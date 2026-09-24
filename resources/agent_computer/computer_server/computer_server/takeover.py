"""Pauses agent input while a person is using the computer.

Selkies (the person) and xdotool (the agent) both inject input through XTest, so events can't be told apart by
device. Instead, input events seen while no agent command is running (plus a short grace period for X to deliver
the agent's own events) count as human. Agent input commands are refused until the person has been idle for
IDLE_SECONDS, or someone calls takeover_release.
"""

import logging
import os
import subprocess
import threading
import time

IDLE_SECONDS = float(os.environ.get("TAKEOVER_IDLE_SECONDS", "5"))
AGENT_GRACE_SECONDS = 0.5
# Compiled from input_watch.c at image build; prints a line per raw key/button/motion event
INPUT_WATCH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "input-watch")

log = logging.getLogger(__name__)
_lock = threading.Lock()
_agent_depth = 0
_agent_last_finished = 0.0
_last_human_input = 0.0
_released_at = 0.0
_monitoring = False


def start():
    """Watch X input for the life of the process; takeover stays disabled if xinput isn't usable."""
    global _monitoring
    try:
        process = subprocess.Popen([INPUT_WATCH], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                   stdin=subprocess.DEVNULL, text=True)
    except OSError as error:
        log.warning("Takeover detection disabled: %s", error)
        return
    _monitoring = True
    threading.Thread(target=_watch, args=(process,), daemon=True).start()


def _watch(process):
    global _last_human_input, _monitoring
    for line in process.stdout:
        if not line.strip():
            continue
        now = time.monotonic()
        with _lock:
            agent_busy = _agent_depth > 0 or now - _agent_last_finished < AGENT_GRACE_SECONDS
            if not agent_busy:
                _last_human_input = now
    _monitoring = False
    log.warning("input-watch exited; takeover detection stopped")


class agent_acting:
    """Context manager marking an agent input command as in progress."""

    def __enter__(self):
        global _agent_depth
        with _lock:
            _agent_depth += 1

    def __exit__(self, *exc):
        global _agent_depth, _agent_last_finished
        with _lock:
            _agent_depth -= 1
            _agent_last_finished = time.monotonic()


def status():
    with _lock:
        idle_for = time.monotonic() - _last_human_input if _last_human_input else None
        active = bool(_last_human_input) and _last_human_input > _released_at and idle_for < IDLE_SECONDS
    return {"monitoring": _monitoring, "human_active": active,
            "human_idle_seconds": round(idle_for, 1) if idle_for is not None else None,
            "resumes_after_idle_seconds": IDLE_SECONDS}


def locked() -> bool:
    return status()["human_active"]


def takeover_status():
    return status()


def takeover_release():
    """Let the agent act immediately, even if the person was just active."""
    global _released_at
    with _lock:
        _released_at = time.monotonic()
    return status()
