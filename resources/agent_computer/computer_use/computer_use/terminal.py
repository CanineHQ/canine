"""Terminal programs as text: shells, Claude Code, vim, installers that ask questions.

A terminal window only shows its text as pixels, and keys typed into it go to whatever window has focus. So programs
run inside tmux instead: tmux keeps each session's screen as text, which `read` returns, and `send` types into a
session directly, whatever has focus and whichever workspace is showing. A person can watch (and type into) the same
session in a terminal window attached to it; `open` can show one.

The agent's sessions live on their own tmux server (`tmux -L canine`), apart from any tmux the person uses.
"""

import os
import re
import subprocess
import time

from . import windows

SOCKET = "canine"   # tmux -L canine: the agent's own tmux server
MAX_WAIT = 90       # seconds; Canine waits 120 for a reply
IDLE_SECONDS = 3    # `wait` with no text: the screen hasn't changed for this long


def list_sessions():
    sessions = []
    for line in _tmux("list-sessions", "-F", "#{session_name}\t#{pane_current_command}\t#{pane_dead}",
                      check=False).splitlines():
        name, command, dead = line.split("\t")
        sessions.append({"session": name, "running": command, "finished": dead == "1"})
    return {"sessions": sessions}


def open_session(command=None, session=None, cwd=None, show=True, workspace=None):
    """Start `command` (default: a shell) in a new session, in the home directory or `cwd`. With `show`, also open a
    terminal window attached to it, so the person can watch."""
    session = session or _free_name()
    if not re.fullmatch(r"[\w.-]+", session):
        raise ValueError("session names may only use letters, digits, '.', '_' and '-'")
    _tmux("new-session", "-d", "-s", session, "-x", "160", "-y", "45", "-c", os.path.expanduser(cwd or "~"),
          *([command] if command else []))
    # Keep the screen after the program exits, so its last output can still be read
    _tmux("set-option", "-t", session, "remain-on-exit", "on")
    result = {"session": session}
    if show:
        result["window"] = windows.open_app(f"foot -e tmux -L {SOCKET} attach -t {session}", workspace).get("window")
    return result


def send(session, text=None, keys=(), enter=False):
    """Type `text` exactly as given, then press `keys` (tmux key names: "Enter", "Escape", "Up", "C-c", "Tab"), then
    Enter if `enter`."""
    _require(session)
    if text:
        _tmux("send-keys", "-t", session, "-l", text)  # -l: literally, so "Enter" in the text isn't a key
    for key in [*keys, *(["Enter"] if enter else [])]:
        _tmux("send-keys", "-t", session, key)
    return {}


def read(session, scrollback=0):
    """The session's screen as text (plus up to `scrollback` lines above it), and what's running in it."""
    _require(session)
    start = ["-S", f"-{int(scrollback)}"] if scrollback else []
    screen = _tmux("capture-pane", "-p", "-J", "-t", session, *start)  # -J: join lines the screen wrapped
    status = _tmux("display-message", "-p", "-t", session, "#{pane_current_command}\t#{pane_dead}").strip()
    command, dead = status.split("\t")
    return {"screen": screen.rstrip("\n"), "running": command, "finished": dead == "1"}


def wait(session, text=None, timeout=30):
    """Wait until `text` appears on the screen, or (without `text`) until the screen stops changing, then read it."""
    _require(session)
    deadline = time.monotonic() + min(float(timeout), MAX_WAIT)
    last, unchanged_since = None, time.monotonic()
    while time.monotonic() < deadline:
        current = read(session)
        if text and text in current["screen"]:
            return current
        if current["screen"] != last:
            last, unchanged_since = current["screen"], time.monotonic()
        elif not text and time.monotonic() - unchanged_since >= IDLE_SECONDS:
            return current
        if current["finished"]:
            return current
        time.sleep(0.5)
    return {**read(session), "timed_out": True}


def close(session):
    _require(session)
    _tmux("kill-session", "-t", session)  # an attached terminal window closes with it
    return {}


def _require(session):
    if session not in {s["session"] for s in list_sessions()["sessions"]}:
        raise LookupError(f"No terminal session {session!r}; list them, or open one")


def _free_name():
    taken = {s["session"] for s in list_sessions()["sessions"]}
    return next(f"term{n}" for n in range(1, 1000) if f"term{n}" not in taken)


def _tmux(*args, check=True):
    result = subprocess.run(["tmux", "-L", SOCKET, *args], capture_output=True, text=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"tmux {args[0]}: {result.stderr.strip()}")
    return result.stdout
