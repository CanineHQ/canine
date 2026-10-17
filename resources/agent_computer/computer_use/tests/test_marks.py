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
                                         action(navigate={"url": "https://example.com"})])

        planned = marks.plan(state, output)

        self.assertEqual([p["did"] for p in planned], ["Clicked “Pay invoice”", "Typed “1240.00” into “Amount”",
                                                       "Typed a password into “Password”", "Opened https://example.com"])
        self.assertEqual(planned[0]["rect"], [125, 62, 100, 25])
        self.assertIsNone(planned[1]["rect"])  # off the screenshot: marked after the step instead
        self.assertIsNone(planned[3]["rect"])


if __name__ == "__main__":
    unittest.main()
