"""Window operations through Hyprland's IPC: open an app or URL, focus, move and close windows, switch workspaces.

Everything addresses windows by `id` (Hyprland's window address, from `list` or `open_app`), never "the focused one"
or "the first one", so an agent only touches the windows it means to. `open_app` waits for the app's window and
returns it, so the agent knows exactly which window is its own.

Omarchy configures Hyprland in Lua, so dispatchers use its Lua syntax: hyprctl dispatch "hl.dsp.focus({ ... })".
"""

import json
import shlex
import subprocess
import time

from . import desktop

OPEN_TIMEOUT = 15  # seconds to wait for a new window to appear


def list_windows():
    return desktop.windows()


def open_app(command, workspace=None, maximize=False):
    """Start an app the way Omarchy's shortcuts do (uwsm-app, so it lives in its own systemd scope, not in this
    server), and return its new window. `command` is a program and arguments, e.g. "nautilus ~/Downloads". With
    `maximize`, the window fills the screen (see maximize)."""
    if workspace is not None:
        switch_workspace(workspace)
    before = {w["id"] for w in desktop.windows()}
    subprocess.Popen(["uwsm-app", "--", *shlex.split(command)], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)
    new = _wait_for_new_windows(before)
    if not new:
        return {"window": None, "note": f"No new window within {OPEN_TIMEOUT}s. It may still be starting (check list), "
                                        "or it reused an existing window (some apps open a tab in their running window)."}
    if workspace is not None:
        # Apps that are already running (a browser) may open next to their existing window instead: move them over
        for w in new:
            if w["workspace"] != int(workspace):
                _dispatch("hl.dsp.window.move", workspace=str(int(workspace)), window=f"address:{w['id']}")
                w["workspace"] = int(workspace)
    # The focused one is the app's main window or its first dialog; list the rest (e.g. a welcome dialog) too
    window = next((w for w in new if w["focused"]), new[-1])
    if maximize:
        maximize_window(window["id"])
        window = next((w for w in desktop.windows() if w["id"] == window["id"]), window)
    return {"window": window, "other_new_windows": [w for w in new if w["id"] != window["id"]]}


def _wait_for_new_windows(before):
    """New windows, once they've settled: apps like LibreOffice show a splash window first and replace it. Splash
    windows have no app name, so skip those, and wait until the set of new windows stays the same for a second."""
    deadline = time.monotonic() + OPEN_TIMEOUT
    new, stable_since = [], None
    while time.monotonic() < deadline:
        current = [w for w in desktop.windows() if w["id"] not in before and w["app"]]
        if [w["id"] for w in current] != [w["id"] for w in new]:
            new, stable_since = current, time.monotonic()
        elif new and time.monotonic() - stable_since >= 1:
            return new
        time.sleep(0.25)
    return new


def open_url(url, workspace=None, maximize=False):
    """Open a URL in a new browser window. (Without --new-window, a browser that's already running opens it as a tab
    in the person's own window.)"""
    return open_app(f"omarchy-launch-browser --new-window {shlex.quote(url)}", workspace, maximize)


def focus(id):
    _dispatch("hl.dsp.focus", window=_address(id))
    return {}


def close(id):
    """Ask a window to close, like its close button. The app may ask something first (e.g. to save changes), so
    report whether it actually closed, and any window it opened instead."""
    before = {w["id"] for w in desktop.windows()}
    _dispatch("hl.dsp.window.close", window=_address(id))
    deadline = time.monotonic() + 2
    while time.monotonic() < deadline:
        windows = desktop.windows()
        if not any(w["id"] == id for w in windows):
            return {"closed": True}
        time.sleep(0.25)
    prompts = [w for w in windows if w["id"] not in before]
    return {"closed": False, "note": "The window is still open; the app may be asking something first.",
            "new_windows": prompts}


def maximize_window(id):
    """Make a window fill the screen, keeping the top bar (Omarchy's Super+Alt+F). Tiled windows are often half the
    screen or less, where web apps hide menus and push dialogs out of view. Does nothing if it's already maximized."""
    address = _address(id)
    if next(w for w in desktop.windows() if w["id"] == id)["maximized"]:
        return {"maximized": True}
    _dispatch("hl.dsp.focus", window=address)
    _dispatch("hl.dsp.window.fullscreen", mode="maximized")  # acts on the focused window
    return {"maximized": next((w["maximized"] for w in desktop.windows() if w["id"] == id), False)}


def move_to_workspace(id, workspace):
    _dispatch("hl.dsp.window.move", workspace=str(int(workspace)), window=_address(id), follow=False)
    return {}


def switch_workspace(workspace):
    _dispatch("hl.dsp.focus", workspace=str(int(workspace)))
    return {}


def _address(id):
    """Hyprland's selector for a window, after checking the window exists (a stale id is an error, not a no-op)."""
    if not any(w["id"] == id for w in desktop.windows()):
        raise LookupError(f"No window {id!r}; it may have closed. List the windows again.")
    return f"address:{id}"


def _dispatch(dispatcher, **args):
    """hyprctl dispatch 'hl.dsp.focus({ window = "address:0x..." })'. Values are JSON-quoted, which Lua reads as
    strings too."""
    fields = ", ".join(f"{key} = {json.dumps(value) if not isinstance(value, bool) else str(value).lower()}"
                       for key, value in args.items())
    reply = desktop.hyprctl("dispatch", f"{dispatcher}({{ {fields} }})").strip()
    if reply != "ok":
        raise RuntimeError(f"Hyprland: {reply}")
