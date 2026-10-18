"""The arrow on screen: a transparent full-monitor surface on the compositor's overlay layer (wlr-layer-shell, through
gtk4-layer-shell), above every window, panels included.

It never takes keyboard focus, and clicks go through it everywhere but the sign: its input region is just the sign,
and a click there removes the arrow at once. It also ends after its duration, when its owner process exits, or on
SIGTERM (`bigarrow stop`), with a short exit animation.
"""

import ctypes
import math
import os
import signal

import cairo
import gi

from . import registry, render
from .geometry import Plan, Size

# gtk4-layer-shell has to be loaded before libwayland-client, which importing Gtk loads
ctypes.CDLL("libgtk4-layer-shell.so")
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402
from gi.repository import Gtk4LayerShell as LayerShell  # noqa: E402

APPEAR_SECONDS = 0.18
EXIT_SECONDS = 0.35
HOVER_OPACITY = 0.8  # the sign under the pointer dims: a click there ends it


def run(spec):
    """Shows the arrow `spec` describes (see __main__.overlay_spec) until it ends."""
    Gtk.init()
    if not LayerShell.is_supported():
        raise RuntimeError("This compositor doesn't support wlr-layer-shell, which bigarrow draws with")

    plan, size = Plan.from_dict(spec["plan"]), Size(**spec["size"])
    loop = GLib.MainLoop()
    window = Gtk.Window(title="bigarrow")
    LayerShell.init_for_window(window)
    LayerShell.set_namespace(window, "bigarrow")
    LayerShell.set_layer(window, LayerShell.Layer.OVERLAY)
    LayerShell.set_keyboard_mode(window, LayerShell.KeyboardMode.NONE)
    LayerShell.set_exclusive_zone(window, -1)  # over panels too, rather than beside them
    for edge in (LayerShell.Edge.TOP, LayerShell.Edge.BOTTOM, LayerShell.Edge.LEFT, LayerShell.Edge.RIGHT):
        LayerShell.set_anchor(window, edge, True)
    monitor = _monitor(spec["monitor"])
    if monitor:
        LayerShell.set_monitor(window, monitor)

    css = Gtk.CssProvider()
    css.load_from_string("window, window * { background: transparent; }")
    Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    area = Gtk.DrawingArea()
    state = {"shown": GLib.get_monotonic_time(), "ending": None, "hover": False}

    def elapsed(since):
        return (GLib.get_monotonic_time() - since) / 1e6

    def draw(_area, context, _width, _height):
        opacity, scale = _appearance(elapsed(state["shown"]), state["ending"] and elapsed(state["ending"]))
        if state["hover"] and not state["ending"]:
            opacity *= HOVER_OPACITY
        context.translate(*plan.tip)  # grow from and shrink into the tip
        context.scale(scale, scale)
        context.translate(-plan.tip[0], -plan.tip[1])
        render.draw(context, plan, spec["text"], tuple(spec["color"]), size, spec["style"], opacity)

    def animate(widget, _clock):
        widget.queue_draw()
        if state["ending"] and elapsed(state["ending"]) >= EXIT_SECONDS:
            loop.quit()
            return False
        return state["ending"] is not None or elapsed(state["shown"]) < APPEAR_SECONDS

    def dismiss(*_):
        """A click on the sign: gone at once, so the person can get on with it."""
        window.set_visible(False)
        loop.quit()

    def end(*_):
        """Plays the exit, then quits: when its time is up, on `bigarrow stop`, or when its owner goes."""
        if state["ending"] is None:
            state["ending"] = GLib.get_monotonic_time()
            registry.remove(spec["id"])
            surface = window.get_surface()
            if surface:
                surface.set_input_region(cairo.Region())  # clicks go through while it goes
            area.add_tick_callback(animate)
            GLib.timeout_add(int(EXIT_SECONDS * 1000) + 500, loop.quit)  # in case no frames come (screen off)
        return False

    def hover(entered):
        state["hover"] = entered
        area.queue_draw()

    area.set_draw_func(draw)
    area.add_tick_callback(animate)
    click = Gtk.GestureClick()
    click.connect("pressed", dismiss)  # only the sign takes clicks (the input region)
    area.add_controller(click)
    motion = Gtk.EventControllerMotion()
    motion.connect("enter", lambda *_: hover(True))
    motion.connect("leave", lambda *_: hover(False))
    area.add_controller(motion)
    window.set_child(area)

    def mapped(*_):
        sign = plan.sign
        region = cairo.Region(cairo.RectangleInt(int(sign.x), int(sign.y), int(sign.width) + 1, int(sign.height) + 1))
        window.get_surface().set_input_region(region)
        registry.save({"id": spec["id"], "pid": os.getpid(), "text": spec["text"], "target": spec["target"],
                       "monitor": spec["monitor"], "sign": spec["plan"]["sign"], "until": spec["until"]})

    window.connect("map", mapped)
    window.connect("close-request", end)

    if spec["duration"] > 0:
        GLib.timeout_add(int(spec["duration"] * 1000), end)
    if spec.get("owner"):
        GLib.timeout_add_seconds(1, _owner_alive, spec["owner"], end)
    for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signum, end)

    window.present()
    try:
        loop.run()
    finally:
        registry.remove(spec["id"])


def _appearance(shown, ending):
    """(opacity, scale) at `shown` seconds after it appeared, or `ending` seconds into its exit: it pops in from the
    tip; going, it swells a little, then shrinks back into the tip as it fades."""
    if ending is not None:
        t = min(ending / EXIT_SECONDS, 1)
        if t < 0.25:
            return 1.0, 1 + 0.08 * math.sin(t / 0.25 * math.pi / 2)
        t = (t - 0.25) / 0.75
        eased = t * t
        return 1 - eased, 1.08 - 0.78 * eased
    t = min(shown / APPEAR_SECONDS, 1)
    eased = 1 - (1 - t) ** 3
    return eased, 0.85 + 0.15 * eased


def _monitor(name):
    monitors = Gdk.Display.get_default().get_monitors()
    for i in range(monitors.get_n_items()):
        if monitors.get_item(i).get_connector() == name:
            return monitors.get_item(i)
    return None


def _owner_alive(pid, end):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        end()
        return False
    except PermissionError:
        pass
    return True
