import io
import unittest

try:
    import cairo

    from bigarrow.annotate import annotate
except (ImportError, ValueError):  # needs pycairo and PyGObject's Pango
    cairo = None


@unittest.skipIf(cairo is None, "needs pycairo and Pango")
class AnnotateTest(unittest.TestCase):
    def test_marks_a_screenshot_and_skips_what_is_off_it(self):
        surface = cairo.ImageSurface(cairo.FORMAT_RGB24, 800, 450)
        cairo.Context(surface).paint()  # black
        blank = io.BytesIO()
        surface.write_to_png(blank)

        marked = annotate(blank.getvalue(), [{"rect": (300, 200, 120, 36), "text": "Clicked “Pay invoice”"},
                                             {"rect": (300, 900, 120, 36), "text": "off the image"}])

        image = cairo.ImageSurface.create_from_png(io.BytesIO(marked))
        self.assertEqual((image.get_width(), image.get_height()), (800, 450))
        self.assertNotEqual(bytes(image.get_data()), bytes(surface.get_data()))  # something was drawn
        self.assertEqual(annotate(blank.getvalue(), [{"rect": (300, 900, 120, 36), "text": "x"}])[:8], b"\x89PNG\r\n\x1a\n")


if __name__ == "__main__":
    unittest.main()
