"""The command line, drawing into PNGs (no display needed, but Pango and cairo are: skipped without PyGObject)."""

import contextlib
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path


@unittest.skipUnless(importlib.util.find_spec("gi") and importlib.util.find_spec("cairo"), "needs PyGObject and pycairo")
class CliTest(unittest.TestCase):
    def run_cli(self, *args):
        from bigarrow.__main__ import main

        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = main([*args, "--json", "--screen", "1536,864"])
        return code, json.loads(out.getvalue())

    def test_draws_into_a_png_and_says_where(self):
        import cairo

        path = Path(tempfile.mkdtemp()) / "arrow.png"
        code, result = self.run_cli("point", "--rect", "700,400,120,40", "--text", "Click Save", "--from", "right",
                                    "--png", str(path))
        self.assertEqual((code, result["from"]), (0, "right"))
        image = cairo.ImageSurface.create_from_png(str(path))
        self.assertEqual((image.get_width(), image.get_height()), (1536, 864))
        sign, stride, data = result["plan"]["sign"], image.get_stride(), image.get_data()
        center = int(sign["y"] + sign["height"] / 2) * stride + int(sign["x"] + 6) * 4
        self.assertEqual(data[center + 3], 255)  # opaque on the sign
        self.assertEqual(data[10 * stride + 10 * 4 + 3], 0)  # transparent elsewhere

    def test_bad_input_and_missing_targets_have_their_own_exit_codes(self):
        self.assertEqual(self.run_cli("point", "--at", "1,1", "--color", "nope")[0], 2)
        self.assertEqual(self.run_cli("point", "--at", "1", "--dry-run")[0], 2)
        code, result = self.run_cli("point", "--at", "100,100", "--size", "s", "--style", "ring", "--dry-run")
        self.assertEqual(code, 0)
        self.assertIsNotNone(result["plan"]["outline"])


if __name__ == "__main__":
    unittest.main()
