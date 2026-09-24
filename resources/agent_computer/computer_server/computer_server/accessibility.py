"""The desktop's real accessibility tree (AT-SPI): what's on screen as roles, names, states and bounds.

Elements are addressed by `path`, their child indexes from the desktop root (e.g. "2.0.5"), which agents can pass
back to click_element / set_element_text. Paths are only stable while the UI doesn't change.
"""

import gi

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi  # noqa: E402

from . import desktop  # noqa: E402

Atspi.set_timeout(2000, 5000)  # an unresponsive app shouldn't hang the whole server

INTERESTING_STATES = {
    "focused": Atspi.StateType.FOCUSED, "selected": Atspi.StateType.SELECTED, "checked": Atspi.StateType.CHECKED,
    "expanded": Atspi.StateType.EXPANDED, "editable": Atspi.StateType.EDITABLE, "disabled": None,
}
PREFERRED_ACTIONS = ("click", "press", "activate", "jump", "toggle", "select")


def _showing(node) -> bool:
    return node.get_state_set().contains(Atspi.StateType.SHOWING)


def _bounds(node):
    component = node.get_component_iface()
    if component is None:
        return None
    rect = component.get_extents(Atspi.CoordType.SCREEN)
    if rect.width <= 0 or rect.height <= 0:
        return None
    return {"x": rect.x, "y": rect.y, "width": rect.width, "height": rect.height}


def _describe(node, path: str) -> dict:
    states = node.get_state_set()
    info = {"path": path, "role": node.get_role_name(), "name": node.get_name() or ""}
    flags = [name for name, state in INTERESTING_STATES.items() if state is not None and states.contains(state)]
    if not states.contains(Atspi.StateType.ENABLED):
        flags.append("disabled")
    if flags:
        info["states"] = flags
    bounds = _bounds(node)
    if bounds:
        info["bounds"] = bounds
    if states.contains(Atspi.StateType.EDITABLE):
        text = node.get_text_iface()
        if text is not None:
            info["text"] = text.get_text(0, min(text.get_character_count(), 500))
    return info


def _walk(visit, app: str = None, max_depth: int = 12, showing_only: bool = True):
    """Depth-first over running apps, calling visit(node, path, depth); visit returns False to stop entirely."""
    root = Atspi.get_desktop(0)

    def descend(node, path, depth):
        if depth > max_depth:
            return True
        for i in range(node.get_child_count()):
            child = node.get_child_at_index(i)
            if child is None or (showing_only and depth > 0 and not _showing(child)):
                continue
            child_path = f"{path}.{i}" if path else str(i)
            if visit(child, child_path, depth) is False or descend(child, child_path, depth + 1) is False:
                return False
        return True

    for index in range(root.get_child_count()):
        application = root.get_child_at_index(index)
        if application is None or (app and app.lower() not in (application.get_name() or "").lower()):
            continue
        if visit(application, str(index), 0) is False or descend(application, str(index), 1) is False:
            return


def get_accessibility_tree(app: str = None, max_depth: int = 12, max_nodes: int = 1500, showing_only: bool = True):
    """Nested tree of the (on-screen) UI, optionally for one app. Capped at max_nodes elements."""
    nodes = {}
    roots = []
    count = 0

    def visit(node, path, depth):
        nonlocal count
        if count >= max_nodes:
            return False
        count += 1
        entry = _describe(node, path)
        nodes[path] = entry
        parent = path.rpartition(".")[0]
        if parent in nodes:
            nodes[parent].setdefault("children", []).append(entry)
        else:
            roots.append(entry)
        return True

    _walk(visit, app=app, max_depth=max_depth, showing_only=showing_only)
    return {"tree": roots, "truncated": count >= max_nodes}


def find_element(role: str = None, name: str = None, app: str = None, max_results: int = 20):
    """Elements whose role matches exactly (e.g. "push button") and whose name contains `name` (case-insensitive)."""
    role = role.replace("_", " ").lower() if role else None
    name = name.lower() if name else None
    matches = []

    def visit(node, path, depth):
        if role and (node.get_role_name() or "").lower() != role:
            return True
        if name and name not in (node.get_name() or "").lower():
            return True
        matches.append(_describe(node, path))
        return len(matches) < max_results

    _walk(visit, app=app)
    return {"elements": matches}


def _resolve(path: str = None, role: str = None, name: str = None, app: str = None, index: int = 0):
    if path:
        node = Atspi.get_desktop(0)
        for part in path.split("."):
            node = node.get_child_at_index(int(part)) if node else None
        if node is None:
            raise LookupError(f"No element at path {path}; the UI may have changed, look it up again")
        return node, path
    elements = find_element(role=role, name=name, app=app, max_results=index + 1)["elements"]
    if len(elements) <= index:
        raise LookupError(f"No element matching role={role!r} name={name!r}")
    return _resolve(path=elements[index]["path"])


def click_element(path: str = None, role: str = None, name: str = None, app: str = None, index: int = 0):
    """Activate an element through its own accessibility action, falling back to clicking its center."""
    node, path = _resolve(path, role, name, app, index)
    action = node.get_action_iface()
    if action is not None:
        names = [action.get_action_name(i).lower() for i in range(action.get_n_actions())]
        for preferred in PREFERRED_ACTIONS:
            if preferred in names:
                action.do_action(names.index(preferred))
                return {"path": path, "method": f"action:{preferred}"}
    bounds = _bounds(node)
    if not bounds:
        raise RuntimeError("Element has no action and no on-screen bounds to click")
    desktop.left_click(bounds["x"] + bounds["width"] // 2, bounds["y"] + bounds["height"] // 2)
    return {"path": path, "method": "click", "bounds": bounds}


def set_element_text(text: str, path: str = None, role: str = None, name: str = None, app: str = None, index: int = 0):
    """Replace an editable element's contents without typing keystroke by keystroke."""
    node, path = _resolve(path, role, name, app, index)
    editable = node.get_editable_text_iface()
    if editable is None:
        raise RuntimeError("Element isn't editable")
    editable.set_text_contents(text)
    return {"path": path}
