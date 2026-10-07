"""The HTTP API. JSON in, JSON out; errors come back as {"error": "..."} with a 4xx/5xx status.

    GET  /status                      {"ok": true, "screen": {"width": ..., "height": ...}, "human": {...}}
    GET  /human                       whether the person has the screen (see human.py)
    POST /human/activity              the person did something (Canine's desktop page reports this)
    POST /human/take_over             pause the agent until /human/hand_back
    POST /human/hand_back             let the agent use the screen again now
    POST /computer-use                one computer-use action, e.g. {"action": "screenshot"} (see actions.py)
    POST /run                         {"command": "uname -a", "timeout": 30}  -> exit code, stdout, stderr
    POST /browse/start                {"task": "...", "url": "...", "model": "x/y", "api_key": "..."}  -> {"id": "..."}
    POST /browse/events               {"id": "...", "after": 7}  -> steps as they happen (see browse.py)
    POST /browse/stop                 {"id": "..."}  -> stops that browse job
    GET  /terminal                    the terminal sessions (tmux) the agent has open
    POST /terminal/open               {"command": "claude", "cwd": "~/app", "show": true}  -> the session (and its window)
    POST /terminal/send               {"session": "term1", "text": "ls", "enter": true, "keys": ["C-c"]}
    POST /terminal/read               {"session": "term1", "scrollback": 0}  -> the screen as text
    POST /terminal/wait               {"session": "term1", "text": "$ ", "timeout": 30}  -> the screen, once it's there
    POST /terminal/close              {"session": "term1"}
    GET  /windows                     the windows, with ids and bounds
    POST /windows/open_app            {"command": "nautilus", "workspace": 3}  -> the new window
    POST /windows/open_url            {"url": "https://example.com"}  -> the new browser window
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

There's no authentication here: the server listens inside the VM, and only Canine can reach it (through kubectl
port-forward, which checks the user's access first; a NetworkPolicy blocks everything else in the cluster).
"""

import json
import logging
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from . import accessibility, actions, browse, desktop, human, shell, terminal, windows

log = logging.getLogger("computer_use")

# One action at a time: two agents (or two requests) moving the same mouse at once would interleave. Shell commands
# and terminal sessions don't touch the mouse or keyboard, and can take a while, so they don't wait for (or hold) it.
_lock = threading.Lock()
UNLOCKED = {("POST", "/run"), ("GET", "/terminal"), ("POST", "/terminal/send"), ("POST", "/terminal/read"),
            ("POST", "/terminal/wait"), ("POST", "/terminal/close"), ("GET", "/human"), ("POST", "/human/activity"),
            ("POST", "/human/take_over"), ("POST", "/human/hand_back"),
            # browse runs browser-use in its own thread and drives the browser over CDP, not the mouse; /browse/events
            # blocks waiting for the next event, so none of these may hold the action lock
            ("POST", "/browse/start"), ("POST", "/browse/events"), ("POST", "/browse/stop")}


ROUTES = {
    ("GET", "/status"): lambda body: {"ok": True, "screen": desktop.screen_size(), "human": human.status()},
    ("GET", "/human"): lambda body: human.status(),
    ("POST", "/human/activity"): lambda body: human.activity(),
    ("POST", "/human/take_over"): lambda body: human.take_over(),
    ("POST", "/human/hand_back"): lambda body: human.hand_back(),
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


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self._handle("GET")

    def do_POST(self):
        self._handle("POST")

    def _handle(self, method):
        path = self.path.split("?")[0].rstrip("/") or "/"
        route = ROUTES.get((method, path))
        if route is None:
            return self._reply(404, {"error": f"No route {method} {self.path}"})
        try:
            length = int(self.headers.get("Content-Length") or 0)
            body = json.loads(self.rfile.read(length) or b"{}") if length else {}
            if method == "POST" and human.needs_screen(path, body):
                human.check()
            if (method, path) in UNLOCKED:
                result = route(body)
            else:
                with _lock:
                    result = route(body)
            self._reply(200, result)
        except human.HumanHasScreen as error:
            self._reply(423, {"error": str(error), "human": human.status()})
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
