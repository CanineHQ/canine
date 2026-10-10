"""Putting words back into accessibility text.

AT-SPI text holds a placeholder (U+FFFC) wherever a child element sits inside it, e.g. each link in a paragraph, and
the words are the child's own. accessibility.py looks up each child's words; this fills them in.
"""

PLACEHOLDER = "￼"


def fill(text, words):
    """Replace each placeholder with the next of `words`, in order. A placeholder with no word (the app didn't give
    one, or gave fewer than it has placeholders) just disappears."""
    words = iter(words)
    return "".join((next(words, None) or "") if char == PLACEHOLDER else char for char in text)
