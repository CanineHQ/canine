"""The agent's own workspace, so the person can keep working on theirs while it runs.

Windows the agent opens (its browser windows, terminal windows) go to WORKSPACE without switching to it and without
taking focus, and keep from taking it later. The person sees them only by switching there to watch.

Hyprland places a window by its window rules, and a rule only gets one chance: when the window opens. Nothing tells
the agent's windows apart from the person's at that moment (Chromium's windows all share a class, and a new one has
no title yet), so `placing` switches a rule on just while the agent's window opens: "the next window goes to
workspace N, silently". The rules are added at runtime (hyprctl eval) and only switched on and off after that;
reloading Hyprland's config drops them, so they're re-added whenever they're missing.

Each window that opens is tagged canine-agent, which a second rule keeps from taking focus when its app asks for it
(Chromium asks whenever the agent clicks in a page) and keeps rendering while it's out of sight (otherwise a page on a
hidden workspace gets no animation frames).
"""

import logging
import os
import signal
import threading
import time
from contextlib import contextmanager

from . import cdp, desktop

log = logging.getLogger("computer_use")

WORKSPACE = int(os.environ.get("CANINE_AGENT_WORKSPACE", "5"))
TAG = "canine-agent"
OPEN_TIMEOUT = 5  # seconds to wait for the window, once its app has been told to open one

_lock = threading.Lock()  # one window opens at a time, so each lands where its caller asked


@contextmanager
def placing(workspace=WORKSPACE):
    """Inside the block, the next window to open goes to `workspace` silently: start the app (or ask the browser for
    a window) and wait for its window in the block, then tag it."""
    armed = arm(workspace)
    try:
        yield
    finally:
        disarm(armed)


def arm(workspace=WORKSPACE):
    """`placing`, split in two for code that awaits in between (a browse job): returns what disarm takes. Holds the
    lock until disarm, which may run on another thread."""
    workspace = int(workspace)
    _lock.acquire()
    try:
        _eval(_ensure_rules(workspace) + f"canine_open[{workspace}]:set_enabled(true)")
    except BaseException:
        _lock.release()
        raise
    return workspace


def disarm(workspace):
    try:
        _eval(f"if canine_open and canine_open[{workspace}] then canine_open[{workspace}]:set_enabled(false) end")
    finally:
        _lock.release()


def addresses():
    return {c["address"] for c in desktop.hyprctl_json("clients")}


def wait_for_new(before, timeout=OPEN_TIMEOUT):
    """The windows that weren't in `before`, as soon as there are any (or none, after `timeout`)."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        new = addresses() - before
        if new:
            return sorted(new)
        time.sleep(0.05)
    return []


def tag(window_addresses):
    for address in window_addresses:
        desktop.hyprctl("dispatch", f'hl.dsp.window.tag({{ tag = "+{TAG}", window = "address:{address}" }})')


def clear(workspace=WORKSPACE, grace=3):
    """Close every window on the agent's workspace: what's left of a run, cleared when it ends (and again as the next
    one starts; the server ends the agent's terminal sessions with it). Each window is asked to close like its close button.
    One still open after `grace` seconds is closed harder: a browser window held open by a page's "Leave site?" prompt
    has its tabs closed over the debugging port, which skips the prompt, and any other window has its process ended,
    if that process has no windows anywhere else. The browser process never is: it runs the person's windows too.
    Returns how many windows closed, and the ones still open."""
    workspace = int(workspace)
    windows = [c for c in desktop.hyprctl_json("clients") if c["workspace"]["id"] == workspace]
    for address in [w["address"] for w in windows]:
        desktop.hyprctl("dispatch", f'hl.dsp.window.close({{ window = "address:{address}" }})')
    left = _still_open(windows, grace)
    if left:
        _close_browser_windows([w for w in left if w["class"] == "chromium"])
        elsewhere = {c["pid"] for c in desktop.hyprctl_json("clients") if c["workspace"]["id"] != workspace}
        for pid in {w["pid"] for w in left if w["class"] != "chromium"} - elsewhere:
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        left = _still_open(left, grace)
    return {"closed": len(windows) - len(left),
            "still_open": [{"id": w["address"], "app": w["class"], "title": w["title"]} for w in left]}


def _close_browser_windows(windows):
    """Close these Chromium windows' tabs over the debugging port. Chromium doesn't say which of its windows is which
    Hyprland window, so each is found by its title (its current tab's), and left alone when that's ambiguous (a tab
    of the person's with the same title)."""
    if not windows:
        return
    try:
        with cdp.connect() as call:
            pages = [t for t in call("Target.getTargets")["targetInfos"] if t["type"] == "page"]
            window_of = {t["targetId"]: call("Browser.getWindowForTarget", {"targetId": t["targetId"]})["windowId"]
                         for t in pages}
            for window in windows:
                title = window["title"].removesuffix(" - Chromium")
                matches = {window_of[t["targetId"]] for t in pages if t["title"] == title}
                if len(matches) == 1:
                    browser_window = matches.pop()
                    for page in pages:
                        if window_of[page["targetId"]] == browser_window:
                            call("Target.closeTarget", {"targetId": page["targetId"]})
    except (cdp.Error, OSError, TimeoutError) as error:
        log.info("Couldn't close browser windows on the agent's workspace: %s", error)


def _still_open(windows, timeout):
    deadline = time.monotonic() + timeout
    while True:
        open_now = addresses()
        left = [w for w in windows if w["address"] in open_now]
        if not left or time.monotonic() >= deadline:
            return left
        time.sleep(0.1)


def _ensure_rules(workspace):
    # Lua, run with hyprctl eval. A config reload starts a fresh Lua state (and drops runtime rules), so check first.
    return (
        "canine_open = canine_open or {} "
        f"if not canine_open[{workspace}] then canine_open[{workspace}] = hl.window_rule({{ "
        f'name = "canine-open-{workspace}", enabled = false, match = {{ class = ".*" }}, '
        f'workspace = "{workspace} silent", no_initial_focus = true }}) end '
        "if not canine_agent_rule then canine_agent_rule = hl.window_rule({ "
        f'name = "{TAG}", match = {{ tag = "{TAG}" }}, focus_on_activate = false, render_unfocused = true }}) end '
    )


def _eval(lua):
    reply = desktop.hyprctl("eval", lua).strip()
    if reply and reply != "ok":
        raise RuntimeError(f"Hyprland: {reply}")
