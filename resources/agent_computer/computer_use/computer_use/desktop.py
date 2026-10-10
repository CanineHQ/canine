"""The desktop as Hyprland sees it: the monitor, the windows on it, and screenshots.

Two coordinate systems meet here:

- Screenshot pixels: what an agent sees and clicks on. Screenshots are scaled down to fit MAX_SCREENSHOT, so a
  1920x1080 monitor is a 1280x720 screenshot, and every coordinate in this package's API is in those pixels.
- Layout coordinates: what Hyprland uses for the cursor and windows. At a monitor scale of 1.25, a 1920x1080 monitor
  is 1536x864 layout units.

`to_layout` and `to_pixels` convert at the edges.
"""

import json
import subprocess
import time
from collections import namedtuple

# Anthropic's API shrinks larger images before the model sees them (to about 1.15 megapixels, 1568px on the long
# edge), and then the model's clicks would land in the wrong place. So the server scales screenshots itself, to the
# size Anthropic recommends for computer use, and scales coordinates to match.
MAX_SCREENSHOT = (1280, 800)

# The monitor as agents see it: its position in the layout, the screenshot's size, screenshot pixels per layout unit
# (`scale`), and the monitor's own pixels per layout unit (`device_scale`, Hyprland's monitor scale)
Screen = namedtuple("Screen", ["x", "y", "width", "height", "scale", "device_scale"])


def hyprctl(*args):
    return subprocess.run(["hyprctl", *args], capture_output=True, text=True, check=True).stdout


def hyprctl_json(*args):
    return json.loads(hyprctl("-j", *args))


_screen = (0, None)  # (when it was read, Screen): an accessibility tree converts thousands of positions


def screen():
    """The (only) monitor, re-read from Hyprland at most once a second."""
    global _screen
    if time.monotonic() - _screen[0] > 1:
        m = hyprctl_json("monitors")[0]
        fit = min(MAX_SCREENSHOT[0] / m["width"], MAX_SCREENSHOT[1] / m["height"], 1)
        _screen = (time.monotonic(), Screen(m["x"], m["y"], round(m["width"] * fit), round(m["height"] * fit), m["scale"] * fit, m["scale"]))
    return _screen[1]


def to_layout(x, y):
    s = screen()
    return s.x + x / s.scale, s.y + y / s.scale


def to_pixels(x, y):
    s = screen()
    return round((x - s.x) * s.scale), round((y - s.y) * s.scale)


def screen_size():
    s = screen()
    return {"width": s.width, "height": s.height}


def screenshot(region=None):
    """PNG bytes of the whole screen, scaled to screenshot pixels. Or, for zooming in, of `region` ([left, top, right,
    bottom] in screenshot pixels) at the monitor's full resolution."""
    if region is None:
        # grim rounds the image size down, so nudge the scale up: 864 x 0.83333 is 719.99..., and should be 720
        scale = screen().scale + 1e-6
        return subprocess.run(["grim", "-s", str(scale), "-"], capture_output=True, check=True).stdout
    left, top = to_layout(region[0], region[1])
    right, bottom = to_layout(region[2], region[3])
    geometry = f"{round(left)},{round(top)} {round(right - left)}x{round(bottom - top)}"
    return subprocess.run(["grim", "-g", geometry, "-"], capture_output=True, check=True).stdout


def windows():
    """Every window, with its bounds in screenshot pixels."""
    focused = hyprctl_json("activewindow").get("address")
    result = []
    for client in hyprctl_json("clients"):
        left, top = to_pixels(*client["at"])
        right, bottom = to_pixels(client["at"][0] + client["size"][0], client["at"][1] + client["size"][1])
        result.append({
            "id": client["address"],
            "title": client["title"],
            "app": client["class"],
            "pid": client["pid"],
            "workspace": client["workspace"]["id"],
            "focused": client["address"] == focused,
            "maximized": client.get("fullscreen", 0) > 0,
            "bounds": {"x": left, "y": top, "width": right - left, "height": bottom - top},
        })
    return result


def window_origin(pid, title=None):
    """The layout position of a process's window, preferring the one with this title if it has several."""
    candidates = [c for c in hyprctl_json("clients") if c["pid"] == pid]
    matching = [c for c in candidates if title and c["title"] == title]
    window = (matching or candidates or [None])[0]
    return tuple(window["at"]) if window else None
