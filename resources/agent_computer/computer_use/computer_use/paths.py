"""What each element path pointed to when it was handed out (by find or tree), to catch paths that have gone stale.

A path is child indexes from the desktop down, and a page's tree changes shape when its layout does: Wikipedia drops
its sidebar when its window narrows, and the same link moves from ".../3/3/4/3/0/1/4/1/0" to ".../3/2/3/3/0/1/4/1/0".
An agent that found a link before the change and pressed its path after pressed whatever was there now (a link in
the table of contents, which only scrolls the page) and was told it worked. `remember` notes what each path showed;
`check` refuses a path that now shows an element with another role or name.
"""

import threading
from collections import OrderedDict

LIMIT = 20_000  # paths remembered; the oldest are forgotten first
_seen = OrderedDict()
_lock = threading.Lock()


def remember(path, role, name):
    with _lock:
        _seen[path] = (role, name)
        _seen.move_to_end(path)
        while len(_seen) > LIMIT:
            _seen.popitem(last=False)


def check(path, role, name):
    """Raise LookupError if `path` was handed out for a different element than the one there now."""
    with _lock:
        was = _seen.get(path)
    if was and was != (role, name):
        raise LookupError(f"{path} now points at {_say(role, name)}, not the {_say(*was)} it was when found: the "
                          "window's layout changed. Look it up again with find.")


def forget():
    with _lock:
        _seen.clear()


def _say(role, name):
    return f"{role} {name!r}" if name else role
