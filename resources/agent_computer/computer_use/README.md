# canine-computer-use

An HTTP server that runs inside a Linux desktop and lets an AI agent see and drive it. It speaks
[Anthropic's computer-use tool](https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/computer-use-tool)
actions (screenshot, click, type, key, scroll...), and adds the accessibility tree, so an agent can find "the Save
button" by name and press it instead of guessing pixels.

Canine installs it on every agent computer (Omarchy: Arch Linux + Hyprland). It's written for Hyprland on Wayland,
with only the standard library plus PyGObject.

## What it needs on the desktop

- **Hyprland** (`hyprctl`) for the monitor, windows and cursor, and **grim** for screenshots
- **wtype** for typing text, and **tmux** for terminal sessions
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

JSON in, JSON out. Prefer commands and window operations, then the accessibility tree, then keys; clicking at
coordinates is the last resort. Coordinates are screenshot pixels. Screenshots are scaled down to fit 1280x800 (a 1920x1080
monitor becomes 1280x720), because Anthropic's API shrinks bigger images before the model sees them, and clicks
would then land in the wrong place. `zoom` returns its region at the monitor's full resolution.

| Request | Body | Returns |
| --- | --- | --- |
| `GET /status` | | `{"ok": true, "screen": {"width", "height"}}` |
| `POST /computer-use` | an action, e.g. `{"action": "left_click", "coordinate": [640, 400]}` | the action's result (`screenshot` returns base64 PNG in `image`) |
| `POST /run` | `{"command": "uname -a", "timeout": 30}` | `exit_code`, `stdout`, `stderr` (stdin closed; killed after the timeout) |
| `POST /terminal/open` | `{"command": "claude", "cwd": "~/app", "show": true}` | a tmux session (and a window attached to it) |
| `POST /terminal/send` | `{"session": "term1", "text": "ls", "enter": true, "keys": ["C-c"]}` | types into the session, whatever has focus |
| `POST /terminal/read`, `/terminal/wait` | `{"session": "term1"}` / `{"session": "term1", "text": "$ "}` | the screen as text |
| `GET /terminal`, `POST /terminal/close` | | the sessions; end one |
| `GET /windows` | | the windows, with id, app, title, workspace and bounds |
| `POST /windows/open_app` | `{"command": "nautilus", "workspace": 3}` | the app's new window |
| `POST /windows/open_url` | `{"url": "https://example.com"}` | the new browser window |
| `POST /windows/focus`, `/windows/close`, `/windows/maximize` | `{"id": "0x..."}` | (open_app and open_url also take `"maximize": true`) |
| `POST /windows/move_to_workspace` | `{"id": "0x...", "workspace": 4}` | |
| `POST /windows/switch_workspace` | `{"workspace": 3}` | |
| `POST /accessibility/tree` | `{"app": "chromium", "max_depth": 8}` | the visible UI as a tree |
| `POST /accessibility/find` | `{"role": "link", "name": "learn more"}` | matching elements, each with a `path` |
| `POST /accessibility/press` | `{"path": "4/0/2/7"}` or `{"role": "button", "name": "Send", "window_id": "0x..."}` | activates the element (`"click": true` clicks its middle instead) |
| `POST /accessibility/set_text` | `{"path": "4/0/2/9", "text": "hello"}` | replaces a text field's contents |
| `POST /accessibility/wait` | `{"role": "button", "name": "Compose", "window_id": "0x...", "timeout": 10}` | waits (up to 30 s) until it's on screen, or with `"gone": true` until it isn't |

Actions: `screenshot`, `zoom`, `left_click`, `right_click`, `middle_click`, `double_click`, `triple_click`,
`mouse_move`, `left_mouse_down`, `left_mouse_up`, `left_click_drag`, `cursor_position`, `scroll`, `key`, `type`,
`hold_key`, `wait`.

## Tests

```bash
python3 -m unittest discover tests
```
