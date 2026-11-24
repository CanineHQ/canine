import asyncio
import base64
import struct
import unittest
from types import SimpleNamespace

from computer_use import marks


def node(index, tag="button", x=100, y=50, width=80, height=20, name="", attributes=None):
    return SimpleNamespace(backend_node_id=index, target_id="t", tag_name=tag, attributes=attributes or {},
                           ax_node=SimpleNamespace(name=name) if name else None,
                           absolute_position=SimpleNamespace(x=x, y=y, width=width, height=height),
                           get_all_children_text=lambda max_depth=-1: "")


def png(width, height):
    return base64.b64encode(b"\x89PNG\r\n\x1a\n" + b"\0\0\0\rIHDR" + struct.pack(">II", width, height) + b"\0" * 8).decode()


def action(**params):
    return SimpleNamespace(model_dump=lambda exclude_none=True: params)


class MarksTest(unittest.TestCase):
    def test_plan_says_what_each_action_did_and_where_on_the_screenshot(self):
        selector_map = {
            5: node(5, name="Pay invoice"),
            6: node(6, tag="input", y=900, name="Amount"),  # below the fold
            7: node(7, tag="input", name="Password", attributes={"type": "password"}),
        }
        # a 1.25 device pixel ratio: a 1000-wide viewport captured 1250 wide
        state = SimpleNamespace(screenshot=png(1250, 750), dom_state=SimpleNamespace(selector_map=selector_map),
                                page_info=SimpleNamespace(viewport_width=1000))
        output = SimpleNamespace(action=[action(click={"index": 5}), action(input={"index": 6, "text": "1240.00"}),
                                         action(input={"index": 7, "text": "hunter2"}),
                                         action(navigate={"url": "https://example.com"}),
                                         action(click={"coordinate_x": 700, "coordinate_y": 425})])  # at a point on the model's 1400x850 image

        planned = marks.plan(state, output)

        self.assertEqual([p["did"] for p in planned], ["Clicked “Pay invoice”", "Typed “1240.00” into “Amount”",
                                                       "Typed a password into “Password”", "Opened https://example.com",
                                                       "Clicked at (700, 425)"])
        self.assertEqual(planned[0]["rect"], [125, 62, 100, 25])
        self.assertIsNone(planned[1]["rect"])  # off the screenshot: marked after the step instead
        self.assertIsNone(planned[3]["rect"])
        self.assertEqual(planned[4]["rect"], [613, 363, 24, 24])  # the middle of the 1250x750 screenshot

    def test_after_the_step_marks_only_elements_that_held_still_for_the_screenshot(self):
        steady, moving = node(5, x=100, y=50), node(6, x=100, y=200)
        positions = {5: [steady.absolute_position] * 2,
                     6: [moving.absolute_position, SimpleNamespace(x=100, y=260, width=80, height=20)]}  # the page shifted

        class Browser:
            async def take_screenshot(self):
                return base64.b64decode(png(1000, 800))

            async def get_or_create_cdp_session(self, target_id, focus=False):
                return None

            async def get_element_coordinates(self, backend_node_id, session):
                return positions[backend_node_id].pop(0)

        missing = [{"did": "Clicked “A”", "action": "click", "node": steady, "ratio": 1.0, "rect": None},
                   {"did": "Clicked “B”", "action": "click", "node": moving, "ratio": 1.0, "rect": None}]
        _, shown = asyncio.run(marks.after(Browser(), missing))
        self.assertEqual(shown, [{"did": "Clicked “A”", "rect": [100, 50, 80, 20]}])


    def test_a_click_is_marked_where_browser_use_clicked_when_that_wasnt_on_the_element_planned(self):
        planned = [{"did": "Clicked “Heading”", "action": "click", "rect": [200, 50, 30, 30], "ratio": 1.25},
                   {"did": "Clicked “Approve”", "action": "click", "rect": [100, 100, 80, 20], "ratio": 1.25}]
        results = [SimpleNamespace(metadata={"click_x": 640, "click_y": 690}),  # Submit review, elsewhere
                   SimpleNamespace(metadata={"click_x": 110, "click_y": 90})]   # on the element (110 * 1.25 = 137.5)

        marks.check_clicks(planned, results)

        self.assertEqual(planned[0], {"did": "Clicked here", "action": "click", "rect": [788, 850, 24, 24], "ratio": 1.25})
        self.assertEqual(planned[1]["did"], "Clicked “Approve”")


if __name__ == "__main__":
    unittest.main()
