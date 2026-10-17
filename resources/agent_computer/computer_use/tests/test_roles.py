"""Role names are matched loosely, and the web's names map to the tree's."""

import unittest

from computer_use import roles


class RolesTest(unittest.TestCase):
    def test_spelling_and_web_names(self):
        for wanted, actual in [("treeitem", "tree item"), ("Tree_Item", "tree item"), ("textbox", "entry"), ("searchbox", "entry"),
                               ("checkbox", "check box"), ("menuitem", "menu item"), ("tab", "page tab"), ("img", "image"),
                               ("button", "push button"), ("button", "button"), ("link", "link")]:
            self.assertTrue(roles.matches(wanted, actual), f"{wanted} should match {actual}")

    def test_different_roles_stay_different(self):
        self.assertFalse(roles.matches("button", "link"))
        self.assertFalse(roles.matches("treeitem", "tree"))


if __name__ == "__main__":
    unittest.main()
