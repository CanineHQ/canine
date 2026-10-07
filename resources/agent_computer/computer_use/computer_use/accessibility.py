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

import re
import time
from collections import Counter, namedtuple

import gi

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi  # noqa: E402

from . import desktop, keyboard, mouse, paths, placeholders, roles, waiting  # noqa: E402

ROLE_BOUNDARY = ("frame", "window", "dialog", "alert")  # an app's top-level windows (LibreOffice's dialogs are alerts)
# Limits on walking a tree. Every element is a D-Bus round trip, and some apps publish enormous trees: a spreadsheet
# is a table with a child for every cell. Look at the first children of any element only, and stop after a total.
MAX_CHILDREN = 200
MAX_VISITED = 3000

# Where an element's reported position is measured from (the window's layout position), and in which units
Window = namedtuple("Window", ["origin", "device_pixels"])


def apps():
    root = Atspi.get_desktop(0)
    return [(str(i), root.get_child_at_index(i)) for i in range(root.get_child_count())]


def node_at(path):
    if not re.fullmatch(r"\d+(/\d+)*", str(path)):
        raise ValueError(f"{path!r} isn't an element path; use the path from tree or find, e.g. \"4/0/2/7\"")
    node = Atspi.get_desktop(0)
    for index in path.split("/"):
        node = node.get_child_at_index(int(index))
        if node is None:
            raise LookupError(f"No element at {path} (the UI may have changed; look it up again)")
    return node


def describe(node, path, window):
    """An element as JSON: role, name, path, and (if it's on screen) its bounds and text."""
    info = {"path": path, "role": node.get_role_name(), "name": node.get_name() or ""}
    paths.remember(path, info["role"], info["name"])  # so a press can tell if the path now points elsewhere
    bounds = _bounds(node, window)
    if bounds:
        info["bounds"] = bounds
    text = _text(node)
    if text:
        info["text"] = text
    if info["role"] == "link":
        url = _url(node)
        if url:
            info["url"] = url  # where it goes: tells a link to another page from one within this page (a contents entry)
    states = node.get_state_set()
    info["states"] = [s for s in ("focused", "checked", "selected", "editable") if states.contains(getattr(Atspi.StateType, s.upper()))]
    if not states.contains(Atspi.StateType.ENABLED):
        info["states"].append("disabled")
    if not states.contains(Atspi.StateType.SHOWING):
        info["states"].append("offscreen")  # e.g. scrolled out of view: press still works; to see it, scroll
    return info


def tree(app=None, max_depth=8, max_elements=500, window_id=None):
    """The visible elements of every app (or of apps whose name contains `app`, or of one window), as a nested tree."""
    budget = [max_elements]
    return [_walk(node, path, None, 0, max_depth, budget) for path, node in _roots(app, window_id)]


# Elements a person can act on, for actionable finds (e.g. to choose which one achieves a goal)
ACTIONABLE_ROLES = {"push button", "button", "toggle button", "link", "entry", "password text", "combo box", "check box",
                    "radio button", "menu item", "check menu item", "radio menu item", "page tab", "list item",
                    "tree item", "spin button", "slider", "switch"}


def find(role=None, name=None, app=None, limit=20, window_id=None, within=None, include_browser_ui=False,
         actionable=False):
    """Elements with this role (loosely: "treeitem" finds "tree item"; see roles.py) whose name contains `name`
    (case-insensitive), as a flat list. Some apps (Slack) leave names empty and put the label in the element's text, so
    `name` matches the text too. When nothing matches, a note says which roles the search did see, so a wrong guess at
    a role name isn't mistaken for an empty tree."""
    name = name.lower() if name else None
    found, browser_ui = [], []
    seen_roles = Counter()

    def visit(node, path, window, depth, in_page):
        # (an application node itself may not claim to be on screen, e.g. LibreOffice's, so only filter below it)
        if len(found) >= limit or sum(seen_roles.values()) >= MAX_VISITED or depth > 30 or (depth > 0 and not _visible(node, window)):
            return
        node_role = node.get_role_name() or ""
        seen_roles[node_role] += 1
        window = _window_for(node, window)
        in_page = in_page or node_role == "document web"
        wanted = (not role or roles.matches(role, node_role)) and (not name or name in _label(node))
        if wanted and actionable:  # only labelled elements a person could press or type into
            wanted = node_role in ACTIONABLE_ROLES and bool(_label(node).strip())
        if wanted:
            # In a browser, matches outside the page are the browser's own controls (tabs, its close button), which
            # an agent looking for a page's "Close" must not press by mistake: keep them apart
            (found if in_page or include_browser_ui else browser_ui).append(describe(node, path, window))
        for i in range(min(node.get_child_count(), MAX_CHILDREN)):
            child = node.get_child_at_index(i)
            if child is not None:
                visit(child, f"{path}/{i}", window, depth + 1, in_page)

    # `within` searches inside one element (e.g. one message, so its "More actions" isn't another message's)
    search_roots = [(within, node_at(within))] if within else _roots(app, window_id)
    for path, node in search_roots:
        visit(node, path, _window_above(path) if within else None, 0, bool(within))
    if not seen_roles.get("document web"):
        found += browser_ui  # not a browser window: there's no page to tell its controls apart from
        browser_ui = []

    result = {"elements": found}
    if browser_ui:
        result["browser_ui_left_out"] = len(browser_ui)  # pass include_browser_ui to get them
    if sum(seen_roles.values()) >= MAX_VISITED:
        result["note"] = f"Stopped after {MAX_VISITED} elements; narrow it with window_id, role or name"
    elif not found:
        result["note"] = _nothing_found(role, name, seen_roles)
    return result


def _nothing_found(role, name, seen_roles):
    """Say what the search did see: "nothing matched" and "nothing here" need different next steps."""
    content = {r: n for r, n in seen_roles.items() if r not in ROLE_BOUNDARY and r not in ("application", "panel", "filler")}
    if not content:
        return "This window publishes no accessibility tree (or nothing in it is visible): use screenshots for it."
    wanted = " and ".join(part for part in [role and f"role {role!r}", name and f"name containing {name!r}"] if part)
    listed = ", ".join(f"{r} ×{n}" for r, n in Counter(content).most_common(15))
    return f"Nothing matched {wanted or 'that'}. Roles in what was searched: {listed}."


def wait(role=None, name=None, app=None, window_id=None, timeout=10, gone=False):
    """Wait until an element with this role and/or name is on screen (or, with `gone`, until none is), e.g. for a
    page to load or a dialog to close: one call instead of waiting, taking a screenshot and looking. Returns the
    element found and how long it took, or says it timed out."""
    if not role and not name:
        raise ValueError("Give a role and/or a name to wait for")

    def check():
        elements = find(role, name, app, limit=1, window_id=window_id)["elements"]
        return {"gone": True} if gone and not elements else (elements[0] if elements and not gone else None)

    result, waited = waiting.until(check, timeout)
    if not result:
        thing = " ".join(part for part in [role, name and repr(name)] if part)
        return {"timed_out": True, "waited": waited,
                "note": f"After {waited}s, {thing} is {'still there' if gone else 'not on screen'}"}
    return {"waited": waited, **({"gone": True} if gone else {"element": result})}


def press(path=None, role=None, name=None, window_id=None, within=None, click=False):
    """Activate an element the way a screen reader would: its "click"/"press"/"activate" action. The element is
    given by its path, or by role and/or name (looked up now, so it can't have gone stale since it was found). Some
    web menus ignore that action; `click` clicks the middle of the element with the mouse instead."""
    node, path = _resolve(path, role, name, window_id, within)
    _on_screen(node)
    if click:
        bounds = _bounds(node, _window_above(path) if "/" in path else None) or {}
        if not bounds:
            raise ValueError(f"{node.get_role_name()} {node.get_name()!r} has no position on screen to click")
        mouse.move_to(bounds["x"] + bounds["width"] // 2, bounds["y"] + bounds["height"] // 2)
        mouse.click("left")
        return {"clicked": path, "role": node.get_role_name(), "name": node.get_name() or ""}
    action = node.get_action_iface()
    if action is None or action.get_n_actions() == 0:
        raise ValueError(f"{node.get_role_name()} {node.get_name()!r} has no action; press it with click: true")
    names = [action.get_action_name(i) for i in range(action.get_n_actions())]
    preferred = next((i for i, n in enumerate(names) if n in ("click", "press", "activate", "jump")), 0)
    action.do_action(preferred)
    # What was pressed, not only where: a press that silently hit the wrong element looked like it worked
    return {"pressed": names[preferred], "path": path, "role": node.get_role_name(), "name": node.get_name() or ""}


def set_text(text, path=None, role=None, name=None, window_id=None, within=None):
    """Replace the text of an editable element (a text field), given by path or by role and/or name."""
    node, path = _resolve(path, role, name, window_id, within, include_browser_ui=True)
    _on_screen(node)
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
    keyboard.press("BackSpace")  # clear it, even when the new text is empty
    keyboard.type_text(text)
    return {"method": "typed"}


# --- helpers ----------------------------------------------------------------------------------------------------

def _resolve(path, role, name, window_id, within, include_browser_ui=False):
    """The element to act on, and its path: by path, or the first visible match for role and/or name. Pressing by
    name never reaches the browser's own controls (its close-tab button); typing can (its address bar)."""
    if path:
        node = node_at(path)
        paths.check(path, node.get_role_name(), node.get_name() or "")
        return node, path
    if not role and not name:
        raise ValueError("Give the element's path, or its role and/or name")
    matches = find(role, name, limit=1, window_id=window_id, within=within, include_browser_ui=include_browser_ui)["elements"]
    if not matches:
        thing = " ".join(part for part in [role, name and repr(name)] if part)
        raise LookupError(f"No {thing} on screen{' in that window' if window_id else ''}; look again with find")
    return node_at(matches[0]["path"]), matches[0]["path"]


def _roots(app=None, window_id=None):
    """Where to start looking: every app, the apps whose name contains `app`, or just the top-level element of one
    window (from GET /windows), so an agent working in its own window doesn't wade through the person's others. A
    window is matched to its app by process ID, and to the app's top-level element by title."""
    if window_id is None:
        return [(path, node) for path, node in apps() if not app or app.lower() in (node.get_name() or "").lower()]
    window = next((w for w in desktop.windows() if w["id"] == window_id), None)
    if window is None:
        raise LookupError(f"No window {window_id!r}; it may have closed. List the windows again.")
    frames = []
    for path, node in apps():
        if node.get_process_id() != window["pid"]:
            continue
        for i in range(node.get_child_count()):
            child = node.get_child_at_index(i)
            if child is not None and child.get_role_name() in ROLE_BOUNDARY:
                frames.append((f"{path}/{i}", child))
    roots = [f for f in frames if f[1].get_name() == window["title"]]
    if not roots and window["focused"]:
        # The app's name for the window can lag behind a title change; the focused window's frame is the active one
        roots = [f for f in frames if f[1].get_state_set().contains(Atspi.StateType.ACTIVE)]
    if not roots:
        raise LookupError(f"Window {window_id!r} ({window['title']!r}) publishes no accessibility tree")
    if len(roots) > 1:
        # Two windows with the same title (two Slack windows): the focused window's frame is the "active" one
        active = [r for r in roots if r[1].get_state_set().contains(Atspi.StateType.ACTIVE)]
        roots = active if window["focused"] else [r for r in roots if r not in active]
        if len(roots) != 1:
            raise LookupError(f"Several windows are titled {window['title']!r}; focus window {window_id!r} first, "
                              "so its tree can be told apart")
    return roots


def _walk(node, path, window, depth, max_depth, budget):
    window = _window_for(node, window)
    info = describe(node, path, window)
    budget[0] -= 1
    if depth < max_depth:
        children = []
        for i in range(min(node.get_child_count(), MAX_CHILDREN)):
            child = node.get_child_at_index(i)
            if budget[0] <= 0:
                info["truncated"] = True
                break
            if child is not None and _visible(child, window):
                children.append(_walk(child, f"{path}/{i}", window, depth + 1, max_depth, budget))
        if children:
            info["children"] = children
    return info


def _window_above(path):
    """The Window context an element inherits, worked out by walking down to it from its app."""
    window, node, parts = None, None, path.split("/")
    for depth in range(1, len(parts)):
        node = node_at("/".join(parts[:depth]))
        window = _window_for(node, window)
    return window


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
    """An element's text (its first 500 characters), or None. An element that can't be read (it went away while we
    were reading, which busy web apps do) has no text, rather than failing the whole tree or search."""
    try:
        text = node.get_text_iface()
        if text is None:
            return None
        count = Atspi.Text.get_character_count(text)
        return _with_links(node, Atspi.Text.get_text(text, 0, min(count, 500))) if count else None
    except Exception:  # GLib.Error and friends from an element that's gone
        return None


# Elements that only group others: their text is all of their children's, so it's no label
CONTAINER_ROLES = {"panel", "section", "filler", "grouping", "scroll pane", "list", "tree", "table", "log",
                   "tool bar", "document web", "document frame", "frame", "application"}


def _on_screen(node):
    """Only act on what the person could see. Web apps keep views you've left loaded but hidden (Slack keeps every
    conversation you've visited, Send buttons and all), and acting on one of those does something nobody can see.
    An element that's only scrolled out of view (visible, not showing) is scrolled into view first."""
    states = node.get_state_set()
    if not states.contains(Atspi.StateType.SHOWING) and states.contains(Atspi.StateType.VISIBLE):
        _scroll_into_view(node)
    if not node.get_state_set().contains(Atspi.StateType.SHOWING):
        raise ValueError(f"{node.get_role_name()} {node.get_name()!r} isn't on screen. If it's on a part of the page "
                         "scrolled out of view, scroll to it first; otherwise it may belong to a hidden view, so "
                         "look again with window_id or within")
    return node


def _scroll_into_view(node):
    component = node.get_component_iface()
    try:
        if component is not None and Atspi.Component.scroll_to(component, Atspi.ScrollType.ANYWHERE):
            time.sleep(0.3)  # let the page settle, so the element reports itself showing
    except Exception:  # an older AT-SPI without scroll_to, or an element that went away
        pass


def _url(node):
    """A link's target, from its hyperlink interface (Chromium and GTK publish it), or None."""
    try:
        hyperlink = node.get_hyperlink()
        return hyperlink.get_uri(0) if hyperlink is not None and hyperlink.get_n_anchors() > 0 else None
    except Exception:  # not a hyperlink after all, or it went away
        return None


def _label(node):
    """An element's name, or (for elements that aren't just containers) its text when it has no name, lowercased."""
    if node.get_name():
        return node.get_name().lower()
    return "" if node.get_role_name() in CONTAINER_ROLES else (_text(node) or "").lower()


def _with_links(node, text):
    """Put the words of the elements inside a text back where its placeholders are, so "the father of \ufffc" reads
    "the father of computer science" (placeholders.py)."""
    if placeholders.PLACEHOLDER not in text:
        return text
    hypertext = node.get_hypertext_iface()
    links = Atspi.Hypertext.get_n_links(hypertext) if hypertext else 0
    return placeholders.fill(text, [_link_words(hypertext, i) for i in range(links)])


def _link_words(hypertext, index):
    """The words of one element inside a text. Apps don't always give one for every placeholder (Slack sometimes
    returns no link at all for an index), so a missing link or element just has no words."""
    link = Atspi.Hypertext.get_link(hypertext, index)
    target = link.get_object(0) if link else None
    return (_text(target) or target.get_name() or "") if target else ""


def _visible(node, window):
    """Whether to include an element. Inside a web page, anything not hidden, including what's scrolled out of view
    (most of a long page). Everywhere else, only what's on screen: native apps count closed menus as "visible" too."""
    in_web_page = window is not None and window.device_pixels
    try:
        return node.get_state_set().contains(Atspi.StateType.VISIBLE if in_web_page else Atspi.StateType.SHOWING)
    except Exception:  # the element went away while we were reading it
        return False
