"""Filling words back into accessibility text, including when the app gives fewer words than placeholders."""

import unittest

from computer_use.placeholders import PLACEHOLDER as P, fill


class PlaceholdersTest(unittest.TestCase):
    def test_fills_in_order(self):
        self.assertEqual(fill(f"the father of {P}, see {P}.", ["computer science", "Turing machine"]),
                         "the father of computer science, see Turing machine.")

    def test_missing_words_leave_nothing_behind(self):
        # Slack: three placeholders, but one link came back as nothing and there's one fewer word than placeholders
        self.assertEqual(fill(f"{P} shipped {P} in {P}", ["Dan", ""]), "Dan shipped  in ")
        self.assertEqual(fill("no placeholders", []), "no placeholders")


if __name__ == "__main__":
    unittest.main()
