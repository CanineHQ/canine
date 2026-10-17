"""bigarrow: big arrows, boxes and signs on a Wayland screen, for agents to show people where to look.

    bigarrow point --at 760,500 --text "Click here"              shows it, and returns once it's gone (8 s)
    bigarrow start --window chromium:Inbox --text "This window"  returns once it's showing (gone after 300 s)
    bigarrow stop [ID ...] [--all]                               ends arrows
    bigarrow list                                                the arrows showing

Exit codes: 0 done, 2 bad input, 3 target not found, 4 can't draw (no Wayland, Hyprland or layer-shell).
"""

import argparse
import json
import os
import secrets
import subprocess
import sys
import time
from dataclasses import asdict

from . import geometry, registry, targets
from .geometry import DIRECTIONS, SIZES, Rect

READY_TIMEOUT = 5  # seconds for a new overlay to show


class CannotDraw(RuntimeError):
    """Exit code 4."""


def main(argv=None):
    args = _parser().parse_args(argv)
    try:
        result = args.run(args)
    except ValueError as error:
        return _fail(args, 2, error)
    except targets.TargetNotFound as error:
        return _fail(args, 3, error)
    except (RuntimeError, OSError) as error:
        return _fail(args, 4, error)
    _say(args, result)
    return 0


def _parser():
    parser = argparse.ArgumentParser(prog="bigarrow", description=__doc__.split("\n")[0],
                                     formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__.split("\n", 2)[2])
    commands = parser.add_subparsers(required=True, metavar="command")
    for name, duration, summary in (("point", 8, "show an arrow, and return once it's gone"),
                                    ("start", 300, "show an arrow, and return once it's showing")):
        command = commands.add_parser(name, help=summary, description=summary)
        _arrow_options(command, duration)
        command.set_defaults(run=_show, detach=name == "start")

    stop = commands.add_parser("stop", help="end arrows")
    stop.add_argument("ids", nargs="*", help="the arrows' ids (from start)")
    stop.add_argument("--all", action="store_true", help="every arrow")
    stop.add_argument("--json", action="store_true")
    stop.set_defaults(run=_stop)

    listing = commands.add_parser("list", help="the arrows showing")
    listing.add_argument("--json", action="store_true")
    listing.set_defaults(run=lambda args: {"arrows": registry.arrows()})

    overlay = commands.add_parser("_overlay")  # the overlay process itself, reading its spec from stdin
    overlay.set_defaults(run=_overlay, json=False)
    return parser


def _arrow_options(command, duration):
    target = command.add_argument_group("target (one of; layout coordinates, as Hyprland reports them)")
    choice = target.add_mutually_exclusive_group(required=True)
    choice.add_argument("--at", metavar="X,Y", help="a point")
    choice.add_argument("--rect", metavar="X,Y,W,H", help="a rectangle")
    choice.add_argument("--window", metavar="CLASS[:TITLE]", help="a window, e.g. chromium:Inbox")
    choice.add_argument("--mouse", action="store_true", help="where the pointer is")

    looks = command.add_argument_group("looks")
    looks.add_argument("--text", default="", help="the sign; a full sentence saying what to do")
    looks.add_argument("--color", default="red", help="red, orange, yellow, green, teal, blue, purple, pink, black, "
                       "white or #RRGGBB (default red)")
    looks.add_argument("--from", dest="direction", default="auto", choices=["auto", *DIRECTIONS],
                       help="the side the arrow comes from (default: where the sign fits best)")
    looks.add_argument("--style", default="arrow", choices=["arrow", "ring", "box"],
                       help="ring and box also outline the target")
    looks.add_argument("--size", default="M", type=str.upper, choices=list(SIZES))
    looks.add_argument("--scale", type=float, default=float(os.environ.get("BIGARROW_SCALE") or 1),
                       help="make it bigger or smaller, e.g. 0.8 (default $BIGARROW_SCALE, or 1)")
    looks.add_argument("--shape", default="bend", choices=["bend", "straight"])

    ending = command.add_argument_group("ending")
    ending.add_argument("--duration", type=float, default=duration, help=f"seconds (default {duration}; 0: no limit)")
    ending.add_argument("--owner", type=int, default=int(os.environ.get("BIGARROW_OWNER_PID") or 0) or None,
                        help="end when this process does (default $BIGARROW_OWNER_PID)")

    output = command.add_argument_group("output")
    output.add_argument("--json", action="store_true", help="say what happened as JSON")
    output.add_argument("--dry-run", action="store_true", help="work out where it would go, without drawing it")
    output.add_argument("--png", metavar="PATH", help="draw it into a PNG of the screen instead")
    output.add_argument("--backdrop", metavar="PNG", help="with --png: draw over this screenshot")
    output.add_argument("--screen", metavar="W,H", help="the screen's size, for --png or --dry-run without Hyprland")


def _show(args):
    from . import render

    rgb = render.color(args.color)
    size = geometry.size(args.size, args.scale)
    monitor, target = _locate(args)
    origin = monitor.bounds
    local = Rect(target.x - origin.x, target.y - origin.y, target.width, target.height)
    screen = Rect(0, 0, origin.width, origin.height)
    others = [Rect(**a["sign"]) for a in registry.arrows() if a.get("monitor") == monitor.name and a.get("sign")]
    plan = geometry.plan(local, screen, render.sign_size(args.text, size), args.style, size,
                         args.direction, args.shape, avoid=others)
    arrow = {"id": secrets.token_hex(3), "monitor": monitor.name, "target": vars(target), "from": plan.direction,
             "plan": plan.as_dict()}

    if args.dry_run:
        return arrow
    if args.png:
        render.png(args.png, plan, args.text, rgb, screen, size, args.style, args.backdrop)
        return {**arrow, "png": args.png}

    until = time.time() + args.duration if args.duration > 0 else None
    spec = {**arrow, "text": args.text, "color": rgb, "size": asdict(size), "style": args.style,
            "duration": args.duration, "owner": args.owner, "until": until}
    process = _spawn(spec, args.detach)
    if args.detach:
        return {**arrow, "until": until}
    process.wait()
    return {**arrow, "ended": True}


def _locate(args):
    """The monitor to draw on, and the target in layout coordinates."""
    if args.screen:
        width, height = targets.parse_numbers(args.screen, 2, "--screen")
        monitors = [targets.Monitor("screen", Rect(0, 0, width, height))]
    else:
        monitors = targets.monitors()
    if args.at:
        target = Rect(*targets.parse_numbers(args.at, 2, "--at"))
    elif args.rect:
        target = Rect(*targets.parse_numbers(args.rect, 4, "--rect"))
    elif args.window:
        target, _ = targets.window(args.window, monitors)
    else:
        target = targets.cursor()
    return targets.monitor_for(target, monitors), target


def _spawn(spec, detach):
    """The overlay process, once its arrow is showing; CannotDraw (with why) if it doesn't get that far."""
    if not os.environ.get("WAYLAND_DISPLAY"):
        raise CannotDraw("No Wayland session here (WAYLAND_DISPLAY isn't set): run it inside the desktop session")
    log = registry.directory() / f"{spec['id']}.log"
    with open(log, "w") as errors:
        process = subprocess.Popen([sys.executable, "-m", "bigarrow", "_overlay"], stdin=subprocess.PIPE,
                                   stdout=subprocess.DEVNULL, stderr=errors, start_new_session=detach, text=True)
        process.stdin.write(json.dumps(spec))
        process.stdin.close()
    deadline = time.monotonic() + READY_TIMEOUT
    while not registry.showing(spec["id"]):
        if process.poll() is not None or time.monotonic() > deadline:
            process.kill()
            reason = log.read_text().strip().splitlines()[-1:] or ["it didn't show within 5 s"]
            raise CannotDraw(f"Couldn't draw the arrow: {reason[0]}")
        time.sleep(0.02)
    log.unlink(missing_ok=True)
    return process


def _overlay(args):
    from . import overlay

    overlay.run(json.load(sys.stdin))


def _stop(args):
    if not args.ids and not args.all:
        raise ValueError("Say which arrows to stop (their ids), or --all")
    return {"stopped": registry.stop(None if args.all else set(args.ids))}


def _say(args, result):
    if result is None:
        return
    if args.json:
        print(json.dumps(result))
    elif "arrows" in result:
        for arrow in result["arrows"]:
            print(f"{arrow['id']}  {arrow['text'] or '(no sign)'}")
    elif "stopped" in result:
        print(f"Stopped {len(result['stopped'])}")
    elif "png" in result:
        print(result["png"])
    elif "ended" not in result:
        print(result["id"])  # start: the id, for stop


def _fail(args, code, error):
    if getattr(args, "json", False):
        print(json.dumps({"error": str(error), "exit_code": code}))
    else:
        print(f"bigarrow: {error}", file=sys.stderr)
    return code


def cli():
    sys.exit(main())


if __name__ == "__main__":
    cli()
