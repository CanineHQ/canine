"""What a browse step did, in words a person reads back later, and where on its screenshot: "Clicked “Pay invoice”",
"Typed “1,240.00” into “Amount”", with a box and an arrow drawn round each on the step's screenshot (bigarrow), so
Canine's timeline shows which buttons were pressed and where.

browser-use decides a step's actions from a screenshot and the page's elements, then runs them. `plan` is called in
between (browse.py hooks it in), while the elements the actions name are still where that screenshot shows them, and
`draw` marks that screenshot afterwards. An element that was off it (below the fold: browser-use scrolls to it before
acting) is marked instead on a screenshot taken once the step is done (`after`), which also shows what was typed or
chosen. Element positions are CSS pixels in the viewport, screenshots are device pixels: `_rect` converts.
"""

import asyncio
import base64
import os
import struct

TRUNCATE = 60
POINT = 24  # the size of the box marking a click at a point (pixels of the model's screenshot)
# The size the model's screenshots are scaled to (browse.py passes it to browser-use). The model clicks at points on
# that image, and browser-use maps them onto the page in proportion; without it, they'd be taken as CSS pixels while
# the model sees device pixels, missing by the display's scale (by 25% at 1.25).
LLM_SCREENSHOT_SIZE = (1400, 850)

# Actions on an element worth showing after the step when it wasn't on the screenshot before
SHOWN_AFTER = {"click", "input", "select_dropdown", "upload_file"}
AFTER_TIMEOUT = 5  # seconds for the screenshot after a step; past that, the step goes unmarked

# Actions that only read: they get words, never a mark
READING = {
    "extract": "Read the page", "search_page": "Searched the page", "find_elements": "Looked for elements",
    "find_text": "Looked for text", "screenshot": "Took a screenshot", "dropdown_options": "Read a dropdown's options",
    "read_file": "Read a file", "wait": "Waited", "write_file": "Wrote a file", "replace_file": "Edited a file",
}


def plan(state, output):
    """[{"did": "Clicked “Pay invoice”", "rect": [x, y, w, h] or None, ...}] for each action in the model's `output`,
    located on `state` (browser-use's BrowserStateSummary: the page as the model saw it). `rect` is None when the
    action has no element, or it's off the screenshot; the other keys are for `after`."""
    selector_map = getattr(getattr(state, "dom_state", None), "selector_map", None) or {}
    page = getattr(state, "page_info", None)
    ratio = _ratio(state.screenshot, page)
    size = _png_size(state.screenshot)
    planned = []
    for action in getattr(output, "action", None) or []:
        for name, params in action.model_dump(exclude_none=True).items():
            params = params if isinstance(params, dict) else {}
            node = selector_map.get(params.get("index")) if params.get("index") is not None else None
            rect = _rect(getattr(node, "absolute_position", None), ratio) or _point(params, size)
            planned.append({"did": describe(name, params, node), "rect": rect if _on(rect, size) else None,
                            "action": name, "node": node, "ratio": ratio})
    return planned


async def after(browser, planned):
    """(screenshot, marks) once the step is done, for its actions whose element wasn't on the screenshot before and is
    on the page now; None if there are none. The element is found again by its node id, where browser-use scrolled
    it to act on it."""
    missing = [p for p in planned if p["rect"] is None and p["action"] in SHOWN_AFTER and p["node"] is not None]
    if not missing:
        return None
    try:
        return await asyncio.wait_for(_after(browser, missing), AFTER_TIMEOUT)
    except Exception:
        return None


async def _after(browser, missing):
    """Each element is found on either side of the screenshot, and marked only where it was both times: a page still
    moving after the step (Amazon's Add to cart opens its cart panel and swaps the button for a stepper) would
    otherwise get a box where the element ended up, not where the screenshot shows it."""
    before = [await _locate(browser, p) for p in missing]
    screenshot = base64.b64encode(await browser.take_screenshot()).decode()
    size = _png_size(screenshot)
    marks = []
    for p, rect in zip(missing, before):
        if _on(rect, size) and _same(rect, await _locate(browser, p)):
            marks.append({"did": p["did"], "rect": rect})
    return (screenshot, marks) if marks else None


async def _locate(browser, p):
    session = await browser.get_or_create_cdp_session(p["node"].target_id, focus=False)
    return _rect(await browser.get_element_coordinates(p["node"].backend_node_id, session), p["ratio"])


def _same(a, b, tolerance=4):
    """Whether two rects are the same place, give or take a few pixels of rounding."""
    return a is not None and b is not None and all(abs(x - y) <= tolerance for x, y in zip(a, b))


def check_clicks(planned, results):
    """Moves a click's mark to where browser-use actually clicked, when that's not on the element planned (`results`:
    the step's ActionResults, in the same order as its actions, a click's with click_x/click_y in viewport CSS pixels).
    The element and its place come from the page as the model saw it, which can be out of date by the time of the click:
    on a GitHub dialog still opening, the button clicked was listed under a toolbar tooltip's name ("Heading"), in the
    wrong place. The name goes too, as it was the wrong element's."""
    for p, result in zip(planned, results):
        metadata = getattr(result, "metadata", None) or {}
        x, y = metadata.get("click_x"), metadata.get("click_y")
        if p["action"] != "click" or p["rect"] is None or x is None or y is None:
            continue  # an element that was off the screenshot is found again after the step (`after`)
        point = [x * p["ratio"], y * p["ratio"]]
        left, top, width, height = p["rect"]
        if not (left <= point[0] <= left + width and top <= point[1] <= top + height):
            p["rect"] = [round(point[0] - POINT / 2), round(point[1] - POINT / 2), POINT, POINT]
            p["did"] = "Clicked here"


def draw(screenshot, marks):
    """`screenshot` (base64 PNG) with each of `marks` ({"did", "rect"}) drawn on; None when there's nothing to mark,
    or bigarrow isn't installed (it needs Pango and cairo)."""
    marks = [{"rect": m["rect"], "text": m["did"]} for m in marks if m.get("rect")]
    if not screenshot or not marks:
        return None
    try:
        from bigarrow.annotate import annotate
    except ImportError:
        return None
    return base64.b64encode(annotate(base64.b64decode(screenshot), marks)).decode()


def describe(name, params, node=None):
    """One action as a short past-tense sentence."""
    target = _quoted(element_name(node)) or "an element"
    if name == "click":
        if node is None and params.get("coordinate_x") is not None:
            return f"Clicked at ({params['coordinate_x']}, {params['coordinate_y']})"
        return f"Clicked {target}"
    if name == "input":
        secret = node is not None and (node.attributes or {}).get("type") == "password"
        return f"Typed a password into {target}" if secret else f"Typed {_quoted(params.get('text', ''))} into {target}"
    if name == "select_dropdown":
        return f"Chose {_quoted(params.get('text', ''))} in {target}"
    if name == "upload_file":
        return f"Uploaded {os.path.basename(params.get('path', ''))} to {target}"
    if name == "navigate":
        return f"Opened {params.get('url', '')}"
    if name == "search":
        return f"Searched for {_quoted(params.get('query', ''))}"
    if name == "scroll":
        where = f" in {target}" if node is not None else ""
        return f"Scrolled {'down' if params.get('down', True) else 'up'}{where}"
    if name == "send_keys":
        return f"Pressed {params.get('keys', '')}"
    if name == "go_back":
        return "Went back"
    if name == "switch":
        return "Switched tabs"
    if name == "close":
        return "Closed a tab"
    if name == "evaluate":
        return "Ran a script on the page"
    if name == "done":
        return "Finished"
    return READING.get(name) or name.replace("_", " ").capitalize()


def element_name(node):
    """What a person would call the element: its accessible name, a label-ish attribute, or its text."""
    if node is None:
        return ""
    attributes = node.attributes or {}
    ax = getattr(node, "ax_node", None)
    candidates = [
        ax.name if ax else None, attributes.get("aria-label"), attributes.get("placeholder"), attributes.get("title"),
        attributes.get("alt"), _text(node), attributes.get("value") if attributes.get("type") != "password" else None,
        attributes.get("name"), attributes.get("id"),
    ]
    name = next((" ".join(c.split()) for c in candidates if c and c.strip()), "")
    return name or (node.tag_name or "").lower()


def _text(node):
    try:
        return node.get_all_children_text(max_depth=4)
    except Exception:
        return None


def _quoted(text):
    text = " ".join(str(text).split())
    if not text:
        return ""
    return f"“{text if len(text) <= TRUNCATE else text[:TRUNCATE - 1] + '…'}”"


def _ratio(screenshot, page):
    """Screenshot pixels per CSS pixel: the image's width over the viewport's (the device pixel ratio, as captured)."""
    size = _png_size(screenshot)
    if not size or not page or not page.viewport_width:
        return 1.0
    return size[0] / page.viewport_width


def _png_size(screenshot):
    """(width, height) from a base64 PNG's header, or None."""
    try:
        header = base64.b64decode(screenshot[:44])  # the PNG signature and IHDR: width and height at bytes 16-24
        return struct.unpack(">II", header[16:24]) if header[:8] == b"\x89PNG\r\n\x1a\n" else None
    except Exception:
        return None


def _point(params, size):
    """A small box round a click at a point (on the model's LLM_SCREENSHOT_SIZE image) as [x, y, width, height] on a
    screenshot of `size`, for an action without an element"""
    x, y = params.get("coordinate_x"), params.get("coordinate_y")
    if x is None or y is None or not size:
        return None
    scale_x, scale_y = size[0] / LLM_SCREENSHOT_SIZE[0], size[1] / LLM_SCREENSHOT_SIZE[1]
    return [round(x * scale_x - POINT / 2), round(y * scale_y - POINT / 2), POINT, POINT]


def _rect(position, ratio):
    """An element's position (CSS pixels in the viewport: browser-use's absolute_position, despite its name, is
    already scrolled, as its own highlighting assumes) as [x, y, width, height] in screenshot pixels."""
    if position is None or position.width <= 0 or position.height <= 0:
        return None
    return [round(position.x * ratio), round(position.y * ratio), round(position.width * ratio),
            round(position.height * ratio)]


def _on(rect, size):
    """Whether at least half of `rect` is on an image of `size`."""
    if rect is None or size is None:
        return False
    x, y, width, height = rect
    visible_w = min(x + width, size[0]) - max(x, 0)
    visible_h = min(y + height, size[1]) - max(y, 0)
    return visible_w > 0 and visible_h > 0 and visible_w * visible_h >= width * height / 2
