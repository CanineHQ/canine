"""Who has the screen: the person or the agent.

The person uses the desktop through the Selkies stream in Canine, whose page reports their activity here (any key,
click or mouse movement). While they're active, and for IDLE_SECONDS after, the agent is paused from everything that
shares the screen with them: the mouse and keyboard, focusing and opening windows, switching workspaces. It can still
look (screenshots, the accessibility tree) and work outside the screen (shell commands, its terminal sessions).

The person can also take over (pause the agent until they hand back), or hand back early.
"""

import threading
import time

IDLE_SECONDS = 20

_state = {"active_until": 0.0, "taken_over": False}
_lock = threading.Lock()


# Requests that share the screen with the person, so wait while they have it. Computer-use actions that only look
# are fine, and a terminal session only needs the screen if it opens a window.
NEEDS_SCREEN = {"/computer-use", "/windows/open_app", "/windows/open_url", "/windows/focus", "/windows/close",
                "/windows/move_to_workspace", "/windows/switch_workspace", "/windows/maximize", "/accessibility/press",
                "/accessibility/set_text", "/terminal/open"}
LOOK_ONLY_ACTIONS = {"screenshot", "zoom", "cursor_position", "wait"}


def needs_screen(path, body):
    if path == "/computer-use":
        return body.get("action") not in LOOK_ONLY_ACTIONS
    if path == "/terminal/open":
        return bool(body.get("show", True))
    return path in NEEDS_SCREEN


class HumanHasScreen(Exception):
    """The agent tried to use the screen while the person has it; reported to the agent as a 423."""


def activity():
    """The person just did something on the desktop."""
    with _lock:
        _state["active_until"] = time.monotonic() + IDLE_SECONDS
    return status()


def take_over():
    with _lock:
        _state["taken_over"] = True
    return status()


def hand_back():
    with _lock:
        _state["taken_over"] = False
        _state["active_until"] = 0.0
    return status()


def status():
    with _lock:
        idle_in = max(0.0, _state["active_until"] - time.monotonic())
        taken_over = _state["taken_over"]
    return {"has_screen": taken_over or idle_in > 0, "taken_over": taken_over, "free_in_seconds": round(idle_in)}


def check():
    """Raise if the person has the screen."""
    current = status()
    if current["taken_over"]:
        raise HumanHasScreen("The person has taken over this computer. Wait until they hand it back.")
    if current["has_screen"]:
        raise HumanHasScreen(f"The person is using this computer. It's free once they've been idle for {IDLE_SECONDS}s "
                             f"(about {current['free_in_seconds']}s from now if they stop).")
