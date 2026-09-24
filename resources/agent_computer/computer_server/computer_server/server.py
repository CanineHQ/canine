"""HTTP + WebSocket front end. Every command is {"command": name, "params": {...}} -> {"success": bool, ...}."""

import asyncio
import inspect
import logging

from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect

from . import accessibility, browser, desktop, takeover

log = logging.getLogger(__name__)

# Commands that change what's on screen, and so wait for the person to go idle (takeover lock)
INPUT_COMMANDS = {
    desktop.move_cursor, desktop.left_click, desktop.right_click, desktop.middle_click, desktop.double_click,
    desktop.mouse_down, desktop.mouse_up, desktop.drag, desktop.scroll, desktop.scroll_up, desktop.scroll_down,
    desktop.type_text, desktop.press_key, desktop.hotkey, desktop.activate_window, desktop.close_window,
    desktop.launch, accessibility.click_element, accessibility.set_element_text,
    browser.browser_open, browser.browser_goto, browser.browser_back, browser.browser_click, browser.browser_fill,
    browser.browser_press, browser.browser_switch_tab,
}

COMMANDS = {
    fn.__name__: fn for fn in (
        # Screen and input
        desktop.screenshot, desktop.get_screen_size, desktop.get_cursor_position,
        desktop.move_cursor, desktop.left_click, desktop.right_click, desktop.middle_click, desktop.double_click,
        desktop.mouse_down, desktop.mouse_up, desktop.drag, desktop.scroll, desktop.scroll_up, desktop.scroll_down,
        desktop.type_text, desktop.press_key, desktop.hotkey,
        # Windows, clipboard, shell, files
        desktop.list_windows, desktop.activate_window, desktop.close_window,
        desktop.get_clipboard, desktop.set_clipboard, desktop.run_command, desktop.launch,
        desktop.read_text, desktop.write_text, desktop.list_dir,
        # Accessibility tree
        accessibility.get_accessibility_tree, accessibility.find_element,
        accessibility.click_element, accessibility.set_element_text,
        # The user's Chrome
        browser.browser_open, browser.browser_snapshot, browser.browser_url, browser.browser_goto,
        browser.browser_back, browser.browser_click, browser.browser_fill, browser.browser_press,
        browser.browser_text, browser.browser_tabs, browser.browser_switch_tab,
        # Human/agent coordination
        takeover.takeover_status, takeover.takeover_release,
    )
}

# Names Cua's computer-server clients use
ALIASES = {"click": "left_click", "type": "type_text", "key": "press_key", "shell": "run_command",
           "exec": "run_command", "read_file": "read_text", "write_file": "write_text", "ls": "list_dir",
           "copy_to_clipboard": "get_clipboard"}

app = FastAPI(title="Canine computer server")


async def execute(command: str, params: dict) -> dict:
    name = ALIASES.get(command, command)
    handler = COMMANDS.get(name)
    if handler is None:
        return {"success": False, "error": f"Unknown command: {command}"}

    if handler in INPUT_COMMANDS and takeover.locked():
        return {"success": False, "takeover": True,
                "error": "A person is using this computer; agent input is paused until they're idle",
                **takeover.status()}

    accepted = inspect.signature(handler).parameters
    kwargs = {key: value for key, value in (params or {}).items() if key in accepted}
    try:
        if handler in INPUT_COMMANDS:
            with takeover.agent_acting():
                result = await _call(handler, kwargs)
        else:
            result = await _call(handler, kwargs)
    except Exception as error:  # report every failure to the agent rather than dropping the connection
        log.exception("Command %s failed", name)
        return {"success": False, "error": f"{type(error).__name__}: {error}"}
    return {"success": True, **result} if "success" not in result else result


async def _call(handler, kwargs):
    if inspect.iscoroutinefunction(handler):
        return await handler(**kwargs)
    return await asyncio.to_thread(handler, **kwargs)


@app.get("/status")
async def status():
    return {"status": "ok", "os_type": "linux", "takeover": takeover.status()}


@app.get("/commands")
async def commands():
    return {"commands": {name: (inspect.getdoc(fn) or "").split("\n")[0] for name, fn in COMMANDS.items()},
            "aliases": ALIASES}


@app.post("/cmd")
async def cmd(request: Request):
    body = await request.json()
    return await execute(body.get("command", ""), body.get("params") or {})


@app.websocket("/ws")
async def websocket(socket: WebSocket):
    await socket.accept()
    try:
        while True:
            message = await socket.receive_json()
            reply = await execute(message.get("command", ""), message.get("params") or {})
            if "id" in message:
                reply["id"] = message["id"]
            await socket.send_json(reply)
    except WebSocketDisconnect:
        pass
