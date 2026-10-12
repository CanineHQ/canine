"""Browser-level commands over Chromium's debugging port (omarchy-setup.sh), for the few made outside browse jobs:
opening a window on the agent's workspace, and closing what's left there.

    with cdp.connect() as call:
        call("Target.getTargets")["targetInfos"]
"""

import json
import urllib.request
from contextlib import contextmanager

CDP_URL = "http://127.0.0.1:9222"  # inside the VM only
TIMEOUT = 10


class Error(Exception):
    pass


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
