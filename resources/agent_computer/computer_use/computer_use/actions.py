"""The computer-use actions, as defined by Anthropic's computer-use tool.

An agent's model returns actions like {"action": "left_click", "coordinate": [640, 400]}; `perform` carries one out
and returns the result. Coordinates are screenshot pixels. The action names and fields match the tool spec, so an
agent loop can pass the model's actions through unchanged:
https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/computer-use-tool
"""

import base64

from . import desktop, keyboard, mouse


class ActionError(ValueError):
    """The request was wrong (unknown action, missing field); reported to the agent as a 400."""


def perform(request):
    action = request.get("action")
    handler = ACTIONS.get(action)
    if handler is None:
        raise ActionError(f"Unknown action {action!r}. Actions: {', '.join(sorted(ACTIONS))}")
    return handler(request) or {}


def _coordinate(request, field="coordinate", required=True):
    value = request.get(field)
    if value is None:
        if required:
            raise ActionError(f"{request['action']} needs {field}: [x, y]")
        return None
    if not (isinstance(value, list) and len(value) == 2):
        raise ActionError(f"{field} must be [x, y]")
    x, y = int(value[0]), int(value[1])
    size = desktop.screen_size()
    if not (0 <= x < size["width"] and 0 <= y < size["height"]):
        raise ActionError(f"{field} {[x, y]} is off the {size['width']}x{size['height']} screen")
    return x, y


def _modifiers(request):
    """Clicks and scrolls can hold modifier keys: {"text": "shift"} or {"text": "ctrl+shift"}."""
    text = request.get("text")
    return [keyboard.MODIFIER_NAMES[m.strip().lower()] for m in text.split("+")] if text else []


def screenshot(request):
    return {"image": base64.b64encode(desktop.screenshot()).decode(), "format": "png", **desktop.screen_size()}


def zoom(request):
    region = request.get("region")
    if not (isinstance(region, list) and len(region) == 4):
        raise ActionError("zoom needs region: [left, top, right, bottom]")
    return {"image": base64.b64encode(desktop.screenshot(region)).decode(), "format": "png"}


def click(button, count=1):
    def handler(request):
        point = _coordinate(request, required=False)
        if point:
            mouse.move_to(*point)
        mouse.click(button, count=count, modifiers=_modifiers(request))
    return handler


def mouse_move(request):
    mouse.move_to(*_coordinate(request))


def left_mouse_down(request):
    mouse.press("left")


def left_mouse_up(request):
    mouse.release("left")


def left_click_drag(request):
    mouse.drag(_coordinate(request, "start_coordinate"), _coordinate(request))


def cursor_position(request):
    x, y = mouse.position()
    return {"coordinate": [x, y]}


def scroll(request):
    point = _coordinate(request, required=False)
    if point:
        mouse.move_to(*point)
    direction = request.get("scroll_direction", "down")
    if direction not in ("up", "down", "left", "right"):
        raise ActionError("scroll_direction must be up, down, left or right")
    mouse.scroll(direction, int(request.get("scroll_amount", 3)), modifiers=_modifiers(request))


def key(request):
    if not request.get("text"):
        raise ActionError('key needs text, e.g. "Return" or "ctrl+a"')
    keyboard.press(request["text"])


def type_(request):
    if request.get("text") is None:
        raise ActionError("type needs text")
    keyboard.type_text(request["text"])


def hold_key(request):
    keyboard.hold(request["text"], min(float(request.get("duration", 1)), 100))


def wait(request):
    keyboard.pause(min(float(request.get("duration", 1)), 100))


ACTIONS = {
    "screenshot": screenshot,
    "zoom": zoom,
    "left_click": click("left"),
    "right_click": click("right"),
    "middle_click": click("middle"),
    "double_click": click("left", count=2),
    "triple_click": click("left", count=3),
    "mouse_move": mouse_move,
    "left_mouse_down": left_mouse_down,
    "left_mouse_up": left_mouse_up,
    "left_click_drag": left_click_drag,
    "cursor_position": cursor_position,
    "scroll": scroll,
    "key": key,
    "type": type_,
    "hold_key": hold_key,
    "wait": wait,
}
