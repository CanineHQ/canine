"""Where the sign, shaft and head go: plain arithmetic, no display needed."""

import math
import unittest

from bigarrow.geometry import GAP, MARGIN, Rect, plan, size

SCREEN = Rect(0, 0, 1536, 864)


def inside(rect, point):
    return rect.x <= point[0] <= rect.x + rect.width and rect.y <= point[1] <= rect.y + rect.height


class GeometryTest(unittest.TestCase):
    def test_the_sign_goes_where_there_is_room_and_never_covers_the_target(self):
        for target in (Rect(1480, 20, 40, 24), Rect(20, 820, 60, 30), Rect(700, 400, 120, 40), Rect(10, 10)):
            p = plan(target, SCREEN, (300, 60))
            self.assertEqual(p.sign.overlap(target.inflate(GAP)), 0, (target, p.direction))
            self.assertTrue(inside(SCREEN.inflate(-MARGIN + 0.01), (p.sign.x, p.sign.y)), p)
            self.assertTrue(inside(SCREEN.inflate(-MARGIN + 0.01), (p.sign.x + p.sign.width, p.sign.y + p.sign.height)))
        self.assertEqual(plan(Rect(1480, 20, 40, 24), SCREEN, (300, 60)).direction, "bottom-left")  # the top right corner
        self.assertEqual(plan(Rect(20, 820, 60, 30), SCREEN, (300, 60)).direction, "top-right")

    def test_signs_keep_out_of_each_others_way(self):
        target = Rect(700, 400, 120, 40)
        first = plan(target, SCREEN, (300, 60))
        second = plan(target, SCREEN, (300, 60), avoid=[first.sign])
        self.assertEqual(second.sign.overlap(first.sign.inflate(GAP)), 0)
        self.assertNotEqual(second.direction, first.direction)

        # A target just below another arrow's sign: this arrow comes from below, rather than through that sign
        other_sign = Rect(1000, 330, 420, 60)
        under = plan(Rect(1100, 400, 80, 30), SCREEN, (120, 30), avoid=[other_sign])
        self.assertFalse(any(inside(other_sign, point) for point in (under.tail, under.control, under.tip)))
        self.assertIn("bottom", under.direction)

    def test_the_head_stops_just_short_of_the_target(self):
        button = Rect(700, 400, 120, 40)
        p = plan(button, SCREEN, (300, 60), direction="right")
        self.assertEqual(p.tip, (820 + GAP, 420))
        self.assertGreater(p.sign.x, p.tip[0])  # to the right, as asked
        self.assertEqual(plan(Rect(300, 300), SCREEN, (0, 0), direction="top").tip, (300, 300 - GAP))

        ring = plan(button, SCREEN, (300, 60), style="ring", direction="bottom")
        self.assertGreater(ring.tip[1], ring.outline.y + ring.outline.height)  # below the ring, not inside it
        self.assertTrue(inside(ring.outline, button.center) and ring.outline.width > button.width)

    def test_scale_makes_everything_bigger_or_smaller_together(self):
        self.assertEqual(size("M", 0.5).font, size("M").font / 2)
        self.assertEqual(size("L", 2).head, size("L").head * 2)
        target = Rect(700, 400)
        small = plan(target, SCREEN, (0, 0), size=size("M", 0.5), direction="left")
        normal = plan(target, SCREEN, (0, 0), size=size("M"), direction="left")
        self.assertAlmostEqual(small.tip[0] - small.tail[0], (normal.tip[0] - normal.tail[0]) / 2)
        with self.assertRaises(ValueError):
            size("M", 0)

    def test_straight_and_bent_shafts(self):
        straight = plan(Rect(700, 400, 120, 40), SCREEN, (300, 60), direction="top-left", shape="straight")
        bent = plan(Rect(700, 400, 120, 40), SCREEN, (300, 60), direction="top-left")
        self.assertEqual(straight.control, ((straight.tail[0] + straight.tip[0]) / 2, (straight.tail[1] + straight.tip[1]) / 2))
        self.assertGreater(math.dist(bent.control, straight.control), 10)


if __name__ == "__main__":
    unittest.main()
