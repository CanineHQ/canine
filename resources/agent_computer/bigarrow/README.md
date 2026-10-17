# bigarrow-wayland

Lets an AI agent draw a big arrow, a ring or a box, with a sign, on a Wayland screen: to show the person where to
click, what to read, or which window it means. Clicks go through it, keyboard focus stays where it is, and it removes
itself.

```bash
bigarrow point --window "chromium:Sign in" --text "Your turn: sign in here, then tell me"
bigarrow start --rect 700,400,120,40 --style ring --color green --text "Click Allow" && bigarrow stop --all
```

A Wayland take on Franz Enzenhofer's [big-arrow-on-the-screen](https://github.com/franzenzenhofer/big-arrow-on-the-screen)
for macOS (MIT), with the same idea and command line: an agent that needs the person to do something points at it
instead of describing it in a terminal they aren't looking at. It never clicks, types or captures anything itself.

## How it works

The arrow is a transparent surface covering one monitor on the compositor's **overlay layer** (wlr-layer-shell,
through gtk4-layer-shell), so it's above every window and panel. It asks for no keyboard focus, and its input region
is only the sign: clicks anywhere else reach the windows underneath, and a click on the sign ends the arrow.

Targets are in **layout coordinates**, the ones Hyprland reports for windows (`hyprctl clients`) and the cursor
(`hyprctl cursorpos`), across all monitors; the arrow is drawn on the monitor showing the target.

## Needs

- A compositor with wlr-layer-shell (Hyprland, Sway, river, niri, KDE...). `--window` and `--mouse` use `hyprctl`,
  so they're Hyprland only; `--at` and `--rect` work anywhere.
- GTK 4, **gtk4-layer-shell**, PyGObject and pycairo (Arch: `gtk4 gtk4-layer-shell python-gobject python-cairo`)

```bash
python3 -m venv --system-site-packages ~/.local/share/bigarrow/venv   # system-site-packages: the distro's PyGObject
~/.local/share/bigarrow/venv/bin/pip install .
```

Run it inside the desktop session (it needs `WAYLAND_DISPLAY`, and `HYPRLAND_INSTANCE_SIGNATURE` for hyprctl).

## Commands

| Command | |
| --- | --- |
| `bigarrow point TARGET [looks]` | shows the arrow, and returns once it's gone (after 8 s by default) |
| `bigarrow start TARGET [looks]` | returns once it's showing, and prints its id (gone after 300 s by default) |
| `bigarrow stop ID...` / `stop --all` | ends arrows |
| `bigarrow list` | the arrows showing |

**Target** (one of): `--at X,Y`, `--rect X,Y,W,H`, `--window CLASS[:TITLE]` (class and title matched
case-insensitively, the most recently focused if several match; it has to be on a workspace that's showing), `--mouse`.

**Looks**: `--text` (wraps when long), `--color red|orange|yellow|green|teal|blue|purple|pink|black|white|#RRGGBB`,
`--from auto|top|bottom|left|right|top-left|top-right|bottom-left|bottom-right` (auto: where the sign fits without
covering the target), `--style arrow|ring|box`, `--size S|M|L`, `--scale 0.8` (bigger or smaller than the size,
everything together; a machine's default in `$BIGARROW_SCALE`), `--shape bend|straight`.

**Ending**: every arrow ends by itself: after `--duration` seconds (`0`: never), when the process in `--owner PID`
(or `$BIGARROW_OWNER_PID`) exits, or with `stop`; or at once, on a click on its sign.

**Output**: `--json` says what happened (and where it drew, in `plan`); `--dry-run` works out where it would go
without drawing; `--png PATH` draws into a PNG instead, over `--backdrop SCREENSHOT` if given (`grim` takes one),
with `--screen W,H` where there's no Hyprland to ask.

Exit codes: 0 done, 2 bad input, 3 target not found (or not on screen), 4 can't draw (no Wayland session, no
layer-shell).

## Marking up screenshots

The same drawing works on an image, with no display: a box round each thing, an arrow, and a sign. Canine's browse
jobs use it to show, on each step's screenshot, what was clicked or typed into ("Clicked “Pay invoice”"), so a person
reading a run back can see where.

```python
from bigarrow.annotate import annotate
marked_png = annotate(png_bytes, [{"rect": (812, 404, 120, 36), "text": "Clicked “Pay invoice”"}])
```

`rect` is in the image's pixels; sizes scale with the image's width.

## Tests

```bash
python -m unittest discover tests   # the geometry anywhere; drawing into PNGs where PyGObject and pycairo are
```
