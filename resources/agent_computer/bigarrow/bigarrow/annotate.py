"""Marking up a screenshot after the fact: a box round each thing an agent acted on, with an arrow and a sign saying
what it did ("Clicked “Pay invoice”"), so a person reading back a run sees what was done and where. Works on the
image alone: no display, no Wayland.

    from bigarrow.annotate import annotate
    marked = annotate(png_bytes, [{"rect": (812, 404, 120, 36), "text": "Clicked “Pay invoice”"}])
"""

import io

import cairo

from . import geometry, render
from .geometry import Rect

REFERENCE_WIDTH = 1536  # the size presets suit a screen this wide; a wider or narrower image scales them to match


def annotate(png, marks, color="red", size="S"):
    """`png` (bytes) with `marks` drawn on, as PNG bytes. Each mark is a dict: `rect` (x, y, width, height, in the
    image's pixels) and `text` (the sign; may be empty). A mark whose rect is off the image gets no box, and the signs
    keep clear of each other."""
    image = cairo.ImageSurface.create_from_png(io.BytesIO(png))
    screen = Rect(0, 0, image.get_width(), image.get_height())
    scale = min(max(screen.width / REFERENCE_WIDTH, 0.5), 3)
    sizes = geometry.size(size, scale)
    rgb = render.color(color)
    context = cairo.Context(image)
    signs = []
    for mark in marks:
        target = _on_image(Rect(*mark["rect"]), screen)
        if target is None:
            continue
        text = mark.get("text") or ""
        plan = geometry.plan(target, screen, render.sign_size(text, sizes), "box", sizes, avoid=signs)
        render.draw(context, plan, text, rgb, sizes, "box")
        if plan.sign.width:
            signs.append(plan.sign)
    out = io.BytesIO()
    image.write_to_png(out)
    return out.getvalue()


def _on_image(rect, screen):
    """The part of `rect` on the image, or None if none of it is (scrolled out of view)."""
    left, top = max(rect.x, 0), max(rect.y, 0)
    right, bottom = min(rect.x + rect.width, screen.width), min(rect.y + rect.height, screen.height)
    if right - left < 1 or bottom - top < 1:
        return None
    return Rect(left, top, right - left, bottom - top)
