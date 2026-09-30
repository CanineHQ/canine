"""The HTTP API. JSON in, JSON out; errors come back as {"error": "..."} with a 4xx/5xx status.

    GET  /status                  {"ok": true, "screen": {"width": ..., "height": ...}}
    POST /computer-use            one computer-use action, e.g. {"action": "screenshot"} (see actions.py)
    GET  /windows                 the windows on screen, with bounds
    POST /accessibility/tree      {"app": "Chromium", "max_depth": 8}  -> the visible UI as a tree
    POST /accessibility/find      {"role": "link", "name": "learn more", "app": "Chromium"}  -> matching elements
    POST /accessibility/press     {"path": "4/0/2/7"}  -> activates the element (its click/press action)
    POST /accessibility/set_text  {"path": "4/0/2/9", "text": "hello"}  -> replaces a text field's contents

There's no authentication here: the server listens inside the VM, and only Canine can reach it (through kubectl
port-forward, which checks the user's access first; a NetworkPolicy blocks everything else in the cluster).
"""

import json
import logging
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from . import accessibility, actions, desktop

log = logging.getLogger("computer_use")

# One action at a time: two agents (or two requests) moving the same mouse at once would interleave
_lock = threading.Lock()

ROUTES = {
    ("GET", "/status"): lambda body: {"ok": True, "screen": desktop.screen_size()},
    ("POST", "/computer-use"): actions.perform,
    ("GET", "/windows"): lambda body: {"windows": desktop.windows()},
    ("POST", "/accessibility/tree"): lambda body: {"apps": accessibility.tree(body.get("app"), int(body.get("max_depth", 8)))},
    ("POST", "/accessibility/find"): lambda body: {"elements": accessibility.find(body.get("role"), body.get("name"), body.get("app"))},
    ("POST", "/accessibility/press"): lambda body: accessibility.press(body["path"]),
    ("POST", "/accessibility/set_text"): lambda body: accessibility.set_text(body["path"], body["text"]),
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self._handle("GET")

    def do_POST(self):
        self._handle("POST")

    def _handle(self, method):
        route = ROUTES.get((method, self.path.split("?")[0].rstrip("/") or "/"))
        if route is None:
            return self._reply(404, {"error": f"No route {method} {self.path}"})
        try:
            length = int(self.headers.get("Content-Length") or 0)
            body = json.loads(self.rfile.read(length) or b"{}") if length else {}
            with _lock:
                result = route(body)
            self._reply(200, result)
        except (actions.ActionError, KeyError, LookupError, ValueError) as error:
            self._reply(400, {"error": str(error)})
        except subprocess.CalledProcessError as error:
            log.exception("Command failed")
            self._reply(500, {"error": f"{error.cmd[0]} failed: {(error.stderr or b'').strip()}"})
        except Exception as error:  # report every failure to the agent rather than dropping the connection
            log.exception("Request failed")
            self._reply(500, {"error": f"{type(error).__name__}: {error}"})

    def _reply(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        log.info("%s %s", self.address_string(), fmt % args)


def serve(host, port):
    server = ThreadingHTTPServer((host, port), Handler)
    log.info("Computer-use server on %s:%d", host, port)
    server.serve_forever()
