"""Apps' UIs as structure, through AT-SPI (the Linux accessibility bus that screen readers use).

Each element has a role ("button", "link", "entry"...), a name, and a position. An agent can find "the Save
button" by role and name, and press it through its accessibility action, without guessing coordinates from a
screenshot.

Apps only publish their UI when accessibility is on; omarchy-setup.sh turns it on for the session.

Positions need care. On Wayland an app doesn't know where its window is, so it reports positions relative to its
window, and we add the window's position from Hyprland. The units differ too: GTK apps (and Chromium's own tabs and
address bar) use Hyprland's layout units, but Chromium and Electron report *web page* content in device pixels.
`Window` carries both facts down the tree, and `_bounds` returns screenshot pixels like the rest of the API.

Elements are addressed by `path`: the child indexes from the desktop down, e.g. "4/0/2/7". Paths are stable while the
app's UI doesn't change, so find an element and use its path right away.
"""

from collections import namedtuple

import gi

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi  # noqa: E402

from . import desktop, keyboard  # noqa: E402

ROLE_BOUNDARY = ("frame", "window", "dialog")  # an app's top-level windows

# Where an element's reported position is measured from (the window's layout position), and in which units
Window = namedtuple("Window", ["origin", "device_pixels"])


def apps():
    root = Atspi.get_desktop(0)
    return [(str(i), root.get_child_at_index(i)) for i in range(root.get_child_count())]


def node_at(path):
    node = Atspi.get_desktop(0)
    for index in path.split("/"):
        node = node.get_child_at_index(int(index))
        if node is None:
            raise LookupError(f"No element at {path} (the UI may have changed; look it up again)")
    return node


def describe(node, path, window):
    """An element as JSON: role, name, path, and (if it's on screen) its bounds and text."""
    info = {"path": path, "role": node.get_role_name(), "name": node.get_name() or ""}
    bounds = _bounds(node, window)
    if bounds:
        info["bounds"] = bounds
    text = _text(node)
    if text:
        info["text"] = text
    states = node.get_state_set()
    info["states"] = [s for s in ("focused", "checked", "selected", "editable") if states.contains(getattr(Atspi.StateType, s.upper()))]
    if not states.contains(Atspi.StateType.ENABLED):
        info["states"].append("disabled")
    return info


def tree(app=None, max_depth=8, max_elements=500):
    """The visible elements of every app (or of apps whose name contains `app`), as a nested tree."""
    budget = [max_elements]
    result = []
    for path, node in apps():
        if app and app.lower() not in (node.get_name() or "").lower():
            continue
        result.append(_walk(node, path, None, 0, max_depth, budget))
    return result


def find(role=None, name=None, app=None, limit=20):
    """Elements whose role matches exactly and whose name contains `name` (case-insensitive), as a flat list."""
    role = role.lower() if role else None
    name = name.lower() if name else None
    found = []

    def visit(node, path, window, depth):
        if len(found) >= limit or depth > 30 or not _showing(node):
            return
        window = _window_for(node, window)
        if (not role or (node.get_role_name() or "").lower() == role) and (not name or name in (node.get_name() or "").lower()):
            found.append(describe(node, path, window))
        for i in range(node.get_child_count()):
            child = node.get_child_at_index(i)
            if child is not None:
                visit(child, f"{path}/{i}", window, depth + 1)

    for path, node in apps():
        if not app or app.lower() in (node.get_name() or "").lower():
            visit(node, path, None, 0)
    return found


def press(path):
    """Activate an element the way a screen reader would: its "click"/"press"/"activate" action."""
    node = node_at(path)
    action = node.get_action_iface()
    if action is None or action.get_n_actions() == 0:
        raise ValueError(f"{node.get_role_name()} {node.get_name()!r} has no action; click its bounds instead")
    names = [action.get_action_name(i) for i in range(action.get_n_actions())]
    preferred = next((i for i, n in enumerate(names) if n in ("click", "press", "activate", "jump")), 0)
    action.do_action(preferred)
    return {"pressed": names[preferred]}


def set_text(path, text):
    """Replace the text of an editable element (a text field)."""
    node = node_at(path)
    editable = node.get_editable_text_iface()
    if editable is not None:
        Atspi.EditableText.set_text_contents(editable, text)
        return {"method": "set"}
    if not node.get_state_set().contains(Atspi.StateType.EDITABLE):
        raise ValueError(f"{node.get_role_name()} {node.get_name()!r} isn't editable")
    # Some editable fields don't offer the EditableText interface (Chromium's address bar): focus the field, select
    # what's in it and type over it, like a person would
    component = node.get_component_iface()
    if component is None or not component.grab_focus():
        raise ValueError(f"Couldn't focus {node.get_role_name()} {node.get_name()!r}; click it and type instead")
    keyboard.press("ctrl+a")
    keyboard.type_text(text)
    return {"method": "typed"}


# --- helpers ----------------------------------------------------------------------------------------------------

def _walk(node, path, window, depth, max_depth, budget):
    window = _window_for(node, window)
    info = describe(node, path, window)
    budget[0] -= 1
    if depth < max_depth:
        children = []
        for i in range(node.get_child_count()):
            child = node.get_child_at_index(i)
            if budget[0] <= 0:
                info["truncated"] = True
                break
            if child is not None and _showing(child):
                children.append(_walk(child, f"{path}/{i}", window, depth + 1, max_depth, budget))
        if children:
            info["children"] = children
    return info


def _window_for(node, current):
    """The Window an element's position is relative to. Set at each top-level window, switched to device pixels at
    the start of a Chromium/Electron web page, and inherited by everything below."""
    role = node.get_role_name() or ""
    if role in ROLE_BOUNDARY:
        origin = desktop.window_origin(node.get_process_id(), node.get_name())
        return Window(origin, device_pixels=False) if origin else None
    if current and role == "document web" and node.get_toolkit_name() == "Chromium":
        return current._replace(device_pixels=True)
    return current


def _bounds(node, window):
    component = node.get_component_iface()
    if component is None or window is None:
        return None
    r = component.get_extents(Atspi.CoordType.WINDOW)
    if r.width <= 0 or r.height <= 0:
        return None
    unit = desktop.screen().device_scale if window.device_pixels else 1  # device pixels per reported unit
    x, y = window.origin[0] + r.x / unit, window.origin[1] + r.y / unit  # in layout units
    left, top = desktop.to_pixels(x, y)
    right, bottom = desktop.to_pixels(x + r.width / unit, y + r.height / unit)
    return {"x": left, "y": top, "width": right - left, "height": bottom - top}


def _text(node):
    text = node.get_text_iface()
    if text is None:
        return None
    count = Atspi.Text.get_character_count(text)
    return Atspi.Text.get_text(text, 0, min(count, 500)) if count else None


def _showing(node):
    try:
        return node.get_state_set().contains(Atspi.StateType.SHOWING)
    except Exception:  # the element went away while we were reading it
        return False
