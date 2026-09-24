"""Pixels, input, windows, clipboard, shell and files. Input goes through xdotool; screenshots through mss."""

import asyncio
import base64
import io
import os
import subprocess

import mss
from PIL import Image

# Accept the key names agents commonly use (Cua/pynput style) and map them to X keysyms
KEY_ALIASES = {
    "enter": "Return", "return": "Return", "esc": "Escape", "escape": "Escape", "backspace": "BackSpace",
    "tab": "Tab", "space": "space", "delete": "Delete", "del": "Delete", "insert": "Insert",
    "home": "Home", "end": "End", "page_up": "Prior", "pageup": "Prior", "page_down": "Next", "pagedown": "Next",
    "up": "Up", "down": "Down", "left": "Left", "right": "Right",
    "ctrl": "ctrl", "control": "ctrl", "alt": "alt", "shift": "shift",
    "cmd": "super", "command": "super", "super": "super", "win": "super", "meta": "super",
    "caps_lock": "Caps_Lock", "print_screen": "Print", "menu": "Menu",
}
BUTTONS = {"left": "1", "middle": "2", "right": "3"}
MAX_OUTPUT = 100_000


def keysym(key: str) -> str:
    lower = key.lower()
    if lower in KEY_ALIASES:
        return KEY_ALIASES[lower]
    if len(lower) in (2, 3) and lower.startswith("f") and lower[1:].isdigit():
        return lower.upper()
    return key


def xdotool(*args: str) -> str:
    result = subprocess.run(["xdotool", *args], capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"xdotool {args[0]} failed")
    return result.stdout


# --- Screen -------------------------------------------------------------------------------------------------

def get_screen_size():
    width, height = xdotool("getdisplaygeometry").split()
    return {"size": {"width": int(width), "height": int(height)}}


def screenshot(format: str = "png", quality: int = 90):
    with mss.mss() as grabber:
        shot = grabber.grab(grabber.monitors[0])
    image = Image.frombytes("RGB", shot.size, shot.bgra, "raw", "BGRX")
    buffer = io.BytesIO()
    if format.lower() in ("jpg", "jpeg"):
        image.save(buffer, format="JPEG", quality=quality)
        format = "jpeg"
    else:
        image.save(buffer, format="PNG", optimize=False)
        format = "png"
    return {"image_data": base64.b64encode(buffer.getvalue()).decode(), "format": format,
            "width": image.width, "height": image.height}


def get_cursor_position():
    fields = dict(part.split(":") for part in xdotool("getmouselocation").split() if ":" in part)
    return {"position": {"x": int(fields["x"]), "y": int(fields["y"])}}


# --- Mouse --------------------------------------------------------------------------------------------------

def move_cursor(x: int, y: int):
    xdotool("mousemove", str(x), str(y))
    return {}


def _click(button: str, x=None, y=None, repeat: int = 1):
    if x is not None and y is not None:
        xdotool("mousemove", str(x), str(y))
    xdotool("click", "--repeat", str(repeat), BUTTONS[button])
    return {}


def left_click(x: int = None, y: int = None):
    return _click("left", x, y)


def right_click(x: int = None, y: int = None):
    return _click("right", x, y)


def middle_click(x: int = None, y: int = None):
    return _click("middle", x, y)


def double_click(x: int = None, y: int = None):
    return _click("left", x, y, repeat=2)


def mouse_down(x: int = None, y: int = None, button: str = "left"):
    if x is not None and y is not None:
        xdotool("mousemove", str(x), str(y))
    xdotool("mousedown", BUTTONS[button])
    return {}


def mouse_up(x: int = None, y: int = None, button: str = "left"):
    if x is not None and y is not None:
        xdotool("mousemove", str(x), str(y))
    xdotool("mouseup", BUTTONS[button])
    return {}


def drag(start_x: int, start_y: int, end_x: int, end_y: int, button: str = "left"):
    xdotool("mousemove", str(start_x), str(start_y))
    xdotool("mousedown", BUTTONS[button])
    xdotool("mousemove", "--sync", str(end_x), str(end_y))
    xdotool("mouseup", BUTTONS[button])
    return {}


def scroll(direction: str = "down", clicks: int = 3, x: int = None, y: int = None):
    if x is not None and y is not None:
        xdotool("mousemove", str(x), str(y))
    button = {"up": "4", "down": "5", "left": "6", "right": "7"}[direction]
    xdotool("click", "--repeat", str(clicks), button)
    return {}


def scroll_up(clicks: int = 3):
    return scroll("up", clicks)


def scroll_down(clicks: int = 3):
    return scroll("down", clicks)


# --- Keyboard -----------------------------------------------------------------------------------------------

def type_text(text: str):
    xdotool("type", "--delay", "8", "--", text)
    return {}


def press_key(key: str):
    xdotool("key", "--", keysym(key))
    return {}


def hotkey(keys: list):
    xdotool("key", "--", "+".join(keysym(k) for k in keys))
    return {}


# --- Windows (EWMH via wmctrl) --------------------------------------------------------------------------------

def list_windows():
    output = subprocess.run(["wmctrl", "-lGp"], capture_output=True, text=True, timeout=10).stdout
    active = xdotool("getactivewindow").strip() if output else ""
    windows = []
    for line in output.splitlines():
        parts = line.split(None, 8)
        if len(parts) < 8:
            continue
        window_id = int(parts[0], 16)
        windows.append({
            "id": window_id, "pid": int(parts[2]), "title": parts[8] if len(parts) > 8 else "",
            "position": {"x": int(parts[3]), "y": int(parts[4])},
            "size": {"width": int(parts[5]), "height": int(parts[6])},
            "active": active == str(window_id),
        })
    return {"windows": windows}


def activate_window(id: int):
    xdotool("windowactivate", "--sync", str(id))
    return {}


def close_window(id: int):
    subprocess.run(["wmctrl", "-ic", hex(id)], check=True, timeout=10)
    return {}


# --- Clipboard ----------------------------------------------------------------------------------------------

def get_clipboard():
    result = subprocess.run(["xclip", "-selection", "clipboard", "-o"], capture_output=True, text=True, timeout=10)
    return {"text": result.stdout}


def set_clipboard(text: str):
    subprocess.run(["xclip", "-selection", "clipboard"], input=text, text=True, check=True, timeout=10)
    return {}


# --- Shell and processes --------------------------------------------------------------------------------------

async def run_command(command: str, timeout: int = 120, cwd: str = None):
    # stdin must be closed, or anything the command backgrounds keeps our pipe open and we never return
    process = await asyncio.create_subprocess_shell(
        command, stdin=asyncio.subprocess.DEVNULL, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
        cwd=cwd or os.path.expanduser("~"), start_new_session=True,
    )
    try:
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout)
    except asyncio.TimeoutError:
        process.kill()
        return {"success": False, "error": f"Command timed out after {timeout}s"}
    return {"stdout": stdout.decode(errors="replace")[:MAX_OUTPUT], "stderr": stderr.decode(errors="replace")[:MAX_OUTPUT],
            "return_code": process.returncode}


def launch(app: str, args: list = None):
    process = subprocess.Popen([app, *(args or [])], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL, start_new_session=True)
    return {"pid": process.pid}


# --- Files ------------------------------------------------------------------------------------------------------

def _path(path: str) -> str:
    return os.path.expanduser(path)


def read_text(path: str, max_bytes: int = MAX_OUTPUT):
    with open(_path(path), encoding="utf-8", errors="replace") as file:
        return {"content": file.read(max_bytes)}


def write_text(path: str, content: str):
    with open(_path(path), "w", encoding="utf-8") as file:
        file.write(content)
    return {}


def list_dir(path: str = "~"):
    entries = []
    with os.scandir(_path(path)) as it:
        for entry in it:
            entries.append({"name": entry.name, "is_dir": entry.is_dir()})
    return {"entries": sorted(entries, key=lambda e: e["name"])}
