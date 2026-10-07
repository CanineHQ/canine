"""`canine-computer-use mcp`: the computer-use tools as a local MCP server, for any agent harness running on this
computer (Claude Code, Codex, opencode, Gemini CLI, goose...). It speaks MCP over stdio, which they all support, and
passes each tool call to the computer-use server on this machine, so the same rules apply (the human lock, one
action at a time).

    {"mcpServers": {"computer": {"command": "~/.local/share/canine/venv/bin/canine-computer-use", "args": ["mcp"]}}}
"""

import json
import sys
import urllib.error
import urllib.request

SERVER = "http://127.0.0.1:8000"

PREFERENCE = ("Prefer, in order: computer_run and computer_terminal (text in, text out), computer_windows, then "
              "computer_accessibility, then keyboard shortcuts, and click at screenshot coordinates only as a last "
              "resort. If a tool says the person is using the computer, wait and try again later.")


def _schema(properties, required=()):
    return {"type": "object", "properties": properties, "required": list(required)}


# name: (description, input schema, how to call the local server)
TOOLS = {
    "computer_screenshot": (
        "Take a screenshot of this computer's screen (1280x720). Its pixels are the coordinates computer_action takes.",
        _schema({}),
        lambda args: ("POST", "/computer-use", {"action": "screenshot"})),
    "computer_action": (
        "Use the mouse and keyboard, following Anthropic's computer-use tool: key (\"ctrl+s\", \"super+Return\"), "
        "type, scroll, left_click at a coordinate, zoom into a region... The desktop is Hyprland: Super is its main "
        "modifier. " + PREFERENCE,
        _schema({"action": {"type": "string"}, "coordinate": {"type": "array", "items": {"type": "integer"}},
                 "start_coordinate": {"type": "array", "items": {"type": "integer"}}, "text": {"type": "string"},
                 "scroll_direction": {"type": "string"}, "scroll_amount": {"type": "integer"},
                 "duration": {"type": "number"}, "region": {"type": "array", "items": {"type": "integer"}}},
                ["action"]),
        lambda args: ("POST", "/computer-use", args)),
    "computer_run": (
        "Run a shell command (bash) on this computer and get its exit code, stdout and stderr. Arch Linux; sudo needs "
        "no password. " + PREFERENCE,
        _schema({"command": {"type": "string"}, "timeout_seconds": {"type": "integer"}}, ["command"]),
        lambda args: ("POST", "/run", {"command": args["command"], "timeout": args.get("timeout_seconds", 30)})),
    "computer_terminal": (
        "Interactive terminal programs as text, in tmux sessions. operation: list, open (command, cwd, show), send "
        "(session, text, keys like \"Enter\"/\"C-c\", enter), read (session, scrollback), wait (session, text, "
        "timeout_seconds), close (session). " + PREFERENCE,
        _schema({"operation": {"type": "string", "enum": ["list", "open", "send", "read", "wait", "close"]},
                 "session": {"type": "string"}, "command": {"type": "string"}, "cwd": {"type": "string"},
                 "show": {"type": "boolean"}, "text": {"type": "string"},
                 "keys": {"type": "array", "items": {"type": "string"}}, "enter": {"type": "boolean"},
                 "scrollback": {"type": "integer"}, "timeout_seconds": {"type": "integer"}}, ["operation"]),
        lambda args: _terminal_request(args)),
    "computer_windows": (
        "Windows, through the window manager: list, open_app (command), open_url (url), focus/close/maximize (id), "
        "move_to_workspace (id, workspace), switch_workspace (workspace). open_app and open_url take maximize: true. "
        "Windows are addressed by id. " + PREFERENCE,
        _schema({"operation": {"type": "string", "enum": ["list", "open_app", "open_url", "focus", "close", "maximize",
                                                           "move_to_workspace", "switch_workspace"]},
                 "id": {"type": "string"}, "command": {"type": "string"}, "url": {"type": "string"},
                 "workspace": {"type": "integer"}, "maximize": {"type": "boolean"}}, ["operation"]),
        lambda args: ("GET", "/windows", None) if args["operation"] == "list"
        else ("POST", f"/windows/{args['operation']}", _without(args, "operation"))),
    "computer_accessibility": (
        "Apps' UI as structure (AT-SPI): tree, find (role, name, window_id, within, limit; a browser's own controls "
        "are left out unless include_browser_ui), press (path, or role/name/window_id; click: true clicks it instead), "
        "set_text (path or role/name, text), wait (role and/or name, window_id, timeout_seconds up to 30, gone: wait for it to disappear) "
        "for a page to load or a dialog to close. Roles can be the tree's (\"tree item\", \"entry\") or the web's (\"treeitem\", \"textbox\"); "
        "if nothing matches, the reply lists the roles that are there. Bounds are screenshot pixels; press and "
        "set_text only act on what's on screen. " + PREFERENCE,
        _schema({"operation": {"type": "string", "enum": ["tree", "find", "press", "set_text", "wait"]},
                 "window_id": {"type": "string"}, "app": {"type": "string"}, "role": {"type": "string"},
                 "name": {"type": "string"}, "within": {"type": "string"}, "limit": {"type": "integer"},
                 "path": {"type": "string"}, "text": {"type": "string"}, "max_depth": {"type": "integer"},
                 "max_elements": {"type": "integer"}, "timeout_seconds": {"type": "integer"},
                 "gone": {"type": "boolean"}, "click": {"type": "boolean"},
                 "include_browser_ui": {"type": "boolean"}}, ["operation"]),
        lambda args: ("POST", f"/accessibility/{args['operation']}", _with_timeout(_without(args, "operation")))),
}


def _without(args, key):
    return {k: v for k, v in args.items() if k != key}


def _with_timeout(body):
    if "timeout_seconds" in body:
        body["timeout"] = body.pop("timeout_seconds")
    return body


def _terminal_request(args):
    if args["operation"] == "list":
        return "GET", "/terminal", None
    return "POST", f"/terminal/{args['operation']}", _with_timeout(_without(args, "operation"))


def call_tool(name, args):
    """MCP content for one tool call: screenshots as images, everything else as JSON text."""
    method, path, body = TOOLS[name][2](args)
    request = urllib.request.Request(SERVER + path, method=method, data=json.dumps(body).encode() if body else None,
                                     headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            result, is_error = json.loads(response.read()), False
    except urllib.error.HTTPError as error:
        result, is_error = json.loads(error.read() or b"{}"), True
    content = []
    if "image" in result:
        content.append({"type": "image", "data": result.pop("image"), "mimeType": f"image/{result.pop('format', 'png')}"})
    if result or not content:
        content.append({"type": "text", "text": result.get("error") if is_error else json.dumps(result)})
    return {"content": content, "isError": is_error}


def handle(message):
    """The reply to one JSON-RPC message, or None for notifications."""
    method, params = message.get("method"), message.get("params") or {}
    if method == "initialize":
        result = {"protocolVersion": params.get("protocolVersion", "2025-06-18"), "capabilities": {"tools": {}},
                  "serverInfo": {"name": "canine-computer-use", "version": "0.1.0"}}
    elif method == "tools/list":
        result = {"tools": [{"name": name, "description": description, "inputSchema": schema}
                            for name, (description, schema, _) in TOOLS.items()]}
    elif method == "tools/call":
        if params.get("name") not in TOOLS:
            return {"jsonrpc": "2.0", "id": message.get("id"), "error": {"code": -32602, "message": "Unknown tool"}}
        try:
            result = call_tool(params["name"], params.get("arguments") or {})
        except Exception as error:  # tell the agent instead of dropping the call
            result = {"content": [{"type": "text", "text": f"{type(error).__name__}: {error}"}], "isError": True}
    elif method == "ping":
        result = {}
    elif "id" not in message:
        return None  # a notification, e.g. notifications/initialized
    else:
        return {"jsonrpc": "2.0", "id": message["id"], "error": {"code": -32601, "message": f"Unknown method {method}"}}
    return {"jsonrpc": "2.0", "id": message.get("id"), "result": result}


def serve():
    """MCP's stdio transport: one JSON-RPC message per line, in on stdin, out on stdout."""
    for line in sys.stdin:
        if line.strip():
            reply = handle(json.loads(line))
            if reply is not None:
                sys.stdout.write(json.dumps(reply) + "\n")
                sys.stdout.flush()
