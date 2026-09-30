"""The key-name parsing, with a fake device in place of /dev/uinput (runs anywhere, no desktop needed)."""

import unittest
from unittest import mock

from computer_use import keyboard


class FakeDevice:
    def __init__(self):
        self.events = []

    def key(self, code, down):
        self.events.append((code, "down" if down else "up"))


class KeyboardTest(unittest.TestCase):
    def press(self, combo):
        fake = FakeDevice()
        with mock.patch.object(keyboard, "device", return_value=fake):
            keyboard.press(combo)
        return fake.events

    def test_combinations_press_modifiers_first_and_release_them_last(self):
        self.assertEqual(self.press("ctrl+a"), [(29, "down"), (30, "down"), (30, "up"), (29, "up")])
        self.assertEqual(self.press("cmd+2"), [(125, "down"), (3, "down"), (3, "up"), (125, "up")])

    def test_xdotool_names_and_shifted_characters(self):
        self.assertEqual(self.press("Return"), [(28, "down"), (28, "up")])
        self.assertEqual(self.press("Page_Down"), [(109, "down"), (109, "up")])
        self.assertEqual(self.press("A"), [(42, "down"), (30, "down"), (30, "up"), (42, "up")])
        self.assertEqual(self.press("?"), [(42, "down"), (53, "down"), (53, "up"), (42, "up")])
        self.assertEqual(self.press("super"), [(125, "down"), (125, "up")])

    def test_unknown_keys_are_rejected(self):
        with self.assertRaises(ValueError):
            self.press("ctrl+nope")


if __name__ == "__main__":
    unittest.main()
