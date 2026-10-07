"""The human lock: activity pauses the agent for a while, take over holds it, hand back releases it."""

import unittest
from unittest import mock

from computer_use import human


class HumanTest(unittest.TestCase):
    def setUp(self):
        human.hand_back()

    def test_activity_pauses_screen_actions_until_idle(self):
        human.check()  # free
        human.activity()
        with self.assertRaises(human.HumanHasScreen):
            human.check()
        with mock.patch.object(human.time, "monotonic", return_value=human.time.monotonic() + human.IDLE_SECONDS + 1):
            human.check()  # idle long enough

    def test_take_over_holds_until_hand_back(self):
        human.take_over()
        with mock.patch.object(human.time, "monotonic", return_value=human.time.monotonic() + 3600):
            with self.assertRaises(human.HumanHasScreen):
                human.check()
        human.hand_back()
        human.check()

    def test_which_requests_need_the_screen(self):
        self.assertTrue(human.needs_screen("/computer-use", {"action": "left_click"}))
        self.assertFalse(human.needs_screen("/computer-use", {"action": "screenshot"}))
        self.assertTrue(human.needs_screen("/accessibility/press", {}))
        self.assertFalse(human.needs_screen("/accessibility/find", {}))
        self.assertFalse(human.needs_screen("/run", {}))
        self.assertTrue(human.needs_screen("/terminal/open", {}))
        self.assertFalse(human.needs_screen("/terminal/open", {"show": False}))
        self.assertFalse(human.needs_screen("/terminal/send", {}))


if __name__ == "__main__":
    unittest.main()
