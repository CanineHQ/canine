"""The HTTP API. JSON in, JSON out; errors come back as {"error": "..."} with a 4xx/5xx status.

    GET  /docs                        this reference, rendered (Swagger UI; GET /openapi.json for the OpenAPI spec)
    GET  /status                      {"ok": true, "screen": {"width": ..., "height": ...}}
    POST /computer-use                one computer-use action, e.g. {"action": "screenshot"} (see actions.py)
    POST /run                         {"command": "uname -a", "timeout": 30}  -> exit code, stdout, stderr
    POST /browse/start                {"task": "...", "url": "...", "model": "x/y", "api_key": "...", "workspace": 5}  -> {"id": "...", "workspace": 5}
    POST /browse/events               {"id": "...", "after": 7}  -> steps as they happen (see browse.py)
    POST /browse/stop                 {"id": "..."}  -> stops that browse job
    GET  /terminal                    the terminal sessions (tmux) the agent has open
    POST /terminal/open               {"command": "claude", "cwd": "~/app", "show": true, "workspace": 5}  -> the session (and its window)
    POST /terminal/send               {"session": "term1", "text": "ls", "enter": true, "keys": ["C-c"]}
    POST /terminal/read               {"session": "term1", "scrollback": 0}  -> the screen as text
    POST /terminal/wait               {"session": "term1", "text": "$ ", "timeout": 30}  -> the screen, once it's there
    POST /terminal/close              {"session": "term1"}
    GET  /windows                     the windows, with ids and bounds
    GET  /workspaces                  -> each workspace's windows, the one the person sees, and a free one for the agent
    POST /workspaces/clear            {"workspace": 5}  -> closes every window on it, ends the terminal sessions opened for it
    POST /windows/open_app            {"command": "nautilus", "workspace": 3}  -> the new window and its workspace
    POST /windows/open_url            {"url": "https://example.com", "workspace": 5}  -> the new browser window and its workspace
    (Opening a window without a workspace uses a free one: see workspaces.py. It never switches the person's view.)
    POST /windows/focus               {"id": "0x5a906b225270"}
    POST /windows/close               {"id": "0x5a906b225270"}
    POST /windows/move_to_workspace   {"id": "0x5a906b225270", "workspace": 4}  (the window moves; the view stays)
    POST /windows/switch_workspace    {"workspace": 3}
    POST /windows/maximize            {"id": "0x5a906b225270"}  (fills the screen; open_app/open_url take "maximize": true)
    POST /accessibility/tree          {"app": "Chromium" or "window_id": "0x...", "max_depth": 8}  -> the UI as a tree
    POST /accessibility/find          {"role": "link", "name": "learn more", "window_id": "0x..."}  -> matching elements
    POST /accessibility/press         {"path": "4/0/2/7"} or {"role": "button", "name": "Send", "window_id": "0x..."}
                                      -> activates the element ("click": true clicks its middle instead)
    POST /accessibility/set_text      {"path": "4/0/2/9", "text": "hello"}  -> replaces a text field's contents
    POST /accessibility/wait          {"role": "button", "name": "Compose", "window_id": "0x...", "timeout": 10}
                                      -> once it's on screen (or with "gone": true, once it isn't), up to 30 s

Every request needs `Authorization: Bearer <token>` (auth.py), or gets a 401: whoever has the token can run commands
as the desktop user. In Canine the server listens on the VM's interface, reached through kubectl port-forward, and a
NetworkPolicy blocks everything else in the cluster as well.
"""

import json
import logging
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from . import accessibility, actions, auth, browse, desktop, docs, shell, terminal, windows, workspaces

log = logging.getLogger("computer_use")

# One action at a time: two agents (or two requests) moving the same mouse at once would interleave. Shell commands
# and terminal sessions don't touch the mouse or keyboard, and can take a while, so they don't wait for (or hold) it.
_lock = threading.Lock()
UNLOCKED = {("POST", "/run"), ("GET", "/terminal"), ("POST", "/terminal/send"), ("POST", "/terminal/read"),
            ("POST", "/terminal/wait"), ("POST", "/terminal/close"),
            # browse runs browser-use in its own thread and drives the browser over CDP, not the mouse; /browse/events
            # blocks waiting for the next event, so none of these may hold the action lock
            ("POST", "/browse/start"), ("POST", "/browse/events"), ("POST", "/browse/stop")}


ROUTES = {
    ("GET", "/status"): lambda body: {"ok": True, "screen": desktop.screen_size()},
    ("POST", "/computer-use"): actions.perform,
    ("POST", "/run"): lambda body: shell.run(body["command"], body.get("timeout", 30)),
    ("POST", "/browse/start"): browse.start,
    ("POST", "/browse/events"): browse.events,
    ("POST", "/browse/stop"): browse.stop,
    ("GET", "/terminal"): lambda body: terminal.list_sessions(),
    ("POST", "/terminal/open"): lambda body: terminal.open_session(body.get("command"), body.get("session"), body.get("cwd"),
                                                                   body.get("show", True), body.get("workspace")),
    ("POST", "/terminal/send"): lambda body: terminal.send(body["session"], body.get("text"), body.get("keys") or [],
                                                           body.get("enter", False)),
    ("POST", "/terminal/read"): lambda body: terminal.read(body["session"], body.get("scrollback", 0)),
    ("POST", "/terminal/wait"): lambda body: terminal.wait(body["session"], body.get("text"), body.get("timeout", 30)),
    ("POST", "/terminal/close"): lambda body: terminal.close(body["session"]),
    ("GET", "/windows"): lambda body: {"windows": windows.list_windows()},
    ("POST", "/windows/open_app"): lambda body: windows.open_app(body["command"], body.get("workspace"), bool(body.get("maximize"))),
    ("POST", "/windows/open_url"): lambda body: windows.open_url(body["url"], body.get("workspace"), bool(body.get("maximize"))),
    ("POST", "/windows/maximize"): lambda body: windows.maximize_window(body["id"]),
    ("POST", "/windows/focus"): lambda body: windows.focus(body["id"]),
    ("POST", "/windows/close"): lambda body: windows.close(body["id"]),
    ("POST", "/windows/move_to_workspace"): lambda body: windows.move_to_workspace(body["id"], body["workspace"]),
    ("POST", "/windows/switch_workspace"): lambda body: windows.switch_workspace(body["workspace"]),
    ("GET", "/workspaces"): lambda body: workspaces.listing(),
    ("POST", "/workspaces/clear"): lambda body: {**workspaces.clear(body["workspace"]),
                                                            **terminal.close_workspace(body["workspace"])},
    ("POST", "/accessibility/tree"): lambda body: {"apps": accessibility.tree(body.get("app"), int(body.get("max_depth", 8)),
                                                                            int(body.get("max_elements", 500)),
                                                                            body.get("window_id"))},
    ("POST", "/accessibility/find"): lambda body: accessibility.find(body.get("role"), body.get("name"), body.get("app"),
                                                                     min(int(body.get("limit", 20)), 255),
                                                                     body.get("window_id"), body.get("within"),
                                                                     bool(body.get("include_browser_ui")),
                                                                     bool(body.get("actionable"))),
    ("POST", "/accessibility/press"): lambda body: accessibility.press(body.get("path"), body.get("role"), body.get("name"),
                                                                       body.get("window_id"), body.get("within"),
                                                                       bool(body.get("click"))),
    ("POST", "/accessibility/set_text"): lambda body: accessibility.set_text(body["text"], body.get("path"), body.get("role"),
                                                                             body.get("name"), body.get("window_id"),
                                                                             body.get("within")),
    ("POST", "/accessibility/wait"): lambda body: accessibility.wait(body.get("role"), body.get("name"), body.get("app"),
                                                                     body.get("window_id"), float(body.get("timeout", 10)),
                                                                     bool(body.get("gone"))),
}


DOCS = {"/docs": ("text/html; charset=utf-8", docs.page), "/openapi.json": ("application/json", docs.spec)}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self._handle("GET")

    def do_POST(self):
        self._handle("POST")

    def _handle(self, method):
        path = self.path.split("?")[0].rstrip("/") or "/"
        route = ROUTES.get((method, path))
        if method == "GET" and path in DOCS:  # only describes the API, so no token needed
            content_type, render = DOCS[path]
            return self._send(200, content_type, render())
        if not auth.authorized(self.headers.get("Authorization"), self.server.token):
            return self._reply(401, {"error": "Missing or wrong token: send Authorization: Bearer <token> (see auth.py)"})
        if route is None:
            return self._reply(404, {"error": f"No route {method} {self.path}"})
        try:
            length = int(self.headers.get("Content-Length") or 0)
            body = json.loads(self.rfile.read(length) or b"{}") if length else {}
            if (method, path) in UNLOCKED:
                result = route(body)
            else:
                with _lock:
                    result = route(body)
            self._reply(200, result)
        except KeyError as error:
            self._reply(400, {"error": f"Missing field {error}"})
        except (actions.ActionError, LookupError, ValueError) as error:
            self._reply(400, {"error": str(error)})
        except subprocess.CalledProcessError as error:
            log.exception("Command failed")
            self._reply(500, {"error": f"{error.cmd[0]} failed: {(error.stderr or b'').strip()}"})
        except Exception as error:  # report every failure to the agent rather than dropping the connection
            log.exception("Request failed")
            self._reply(500, {"error": f"{type(error).__name__}: {error}"})

    def _reply(self, status, payload):
        self._send(status, "application/json", json.dumps(payload).encode())

    def _send(self, status, content_type, body):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        log.info("%s %s", self.address_string(), fmt % args)


def serve(host, port, token):
    server = ThreadingHTTPServer((host, port), Handler)
    server.token = token
    log.info("Computer-use server on %s:%d", host, port)
    server.serve_forever()
