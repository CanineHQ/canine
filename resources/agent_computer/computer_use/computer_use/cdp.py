"""Browser-level commands over Chromium's debugging port (set up by setup.py), for the few made outside browse jobs:
opening a window on the agent's workspace, and closing what's left there.

    with cdp.connect() as call:
        call("Target.getTargets")["targetInfos"]
"""

import json
import time
import urllib.error
import urllib.request
from contextlib import contextmanager

CDP_URL = "http://127.0.0.1:9222"  # inside the VM only
TIMEOUT = 10
START_TIMEOUT = 30  # seconds for a Chromium we started to open its debugging port


class Error(Exception):
    pass


def running():
    try:
        urllib.request.urlopen(f"{CDP_URL}/json/version", timeout=2).read()
        return True
    except (urllib.error.URLError, OSError):
        return False


def ensure_running(workspace):
    """The debugging port is only there while Chromium is open, and nothing opens it at login (after a restart, it
    isn't running until someone starts it). Start it when it isn't, on `workspace` with its window tagged as the
    agent's (windows.open_app), so it's closed with the rest of the run's windows. Returns the window it opened, if any."""
    if running():
        return None
    from . import windows  # windows imports this module

    opened = windows.open_app("chromium", workspace=workspace)
    deadline = time.monotonic() + START_TIMEOUT
    while not running():
        if time.monotonic() > deadline:
            raise Error(f"Started Chromium, but its debugging port didn't answer on {CDP_URL} within {START_TIMEOUT}s. "
                        "It needs --remote-debugging-port=9222 in ~/.config/chromium-flags.conf.")
        time.sleep(0.5)
    return opened.get("window")


@contextmanager
def connect():
    from websockets.sync.client import connect as websocket  # installed with browser-use

    with urllib.request.urlopen(f"{CDP_URL}/json/version", timeout=5) as response:
        endpoint = json.load(response)["webSocketDebuggerUrl"]
    with websocket(endpoint, open_timeout=5) as socket:
        ids = iter(range(1, 1_000_000))

        def call(method, params=None):
            id = next(ids)
            socket.send(json.dumps({"id": id, "method": method, "params": params or {}}))
            while True:
                reply = json.loads(socket.recv(timeout=TIMEOUT))
                if reply.get("id") == id:
                    if "error" in reply:
                        raise Error(f"{method}: {reply['error'].get('message')}")
                    return reply["result"]

        yield call
