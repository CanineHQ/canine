"""The overlay's animation curve (skipped without GTK 4 and gtk4-layer-shell)."""

import ctypes.util
import importlib.util
import unittest


@unittest.skipUnless(importlib.util.find_spec("gi") and ctypes.util.find_library("gtk4-layer-shell"), "needs GTK 4 and gtk4-layer-shell")
class AppearanceTest(unittest.TestCase):
    def test_pops_in_from_the_tip_then_swells_and_shrinks_away(self):
        from bigarrow.overlay import APPEAR_SECONDS, EXIT_SECONDS, _appearance

        self.assertEqual(_appearance(0, None), (0, 0.85))
        self.assertEqual(_appearance(APPEAR_SECONDS, None), (1, 1))
        swell = _appearance(10, EXIT_SECONDS * 0.25)
        self.assertEqual(swell[0], 1.0)
        self.assertGreater(swell[1], 1.05)
        opacity, scale = _appearance(10, EXIT_SECONDS)
        self.assertAlmostEqual(opacity, 0)
        self.assertLess(scale, 0.5)


if __name__ == "__main__":
    unittest.main()
