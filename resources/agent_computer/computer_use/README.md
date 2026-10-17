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
- **AT-SPI** (`at-spi2-core`, PyGObject) for the accessibility tree
- **Chromium** (open-source builds; Google Chrome-branded ones refuse a debugging port on the normal profile) for
  `browse` and `open_url`
- Optionally **bigarrow** (`../bigarrow`, in the same venv) to mark on each browse step's screenshot what was clicked
  or typed into, and where (`marks.py`); without it, steps still say what they did, in words

## Install and run

```bash
python3 -m venv --system-site-packages ~/.local/share/canine/venv   # system-site-packages: the distro's PyGObject
~/.local/share/canine/venv/bin/pip install .
~/.local/share/canine/venv/bin/canine-computer-use setup             # as the desktop user; sudo for the root steps
```

`setup` gets the desktop ready and installs the server as a systemd user service that runs with the desktop session
(on `127.0.0.1:8000`; `--host`, `--port`). It's safe to run again, and only changes what isn't set up yet:

- **/dev/uinput** writable by your group (a virtual keyboard and mouse for clicks and key combinations): the `uinput`
  module, loaded at boot, and a udev rule
- **accessibility** on, so apps publish their UI: GTK's `toolkit-accessibility` setting, `QT_ACCESSIBILITY=1`, and
  Chromium's `--force-renderer-accessibility`
- **Chromium's DevTools port** (`--remote-debugging-port=9222`, in `~/.config/chromium-flags.conf`), which browse
  and `open_url` drive the browser through; restart Chromium after the first run
- the **service**, started right away when run inside the desktop session, otherwise at the next login

Every request needs the token `setup` creates (`COMPUTER_USE_TOKEN`'s, if set when it runs) in
`~/.config/canine-computer-use/token`, readable only by you:

```bash
curl -H "Authorization: Bearer $(cat ~/.config/canine-computer-use/token)" http://127.0.0.1:8000/status
```

Whoever has it can run commands as you. `--host 0.0.0.0 --open-firewall` exposes the server (and allows the port
through ufw) for when something outside the machine drives it, as Canine does through kubectl port-forward.

To run it by hand instead, start `canine-computer-use --port 8000` inside the desktop session (it needs
`WAYLAND_DISPLAY` and `HYPRLAND_INSTANCE_SIGNATURE`).

## Workspaces

The agent works on a workspace of its own so the person can keep using the desktop. Everything that opens a window
(browse jobs' pages, terminal windows, `open_app`, `open_url`) takes a `workspace`; without one, the server picks one
the person isn't looking at with nothing of theirs on it, and the reply says which it used. `GET /workspaces` lists
what's on each. Windows open there without switching the person's screen to them or taking focus, and keep from
taking it later; switch to that workspace to watch. Hyprland's rules can only place a window as it opens, and nothing
tells the agent's windows apart from the person's at that moment, so the server switches a placement rule on just
while its own window opens (`workspaces.py`). Clicks at coordinates, typing and key presses (`/computer-use`) still go
through the one shared mouse and keyboard, so those wait while the person is using the computer.

`POST /workspaces/clear` with a `workspace` closes everything on it and ends the terminal sessions opened for it;
Canine calls it on a run's workspace as the run starts and once it's over. Runs can work side by side, each on its
own workspace: the person keeps the one they're looking at.

## API

The reference, with every endpoint and an example request, is served at **`/docs`** (Swagger UI: Authorize with
the token to try requests from the page) and as OpenAPI at `/openapi.json`. Neither needs the token.

JSON in, JSON out. Prefer commands and window operations, then the accessibility tree, then keys; clicking at
coordinates is the last resort. Coordinates are screenshot pixels. Screenshots are scaled down to fit 1280x800 (a 1920x1080
monitor becomes 1280x720), because Anthropic's API shrinks bigger images before the model sees them, and clicks
would then land in the wrong place. `zoom` returns its region at the monitor's full resolution.

| Request | Body | Returns |
| --- | --- | --- |
| `GET /status` | | `{"ok": true, "screen": {"width", "height"}}` |
| `POST /computer-use` | an action, e.g. `{"action": "left_click", "coordinate": [640, 400]}` | the action's result (`screenshot` returns base64 PNG in `image`) |
| `POST /run` | `{"command": "uname -a", "timeout": 30}` | `exit_code`, `stdout`, `stderr` (stdin closed; killed after the timeout) |
| `POST /terminal/open` | `{"command": "claude", "cwd": "~/app", "show": true, "workspace": 5}` | a tmux session (and a window attached to it, and its workspace) |
| `POST /terminal/send` | `{"session": "term1", "text": "ls", "enter": true, "keys": ["C-c"]}` | types into the session, whatever has focus |
| `POST /terminal/read`, `/terminal/wait` | `{"session": "term1"}` / `{"session": "term1", "text": "$ "}` | the screen as text |
| `GET /terminal`, `POST /terminal/close` | | the sessions; end one |
| `GET /windows` | | the windows, with id, app, title, workspace and bounds |
| `GET /workspaces` | | each workspace's windows (the agent's marked), the one the person sees, and a `free` one |
| `POST /workspaces/clear` | `{"workspace": 5}` | closes every window on it; ends the terminal sessions opened for it |
| `POST /windows/open_app` | `{"command": "nautilus", "workspace": 3}` | the app's new window and its workspace (opened there, or on a free one, without switching to it) |
| `POST /windows/open_url` | `{"url": "https://example.com", "workspace": 3}` | the new browser window and its workspace |
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
