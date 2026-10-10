"""Accessibility role names, as models write them and as the tree has them.

The Linux accessibility tree (AT-SPI) has its own role names ("tree item", "entry", "check box"), but models mostly
know the web's (ARIA: "treeitem", "textbox", "checkbox"). Asking for "treeitem" used to find nothing, and an agent
concluded Slack had no accessibility tree at all. So roles are compared loosely (case, spaces, underscores and
hyphens don't matter) and the common web names are translated.
"""

# Web (ARIA) role -> the tree's role, both already normalized
ALIASES = {
    "textbox": "entry", "searchbox": "entry", "input": "entry",
    "treeitem": "treeitem", "combobox": "combobox", "checkbox": "checkbox", "radio": "radiobutton",
    "menuitem": "menuitem", "menuitemcheckbox": "checkmenuitem", "menuitemradio": "radiomenuitem",
    "listitem": "listitem", "option": "listitem", "listbox": "list",
    "tab": "pagetab", "tablist": "pagetablist", "tabpanel": "panel",
    "img": "image", "row": "tablerow", "cell": "tablecell", "gridcell": "tablecell", "grid": "table",
    "columnheader": "tablecolumnheader", "rowheader": "tablerowheader",
    "dialog": "dialog", "alertdialog": "alert", "navigation": "landmark", "main": "landmark",
    "pushbutton": "button", "togglebutton": "togglebutton", "switch": "togglebutton",
}


def normalize(role):
    return "".join(c for c in str(role or "").lower() if c.isalnum())


def canonical(role):
    """The tree's role for a role name as given, normalized: "treeitem", "Tree Item" and "tree_item" are all the same."""
    key = normalize(role)
    return ALIASES.get(key, key)


def matches(wanted, actual):
    return canonical(wanted) == canonical(actual)
