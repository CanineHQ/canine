# canine-computer-use

An HTTP server that runs inside a Linux desktop and lets an AI agent see and drive it. It speaks
[Anthropic's computer-use tool](https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/computer-use-tool)
actions (screenshot, click, type, key, scroll...), and adds the accessibility tree, so an agent can find "the Save
button" by name and press it instead of guessing pixels.

Canine installs it on every agent computer (Omarchy: Arch Linux + Hyprland). It's written for Hyprland on Wayland,
with only the standard library plus PyGObject.

## What it needs on the desktop

- **Hyprland** (`hyprctl`) for the monitor, windows and cursor, and **grim** for screenshots
- **wtype** for typing text
- **/dev/uinput** writable by the user (a virtual keyboard and mouse for clicks and key combinations): load the
  `uinput` module and add a udev rule such as
  `KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", GROUP="wheel", MODE="0660"`
- **AT-SPI** (`at-spi2-core`, PyGObject) with accessibility turned on:
  `gsettings set org.gnome.desktop.interface toolkit-accessibility true`, `QT_ACCESSIBILITY=1`, and
  `--force-renderer-accessibility` for Chromium

## Install and run

```bash
python3 -m venv --system-site-packages ~/.local/share/canine/venv   # system-site-packages: the distro's PyGObject
~/.local/share/canine/venv/bin/pip install .
~/.local/share/canine/venv/bin/canine-computer-use --port 8000
```

Run it inside the desktop session (it needs `WAYLAND_DISPLAY` and `HYPRLAND_INSTANCE_SIGNATURE`), e.g. as a systemd
user service that's part of `graphical-session.target`. It has no authentication: keep the port private.

## API

JSON in, JSON out. Coordinates are screenshot pixels. Screenshots are scaled down to fit 1280x800 (a 1920x1080
monitor becomes 1280x720), because Anthropic's API shrinks bigger images before the model sees them, and clicks
would then land in the wrong place. `zoom` returns its region at the monitor's full resolution.

| Request | Body | Returns |
| --- | --- | --- |
| `GET /status` | | `{"ok": true, "screen": {"width", "height"}}` |
| `POST /computer-use` | an action, e.g. `{"action": "left_click", "coordinate": [640, 400]}` | the action's result (`screenshot` returns base64 PNG in `image`) |
| `GET /windows` | | the windows, with app, title, workspace and bounds |
| `POST /accessibility/tree` | `{"app": "chromium", "max_depth": 8}` | the visible UI as a tree |
| `POST /accessibility/find` | `{"role": "link", "name": "learn more"}` | matching elements, each with a `path` |
| `POST /accessibility/press` | `{"path": "4/0/2/7"}` | activates the element |
| `POST /accessibility/set_text` | `{"path": "4/0/2/9", "text": "hello"}` | replaces a text field's contents |

Actions: `screenshot`, `zoom`, `left_click`, `right_click`, `middle_click`, `double_click`, `triple_click`,
`mouse_move`, `left_mouse_down`, `left_mouse_up`, `left_click_drag`, `cursor_position`, `scroll`, `key`, `type`,
`hold_key`, `wait`.

## Tests

```bash
python3 -m unittest discover tests
```
