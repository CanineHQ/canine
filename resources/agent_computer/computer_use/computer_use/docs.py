"""The API's reference: GET /openapi.json (OpenAPI 3.1) and GET /docs (Swagger UI rendering it, with an Authorize
button for the token, so requests can be tried from the page). Neither needs the token: they only describe the API.

ENDPOINTS has an entry for every route in server.py (tests/test_server.py checks).
"""

import json

from . import actions

TAGS = [
    ("Status", "Whether the server is up, and whether the person is using the computer"),
    ("Computer use", "Anthropic's computer-use actions: screenshots, the mouse and the keyboard"),
    ("Shell", "Commands, and terminal sessions (tmux) the agent can type into and read"),
    ("Windows", "Opening, focusing and moving windows, without taking the screen from the person"),
    ("Workspaces", "Hyprland's workspaces: the agent works on its own, the person keeps theirs"),
    ("Accessibility", "The UI as a tree of named elements (AT-SPI), to find and press things by name"),
    ("Browse", "browser-use, carrying out a browsing task in the logged-in browser on its own"),
]

# (method, path): (tag, summary, description, example request body or None)
ENDPOINTS = {
    ("GET", "/status"): ("Status", "Server status", "The screen's size.", None),
    ("POST", "/computer-use"): ("Computer use", "Perform one computer-use action",
                                "The actions and fields of Anthropic's computer-use tool, so an agent loop can pass "
                                "its model's actions through unchanged. Coordinates are screenshot pixels: screenshots "
                                "are scaled down to fit 1280x800. `screenshot` returns a base64 PNG in `image`; `zoom` "
                                "returns its `region` at full resolution.\n\nActions: "
                                + ", ".join(f"`{name}`" for name in sorted(actions.ACTIONS)),
                                {"action": "left_click", "coordinate": [640, 400]}),
    ("POST", "/run"): ("Shell", "Run a shell command",
                       "Returns `exit_code`, `stdout` and `stderr`. Stdin is closed, and the command (with anything it "
                       "started) is killed after `timeout` seconds (at most 100).", {"command": "uname -a", "timeout": 30}),
    ("GET", "/terminal"): ("Shell", "The open terminal sessions", None, None),
    ("POST", "/terminal/open"): ("Shell", "Open a terminal session",
                                 "A tmux session running `command` (a shell if none), with a terminal window showing it "
                                 "on `workspace` when `show` is true (a free workspace if none is given).",
                                 {"command": "claude", "cwd": "~/app", "show": True, "workspace": 5}),
    ("POST", "/terminal/send"): ("Shell", "Type into a session",
                                 "`text`, then Enter if `enter`; `keys` are tmux key names (`C-c`, `Up`, `Escape`). "
                                 "Goes to the session, whatever window has focus.",
                                 {"session": "term1", "text": "ls", "enter": True}),
    ("POST", "/terminal/read"): ("Shell", "Read a session's screen", "As text; `scrollback` adds lines above it.",
                                 {"session": "term1", "scrollback": 0}),
    ("POST", "/terminal/wait"): ("Shell", "Wait for text in a session",
                                 "Returns the screen once `text` is on it, the program has finished, or `timeout` "
                                 "seconds (at most 90) have passed.", {"session": "term1", "text": "$ ", "timeout": 30}),
    ("POST", "/terminal/close"): ("Shell", "End a session", None, {"session": "term1"}),
    ("GET", "/windows"): ("Windows", "The windows", "Each with its id, app, title, workspace and bounds.", None),
    ("POST", "/windows/open_app"): ("Windows", "Open an app",
                                    "Runs `command` and returns its new window, opened on `workspace` (or a free one) "
                                    "without switching the person's screen to it or taking focus.",
                                    {"command": "nautilus", "workspace": 3, "maximize": True}),
    ("POST", "/windows/open_url"): ("Windows", "Open a URL in a new browser window",
                                    "On `workspace` (or a free one), without switching to it.",
                                    {"url": "https://example.com", "workspace": 3}),
    ("POST", "/windows/focus"): ("Windows", "Focus a window", None, {"id": "0x5a906b225270"}),
    ("POST", "/windows/close"): ("Windows", "Close a window", None, {"id": "0x5a906b225270"}),
    ("POST", "/windows/maximize"): ("Windows", "Maximize a window", None, {"id": "0x5a906b225270"}),
    ("POST", "/windows/move_to_workspace"): ("Windows", "Move a window to another workspace", "The view stays where it is.",
                                             {"id": "0x5a906b225270", "workspace": 4}),
    ("POST", "/windows/switch_workspace"): ("Windows", "Show another workspace", "Changes what the person sees.",
                                            {"workspace": 3}),
    ("GET", "/workspaces"): ("Workspaces", "What's on each workspace",
                             "Each workspace's windows (the agent's marked `agent`), which one the person sees, and a "
                             "`free` one for the agent: not visible, and nothing of the person's on it.", None),
    ("POST", "/workspaces/clear"): ("Workspaces", "Clear a workspace",
                                    "Closes every window on it and ends the terminal sessions opened for it. Browser "
                                    "windows get their tabs closed; the browser itself keeps running.",
                                    {"workspace": 5}),
    ("POST", "/accessibility/tree"): ("Accessibility", "The UI as a tree",
                                      "The visible elements of an `app` or `window_id` (or every app), each with a "
                                      "`path` to press it by.", {"app": "Chromium", "max_depth": 8}),
    ("POST", "/accessibility/find"): ("Accessibility", "Find elements",
                                      "By `role` and/or `name` (a case-insensitive substring), optionally in one "
                                      "`window_id` or `within` an element's path. `actionable` keeps only what can be "
                                      "pressed or typed into.", {"role": "link", "name": "learn more"}),
    ("POST", "/accessibility/press"): ("Accessibility", "Press an element",
                                       "By `path`, or by `role` and `name`. Activates it through accessibility; "
                                       "`click: true` clicks its middle instead.",
                                       {"role": "button", "name": "Send", "window_id": "0x5a906b225270"}),
    ("POST", "/accessibility/set_text"): ("Accessibility", "Set a text field's contents", None,
                                          {"path": "4/0/2/9", "text": "hello"}),
    ("POST", "/accessibility/wait"): ("Accessibility", "Wait for an element",
                                      "Until it's on screen, or with `gone: true` until it isn't, for up to `timeout` "
                                      "seconds (at most 30).", {"role": "button", "name": "Compose", "timeout": 10}),
    ("POST", "/browse/start"): ("Browse", "Start a browsing task",
                                "browser-use carries out `task` in the logged-in browser, in windows of its own on "
                                "`workspace` (or a free one), with `model` through OpenRouter. Returns the job's `id`; "
                                "follow it with POST /browse/events.",
                                {"task": "Find the top story on Hacker News", "url": "https://news.ycombinator.com",
                                 "model": "openai/gpt-5.1", "api_key": "sk-or-...", "max_steps": 40}),
    ("POST", "/browse/events"): ("Browse", "A browsing task's events",
                                 "Events after `after`, waiting up to `wait` seconds for one: a `step` per step it "
                                 "takes, then `done` (with its `result`) or `error`.",
                                 {"id": "browse-ab12cd", "after": -1, "wait": 25}),
    ("POST", "/browse/stop"): ("Browse", "Stop a browsing task", None, {"id": "browse-ab12cd"}),
}


def openapi():
    paths = {}
    for (method, path), (tag, summary, description, example) in ENDPOINTS.items():
        operation = {"tags": [tag], "summary": summary, "responses": {
            "200": {"description": "The result, as JSON"},
            "400": {"description": "A missing or wrong field: `{\"error\": \"...\"}`"},
            "401": {"description": "Missing or wrong token"},
        }}
        if description:
            operation["description"] = description
        if method == "POST":
            operation["requestBody"] = {"content": {"application/json": {"example": example or {}}}}
        paths.setdefault(path, {})[method.lower()] = operation
    return {
        "openapi": "3.1.0",
        "info": {
            "title": "canine-computer-use",
            "version": "0.1.0",
            "description": "Lets an AI agent see and drive this Hyprland desktop. JSON in, JSON out; errors come back "
                           "as `{\"error\": \"...\"}`. Every request needs `Authorization: Bearer <token>`: the token "
                           "is in `~/.config/canine-computer-use/token`. Prefer commands and window operations, then "
                           "the accessibility tree, then keys; clicking at coordinates is the last resort.",
        },
        "tags": [{"name": name, "description": description} for name, description in TAGS],
        "components": {"securitySchemes": {"token": {"type": "http", "scheme": "bearer"}}},
        "security": [{"token": []}],
        "paths": paths,
    }


PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Computer-use API</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.17.14/swagger-ui.css">
  <style>body { margin: 0; background: #fff; }</style>
</head>
<body>
  <div id="docs"></div>
  <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.17.14/swagger-ui-bundle.js"></script>
  <script>SwaggerUIBundle({ url: "openapi.json", dom_id: "#docs", persistAuthorization: true });</script>
</body>
</html>
"""


def page():
    return PAGE.encode()


def spec():
    return json.dumps(openapi()).encode()
