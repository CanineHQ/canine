"""Catching element paths that point at a different element than when they were found."""

import unittest

from computer_use import paths


class PathsTest(unittest.TestCase):
    def setUp(self):
        paths.forget()

    def test_a_path_still_showing_what_it_did_passes(self):
        paths.remember("4/3/0/1", "link", "Italy")
        paths.check("4/3/0/1", "link", "Italy")
        paths.check("9/9", "button", "Never handed out")  # nothing to compare with

    def test_a_path_that_now_shows_something_else_is_refused(self):
        paths.remember("4/3/0/1", "link", "Italy")  # the infobox's Italy, before the layout changed
        with self.assertRaisesRegex(LookupError, r"now points at link 'History', not the link 'Italy'"):
            paths.check("4/3/0/1", "link", "History")


if __name__ == "__main__":
    unittest.main()
