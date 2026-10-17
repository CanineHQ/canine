"""Workspaces, and opening windows on one without disturbing the person.

The agent works on a workspace of its own, so the person can keep using the computer on theirs. Every call that
opens a window (open_app, open_url, a terminal's window, a browse job's pages) takes a `workspace`; without one, the
server chooses: one the person isn't looking at, with nothing of theirs on it (`choose`). Replies say which it used,
and `listing` shows what's on each, so the agent always knows where its windows are.

Windows open there without switching to it or taking focus, and keep from taking it later. Hyprland places a window
by its window rules, and a rule only gets one chance: when the window opens. Nothing tells the agent's windows apart
from the person's at that moment (Chromium's windows all share a class, and a new one has no title yet), so
`placing` switches a rule on just while the agent's window opens: "the next window goes to workspace N, silently".
The rules are added at runtime (hyprctl eval) and only switched on and off after that; reloading Hyprland's config
drops them, so they're re-added whenever they're missing.

Each window that opens is tagged canine-agent, which a second rule keeps from taking focus when its app asks for it
(Chromium asks whenever the agent clicks in a page) and keeps rendering while it's out of sight (otherwise a page on a
hidden workspace gets no animation frames). The tag is also how `choose` tells the agent's leftovers from the person's
windows.
"""

import logging
import os
import signal
import threading
import time
from contextlib import contextmanager

from . import cdp, desktop

log = logging.getLogger("computer_use")

WORKSPACES = range(1, 11)  # Omarchy's: Super+1 to Super+0
TAG = "canine-agent"
OPEN_TIMEOUT = 5  # seconds to wait for the window, once its app has been told to open one

_lock = threading.Lock()  # one window opens at a time, so each lands where its caller asked


def listing():
    """Each workspace with its windows (the agent's marked), which one the person is looking at, and the one `choose`
    would pick."""
    visible = _visible()
    clients = desktop.hyprctl_json("clients")
    workspaces = []
    for number in sorted(set(WORKSPACES) | {c["workspace"]["id"] for c in clients if c["workspace"]["id"] > 0}):
        windows = [{"id": c["address"], "app": c["class"], "title": c["title"], "agent": _is_agents(c)}
                   for c in clients if c["workspace"]["id"] == number]
        workspaces.append({"workspace": number, "visible": number == visible, "windows": windows})
    try:
        free = choose()
    except LookupError:
        free = None
    return {"workspaces": workspaces, "free": free}


def choose():
    """A workspace for the agent: the first the person isn't looking at that's empty, or else holds only the agent's
    leftovers (which the caller should clear). Never one with the person's windows."""
    visible = _visible()
    clients = desktop.hyprctl_json("clients")
    candidates = [n for n in WORKSPACES if n != visible]
    on = {n: [c for c in clients if c["workspace"]["id"] == n] for n in candidates}
    for number in candidates:
        if not on[number]:
            return number
    for number in candidates:
        if all(_is_agents(c) for c in on[number]):
            return number
    raise LookupError("Every workspace has the person's windows on it; name one to use.")


def resolve(workspace):
    """The workspace asked for, or one chosen when none was."""
    return choose() if workspace is None else int(workspace)


@contextmanager
def placing(workspace):
    """Inside the block, the next window to open goes to `workspace` silently: start the app (or ask the browser for
    a window) and wait for its window in the block, then tag it."""
    armed = arm(workspace)
    try:
        yield
    finally:
        disarm(armed)


def arm(workspace):
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


def clear(workspace, grace=3):
    """Close every window on `workspace`: what's left of a run, cleared when it ends (and again as the next one starts
    there; the server ends the agent's terminal sessions with it). Always named, never chosen: it closes the
    person's windows there too. Each window is asked to close like its close button.
    One still open after `grace` seconds is closed harder: a browser window held open by a page's "Leave site?" prompt
    has its tabs closed over the debugging port, which skips the prompt, and any other window has its process ended,
    if that process has no windows anywhere else. A browser's process never is: Chromium runs all its windows in one,
    the person's and its web apps' (Omarchy's web apps are Chromium windows of their own class) as well as the agent's.
    Returns how many windows closed, and the ones still open."""
    workspace = int(workspace)
    windows = [c for c in desktop.hyprctl_json("clients") if c["workspace"]["id"] == workspace]
    for address in [w["address"] for w in windows]:
        desktop.hyprctl("dispatch", f'hl.dsp.window.close({{ window = "address:{address}" }})')
    left = _still_open(windows, grace)
    if left:
        browser = {w["pid"] for w in left if _is_browser(w["pid"])}
        _close_browser_windows([w for w in left if w["pid"] in browser])
        elsewhere = {c["pid"] for c in desktop.hyprctl_json("clients") if c["workspace"]["id"] != workspace}
        for pid in {w["pid"] for w in left} - browser - elsewhere:
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        left = _still_open(left, grace)
    return {"closed": len(windows) - len(left),
            "still_open": [{"id": w["address"], "app": w["class"], "title": w["title"]} for w in left]}


BROWSERS = {"chromium", "chrome", "brave", "vivaldi-bin", "msedge", "helium", "firefox", "zen", "librewolf"}


def _is_browser(pid):
    try:
        with open(f"/proc/{pid}/comm") as comm:
            return comm.read().strip() in BROWSERS
    except OSError:
        return True  # can't tell: don't risk ending it


def _close_browser_windows(windows):
    """Close these Chromium windows' tabs over the debugging port. Chromium doesn't say which of its windows is which
    Hyprland window, so each is found by its title (its current tab's: "Hacker News - Chromium", or just "Hacker News"
    for a web app), and left alone when that's ambiguous (a tab of the person's with the same title)."""
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


def _visible():
    return desktop.hyprctl_json("monitors")[0]["activeWorkspace"]["id"]


def _is_agents(client):
    # The static tag `tag` sets; a rule's tags show with a "*" and aren't ours
    return TAG in client.get("tags", [])


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
