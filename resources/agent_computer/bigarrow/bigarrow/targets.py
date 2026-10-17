"""What to point at, and which monitor it's on, in layout coordinates across all monitors: what Hyprland reports for
windows (`hyprctl clients`) and the cursor (`hyprctl cursorpos`), and what accessibility tools convert to.
"""

import json
import shutil
import subprocess
from dataclasses import dataclass

from .geometry import Rect


class TargetNotFound(LookupError):
    """Exit code 3: nothing matched, or it isn't on screen."""


@dataclass(frozen=True)
class Monitor:
    name: str
    bounds: Rect  # in layout coordinates
    workspaces: tuple = ()  # the workspaces it shows: its active one, and a special (scratchpad) one open over it


def _hyprctl(*args):
    if not shutil.which("hyprctl"):
        raise RuntimeError("hyprctl isn't installed: on other compositors, give --at or --rect with --screen")
    result = subprocess.run(["hyprctl", "-j", *args], capture_output=True, text=True, timeout=5)
    if result.returncode or not result.stdout.lstrip().startswith(("[", "{")):
        raise RuntimeError(f"hyprctl {' '.join(args)} failed: {(result.stdout + result.stderr).strip()[:200]}")
    return json.loads(result.stdout)


def monitors():
    found = []
    for m in _hyprctl("monitors"):
        width, height = m["width"] / m["scale"], m["height"] / m["scale"]
        if m.get("transform", 0) % 2:  # rotated a quarter turn
            width, height = height, width
        showing = (m.get("activeWorkspace") or {}, m.get("specialWorkspace") or {})
        found.append(Monitor(m["name"], Rect(m["x"], m["y"], width, height), tuple(w["id"] for w in showing if w.get("id"))))
    return found


def monitor_for(target, available):
    """The monitor showing the target's center (or the one nearest to it)."""
    cx, cy = target.center

    def distance(m):
        b = m.bounds
        return max(b.x - cx, 0, cx - b.x - b.width) + max(b.y - cy, 0, cy - b.y - b.height)

    return min(available, key=distance)


def parse_numbers(value, count, flag):
    try:
        numbers = [float(n) for n in value.split(",")]
    except ValueError:
        numbers = []
    if len(numbers) != count:
        raise ValueError(f"{flag} takes {count} numbers separated by commas, e.g. {','.join(['100'] * count)}")
    return numbers


def cursor():
    position = _hyprctl("cursorpos")
    return Rect(position["x"], position["y"])


def window(query, available):
    """The window whose class (or initial class) matches `query`, and title contains what follows a colon in it
    ("chromium:Inbox"), case-insensitively; the most recently focused if several do. It has to be on a workspace a
    monitor is showing."""
    wanted_class, _, wanted_title = query.partition(":")
    wanted_class, wanted_title = wanted_class.strip().lower(), wanted_title.strip().lower()
    matches = [
        c for c in _hyprctl("clients")
        if c.get("mapped", True) and not c.get("hidden")
        and (not wanted_class or wanted_class in (c.get("class") or "").lower()
             or wanted_class in (c.get("initialClass") or "").lower())
        and wanted_title in (c.get("title") or "").lower()
    ]
    if not matches:
        raise TargetNotFound(f"No window matches {query!r}: `hyprctl clients` lists them (class:title)")
    showing = {workspace for m in available for workspace in m.workspaces}
    visible = [c for c in matches if c["workspace"]["id"] in showing]
    special = {m.workspaces[-1] for m in available if len(m.workspaces) > 1}
    if special & {c["workspace"]["id"] for c in visible}:  # an open scratchpad covers the workspace under it
        visible = [c for c in visible if c["workspace"]["id"] in special]
    if not visible:
        workspaces = sorted({c["workspace"]["id"] for c in matches})
        raise TargetNotFound(f"{query!r} is on workspace {', '.join(map(str, workspaces))}, which no monitor is showing")
    best = min(visible, key=lambda c: c.get("focusHistoryID", 0))
    (x, y), (width, height) = best["at"], best["size"]
    return Rect(x, y, width, height), best
