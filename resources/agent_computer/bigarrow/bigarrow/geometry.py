"""Where everything goes: the sign, the shaft and the head, for a target on a screen. Pure arithmetic, no drawing.

All coordinates are layout units (what Hyprland reports for windows and the cursor) relative to the monitor the
arrow is drawn on, y down. A target is a rectangle; a point is a rectangle with no size.
"""

import math
from dataclasses import asdict, dataclass

MARGIN = 16  # keep the sign this far inside the screen's edges
GAP = 8      # between the head (or an outline) and what it points at


@dataclass(frozen=True)
class Rect:
    x: float
    y: float
    width: float = 0
    height: float = 0

    @property
    def center(self):
        return self.x + self.width / 2, self.y + self.height / 2

    def inflate(self, by):
        return Rect(self.x - by, self.y - by, self.width + 2 * by, self.height + 2 * by)

    def overlap(self, other):
        dx = min(self.x + self.width, other.x + other.width) - max(self.x, other.x)
        dy = min(self.y + self.height, other.y + other.height) - max(self.y, other.y)
        return max(dx, 0) * max(dy, 0)


@dataclass(frozen=True)
class Size:
    font: float        # the sign's text, in points
    length: float      # the shaft, from the sign to the head
    width: float       # the shaft's stroke
    head: float        # the head's length
    text_width: float  # the sign's text wraps beyond this

    @property
    def border(self):  # the white edge around everything
        return max(self.width * 0.45, 2.5)


SIZES = {"S": Size(13, 80, 7, 22, 320), "M": Size(17, 115, 10, 30, 380), "L": Size(24, 170, 14, 42, 460)}


def size(name="M", scale=1.0):
    """A preset, made bigger or smaller by `scale` (everything together: text, shaft, stroke, head)."""
    if not 0.2 <= scale <= 5:
        raise ValueError(f"Scale {scale} is out of range: 0.2 to 5")
    return Size(*(value * scale for value in asdict(SIZES[name]).values()))

# Where the sign sits, seen from the target ("from top": the arrow comes down from above). Diagonals first: a slanted
# arrow reads as pointing, a level one next to a button can read as underlining it.
DIRECTIONS = {
    "bottom-right": (1, 1), "bottom-left": (-1, 1), "top-right": (1, -1), "top-left": (-1, -1),
    "right": (1, 0), "left": (-1, 0), "bottom": (0, 1), "top": (0, -1),
}


@dataclass(frozen=True)
class Plan:
    direction: str
    sign: Rect
    tail: tuple      # where the shaft leaves the sign
    control: tuple   # the shaft's curve (a quadratic Bézier control point)
    tip: tuple       # the head's point
    outline: Rect | None  # the ring's or box's bounds, around the target
    moved: float = 0      # how far the sign had to move to stay on screen

    def as_dict(self):
        return asdict(self)

    @classmethod
    def from_dict(cls, d):
        rect = lambda r: Rect(**r) if r else None  # noqa: E731
        return cls(d["direction"], rect(d["sign"]), tuple(d["tail"]), tuple(d["control"]), tuple(d["tip"]),
                   rect(d["outline"]), d.get("moved", 0))


def plan(target, screen, sign_size, style="arrow", size=SIZES["M"], direction="auto", shape="bend", avoid=()):
    """Where to draw, for `target` (a Rect) on `screen` (a Rect, usually at 0,0) with a sign of `sign_size`
    (width, height). `direction` is a key of DIRECTIONS or "auto": the side the sign fits best, clear of the target
    and of `avoid` (other arrows' signs)."""
    if direction != "auto":
        return _plan(target, screen, sign_size, style, size, direction, shape)
    candidates = [_plan(target, screen, sign_size, style, size, name, shape) for name in DIRECTIONS]
    return min(candidates, key=lambda p: _cost(p, target, size, avoid))


def _plan(target, screen, sign_size, style, size, direction, shape):
    dx, dy = DIRECTIONS[direction]
    norm = math.hypot(dx, dy)
    ux, uy = dx / norm, dy / norm
    cx, cy = target.center
    outline = _outline(target, style)

    # The head stops just short of the target's edge (or the outline's), on the line from its center toward the sign
    if style == "ring":
        rx, ry = outline.width / 2, outline.height / 2
        reach = 1 / math.hypot(ux / rx, uy / ry) + GAP
    else:
        bounds = outline or target
        hw, hh = bounds.width / 2, bounds.height / 2
        reach = min(hw / abs(ux) if ux else math.inf, hh / abs(uy) if uy else math.inf)
        reach = (0 if reach == math.inf else reach) + GAP
    tip = (cx + ux * reach, cy + uy * reach)

    # The sign's nearest corner (or edge's middle) a shaft's length further out, then nudged back onto the screen
    width, height = sign_size
    sx = tip[0] + ux * size.length + (math.copysign(width / 2, dx) if dx else 0)
    sy = tip[1] + uy * size.length + (math.copysign(height / 2, dy) if dy else 0)
    wanted = sx, sy
    sx = min(max(sx, screen.x + MARGIN + width / 2), screen.x + screen.width - MARGIN - width / 2)
    sy = min(max(sy, screen.y + MARGIN + height / 2), screen.y + screen.height - MARGIN - height / 2)
    moved = math.hypot(sx - wanted[0], sy - wanted[1])
    sign = Rect(sx - width / 2, sy - height / 2, width, height)

    tail = _edge_toward(sign, tip)
    mx, my = (tail[0] + tip[0]) / 2, (tail[1] + tip[1]) / 2
    if shape == "bend":
        # Bowed a little to one side, always the same way round, like a hand-drawn arrow
        length = math.hypot(tip[0] - tail[0], tip[1] - tail[1])
        nx, ny = (tip[1] - tail[1]) / (length or 1), -(tip[0] - tail[0]) / (length or 1)
        control = (mx + nx * length * 0.2, my + ny * length * 0.2)
    else:
        control = (mx, my)
    return Plan(direction, sign, tail, control, tip, outline, moved)


def _outline(target, style):
    if style == "box":
        return target.inflate(6)
    if style == "ring":  # an ellipse through the rectangle's corners, and a little more
        cx, cy = target.center
        rx, ry = max(target.width / 2, 8) * math.sqrt(2) + 6, max(target.height / 2, 8) * math.sqrt(2) + 6
        return Rect(cx - rx, cy - ry, 2 * rx, 2 * ry)
    return None


def _along(p, count):
    """Points along the shaft, from the sign to the tip."""
    for i in range(count + 1):
        t = i / count
        yield tuple((1 - t) ** 2 * a + 2 * (1 - t) * t * c + t ** 2 * b for a, c, b in zip(p.tail, p.control, p.tip))


def _inside(rect, point):
    return rect.x <= point[0] <= rect.x + rect.width and rect.y <= point[1] <= rect.y + rect.height


def _edge_toward(rect, point):
    """Where the line from the rectangle's center to `point` leaves it."""
    cx, cy = rect.center
    vx, vy = point[0] - cx, point[1] - cy
    if not vx and not vy:
        return cx, cy
    scale = min(rect.width / 2 / abs(vx) if vx else math.inf, rect.height / 2 / abs(vy) if vy else math.inf, 1)
    return cx + vx * scale, cy + vy * scale


def _cost(p, target, size, avoid=()):
    """Lower is better: a sign covering the target or another sign, a shaft crossing another sign, a sign that had to
    move to stay on screen, a shaft squashed short."""
    covered = p.sign.overlap((p.outline or target).inflate(GAP)) + sum(p.sign.overlap(o.inflate(GAP)) for o in avoid)
    crossing = sum(_inside(o.inflate(size.width), point) for o in avoid for point in _along(p, 20))
    covered += crossing * size.length * size.width
    shaft = math.hypot(p.tip[0] - p.tail[0], p.tip[1] - p.tail[1])
    squashed = max(size.length - shaft, 0)
    return covered * 10 + squashed * 4 + p.moved + list(DIRECTIONS).index(p.direction)
