"""Drawing a Plan with cairo: the same code paints the overlay and --png images.

Each part gets a soft shadow, then a white (or black) border, then its colour, so the arrow reads on any background.
"""

import math

import cairo
import gi

gi.require_version("Pango", "1.0")
gi.require_version("PangoCairo", "1.0")
from gi.repository import Pango, PangoCairo  # noqa: E402

from .geometry import SIZES  # noqa: E402

COLORS = {
    "red": "#FF3B30", "orange": "#FF9500", "yellow": "#FFCC00", "green": "#34C759", "teal": "#30B0C7",
    "blue": "#007AFF", "purple": "#AF52DE", "pink": "#FF2D55", "black": "#1C1C1E", "white": "#FFFFFF",
}
PADDING = 0.6  # of the font size, around the text


def color(value):
    """(r, g, b) from a name in COLORS or #RRGGBB; ValueError otherwise."""
    value = COLORS.get(value.lower(), value)
    if len(value) != 7 or value[0] != "#":
        raise ValueError(f"Unknown colour {value!r}: use {', '.join(COLORS)} or #RRGGBB")
    return tuple(int(value[i:i + 2], 16) / 255 for i in (1, 3, 5))


def _light(rgb):
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2] > 0.6


def _layout(context, text, size):
    layout = PangoCairo.create_layout(context)
    font = Pango.FontDescription.from_string("Sans Bold")
    font.set_size(round(size.font * Pango.SCALE))
    layout.set_font_description(font)
    layout.set_width(round(size.text_width * Pango.SCALE))
    layout.set_wrap(Pango.WrapMode.WORD_CHAR)
    layout.set_alignment(Pango.Alignment.CENTER)
    layout.set_text(text, -1)
    return layout


def sign_size(text, size=SIZES["M"]):
    """The sign's (width, height) for `text`, padding included; (0, 0) without text."""
    if not text:
        return 0, 0
    context = cairo.Context(cairo.ImageSurface(cairo.FORMAT_ARGB32, 1, 1))
    _, logical = _layout(context, text, size).get_pixel_extents()
    pad = size.font * PADDING
    return logical.width + 2 * pad, logical.height + 2 * pad


def draw(context, plan, text, rgb, size=SIZES["M"], style="arrow", opacity=1.0):
    """Paints the arrow (and its outline and sign) onto `context`, in the plan's coordinates."""
    s = size
    border = (0, 0, 0) if rgb == (1.0, 1.0, 1.0) else (1, 1, 1)  # a white arrow gets a black border
    context.push_group()
    for layer in ("shadow", "border", "fill"):
        context.save()
        if layer == "shadow":
            context.translate(0, 3)
            paint, extra = (0, 0, 0, 0.28), s.border * 1.4
        elif layer == "border":
            paint, extra = (*border, 1), s.border
        else:
            paint, extra = (*rgb, 1), 0
        context.set_source_rgba(*paint)
        context.set_line_cap(cairo.LINE_CAP_ROUND)
        context.set_line_join(cairo.LINE_JOIN_ROUND)

        if plan.outline and style in ("ring", "box"):
            _outline_path(context, plan.outline, style)
            context.set_line_width(s.width * 0.7 + extra)
            context.stroke()
        if plan.sign.width:
            _shaft(context, plan, s, extra)
            _head(context, plan, s, extra)
            _rounded(context, plan.sign, min(s.font * 0.6, plan.sign.height / 2))
            if extra:
                context.set_line_width(extra)
                context.stroke_preserve()
            context.fill()
        else:  # no sign: just the arrow, from a shaft's length out
            _shaft(context, plan, s, extra)
            _head(context, plan, s, extra)
        context.restore()

    if text and plan.sign.width:
        layout = _layout(context, text, size)
        _, logical = layout.get_pixel_extents()
        context.set_source_rgb(*((0.08, 0.08, 0.08) if _light(rgb) else (1, 1, 1)))
        context.move_to(plan.sign.x + (plan.sign.width - logical.width) / 2 - logical.x,
                        plan.sign.y + (plan.sign.height - logical.height) / 2 - logical.y)
        PangoCairo.show_layout(context, layout)
    context.pop_group_to_source()
    context.paint_with_alpha(opacity)


def _shaft(context, plan, s, extra):
    base = _head_base(plan, s)
    context.move_to(*plan.tail)
    context.curve_to(*_cubic(plan.tail, plan.control, base))
    context.set_line_width(s.width + extra)
    context.stroke()


def _head(context, plan, s, extra):
    (tx, ty), (ux, uy) = plan.tip, _direction(plan)
    half = s.head * 0.62
    bx, by = tx - ux * s.head, ty - uy * s.head
    context.move_to(tx, ty)
    context.line_to(bx - uy * half, by + ux * half)
    context.line_to(bx + uy * half, by - ux * half)
    context.close_path()
    if extra:
        context.set_line_width(extra)
        context.stroke_preserve()
    context.fill()


def _direction(plan):
    """The way the head points: along the curve as it arrives at the tip."""
    vx, vy = plan.tip[0] - plan.control[0], plan.tip[1] - plan.control[1]
    length = math.hypot(vx, vy) or 1
    return vx / length, vy / length


def _head_base(plan, s):
    ux, uy = _direction(plan)
    return plan.tip[0] - ux * s.head * 0.8, plan.tip[1] - uy * s.head * 0.8


def _cubic(start, control, end):
    """A quadratic Bézier's control point as cairo's cubic ones, ending at `end`."""
    c1 = (start[0] + 2 / 3 * (control[0] - start[0]), start[1] + 2 / 3 * (control[1] - start[1]))
    c2 = (end[0] + 2 / 3 * (control[0] - end[0]), end[1] + 2 / 3 * (control[1] - end[1]))
    return (*c1, *c2, *end)


def _outline_path(context, rect, style):
    if style == "box":
        _rounded(context, rect, 10)
        return
    context.save()
    context.translate(*rect.center)
    context.scale(rect.width / 2, rect.height / 2)
    context.arc(0, 0, 1, 0, 2 * math.pi)
    context.restore()


def _rounded(context, rect, radius):
    x, y, w, h = rect.x, rect.y, rect.width, rect.height
    context.new_sub_path()
    context.arc(x + w - radius, y + radius, radius, -math.pi / 2, 0)
    context.arc(x + w - radius, y + h - radius, radius, 0, math.pi / 2)
    context.arc(x + radius, y + h - radius, radius, math.pi / 2, math.pi)
    context.arc(x + radius, y + radius, radius, math.pi, 3 * math.pi / 2)
    context.close_path()


def png(path, plan, text, rgb, screen, size=SIZES["M"], style="arrow", backdrop=None):
    """Writes the arrow to a PNG of the screen's size: over `backdrop` (a screenshot, scaled to fit), or transparent."""
    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, round(screen.width), round(screen.height))
    context = cairo.Context(surface)
    if backdrop:
        image = cairo.ImageSurface.create_from_png(backdrop)
        context.save()
        context.scale(screen.width / image.get_width(), screen.height / image.get_height())
        context.set_source_surface(image)
        context.paint()
        context.restore()
    context.translate(-screen.x, -screen.y)
    draw(context, plan, text, rgb, size, style)
    surface.write_to_png(path)
