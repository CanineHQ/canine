"""The keyboard.

- Key presses and combinations ("Return", "ctrl+a", "super+2") go through the virtual device (uinput.py) as real
  US-keyboard key codes, so Hyprland's shortcuts and apps see exactly what a physical keyboard would send.
- Typing text uses the same key codes for every character a US keyboard has, and pastes the rest (é, ✓, 日本) through
  the clipboard, putting back what was on it. (Typing through wtype isn't reliable in Chromium: wtype makes up its own
  key map, and Chromium reads some of its key codes as the physical keys they collide with, so a "-" that landed on
  Backspace's code deleted the character before it.)

Key names follow the Anthropic computer-use tool, which uses xdotool's names ("Return", "Page_Down", "ctrl+s").
"""

import re
import subprocess
import time

from . import desktop
from .uinput import device

MODIFIER_CODES = {"shift": 42, "ctrl": 29, "alt": 56, "super": 125}
MODIFIER_NAMES = {
    "ctrl": "ctrl", "control": "ctrl",
    "shift": "shift",
    "alt": "alt", "option": "alt",
    "super": "super", "cmd": "super", "meta": "super", "win": "super",
}

# Linux key codes for a US keyboard (linux/input-event-codes.h)
KEYS = {
    **{c: code for c, code in zip("1234567890", range(2, 12))},
    **{c: code for c, code in zip("qwertyuiop", range(16, 26))},
    **{c: code for c, code in zip("asdfghjkl", range(30, 39))},
    **{c: code for c, code in zip("zxcvbnm", range(44, 51))},
    "-": 12, "=": 13, "[": 26, "]": 27, ";": 39, "'": 40, "`": 41, "\\": 43, ",": 51, ".": 52, "/": 53,
    "escape": 1, "backspace": 14, "tab": 15, "return": 28, "space": 57, "capslock": 58,
    **{f"f{n}": code for n, code in zip(range(1, 11), range(59, 69))}, "f11": 87, "f12": 88,
    "print": 99, "home": 102, "up": 103, "prior": 104, "left": 105, "right": 106, "end": 107, "down": 108,
    "next": 109, "insert": 110, "delete": 111, "menu": 127,
}
ALIASES = {
    "enter": "return", "esc": "escape", "del": "delete", "pageup": "prior", "page_up": "prior",
    "pagedown": "next", "page_down": "next", "minus": "-", "equal": "=", "comma": ",", "period": ".",
    "slash": "/", "backslash": "\\", "semicolon": ";", "apostrophe": "'", "grave": "`",
    "bracketleft": "[", "bracketright": "]",
}
# Characters typed with Shift on a US keyboard, and the key they're on
SHIFTED = dict(zip('!@#$%^&*()_+{}:"~|<>?', "1234567890-=[];'`\\,./"))


def press(combo):
    """Press a key or combination, e.g. "Return", "ctrl+a", "super+2", "shift+Tab"."""
    parts = [part.strip() for part in combo.split("+") if part.strip()]
    if combo.strip() == "+":
        parts = ["+"]
    modifiers = [MODIFIER_NAMES[p.lower()] for p in parts[:-1]]
    name = parts[-1]

    if name.lower() in MODIFIER_NAMES:  # a lone modifier, e.g. "super"
        return _tap([*modifiers, MODIFIER_NAMES[name.lower()]], None)
    code, shifted = _key_code(name)
    if code is None:
        raise ValueError(f"Unknown key {name!r}")
    _tap(modifiers + (["shift"] if shifted and "shift" not in modifiers else []), code)


def type_text(text):
    """Type text. Newlines and tabs are pressed as the Return and Tab keys."""
    for chunk in re.split(r"(\n|\t)", text):
        if chunk == "\n":
            press("Return")
        elif chunk == "\t":
            press("Tab")
        elif chunk:
            _type_chunk(chunk)


def _type_chunk(text):
    """Characters on a US keyboard as key presses; runs of anything else through wtype."""
    for keyboard_run, run in _runs(text):
        if keyboard_run:
            for char in run:
                code, shifted = _char_code(char)
                _tap(["shift"] if shifted else [], code)
        else:
            _paste(run)


TERMINALS = {"foot", "Alacritty", "kitty", "com.mitchellh.ghostty", "org.wezfurlong.wezterm"}  # paste with ctrl+shift+v


def _paste(text):
    """Paste text through the clipboard, then put back what was on it (if it was text)."""
    saved = subprocess.run(["wl-paste", "--no-newline"], capture_output=True, timeout=5)
    subprocess.run(["wl-copy"], input=text.encode(), check=True, timeout=5)
    app = desktop.hyprctl_json("activewindow").get("class", "")
    press("ctrl+shift+v" if app in TERMINALS else "ctrl+v")
    time.sleep(0.2)  # let the app read the clipboard before it changes back
    if saved.returncode == 0:
        subprocess.run(["wl-copy"], input=saved.stdout, timeout=5)
    else:
        subprocess.run(["wl-copy", "--clear"], timeout=5)


def _runs(text):
    """Split text into (on_us_keyboard, run) pieces."""
    runs = []
    for char in text:
        on_keyboard = _char_code(char)[0] is not None
        if runs and runs[-1][0] == on_keyboard:
            runs[-1][1] += char
        else:
            runs.append([on_keyboard, char])
    return [(on_keyboard, run) for on_keyboard, run in runs]


def _char_code(char):
    return (KEYS["space"], False) if char == " " else _key_code(char)


def hold(combo, seconds):
    """Hold a key (or combination) down for a while, e.g. to trigger key repeat."""
    parts = [part.strip() for part in combo.split("+")]
    modifiers = [MODIFIER_NAMES[p.lower()] for p in parts[:-1]]
    code, shifted = _key_code(parts[-1])
    codes = [MODIFIER_CODES[m] for m in modifiers + (["shift"] if shifted else [])] + [code]
    for c in codes:
        device().key(c, down=True)
    time.sleep(seconds)
    for c in reversed(codes):
        device().key(c, down=False)


def pause(seconds):
    time.sleep(seconds)


def _key_code(name):
    """(key code, needs Shift) for a key name or character."""
    if len(name) == 1:
        if name in SHIFTED:
            return KEYS[SHIFTED[name]], True
        if name.isupper():
            return KEYS.get(name.lower()), True
    key = ALIASES.get(name.lower(), name.lower())
    return KEYS.get(key), False


def _tap(modifiers, code):
    """Press modifiers, tap the key, release in reverse order."""
    modifier_codes = [MODIFIER_CODES[m] for m in modifiers]
    for c in modifier_codes:
        device().key(c, down=True)
    if code is not None:
        device().key(code, down=True)
        device().key(code, down=False)
    for c in reversed(modifier_codes):
        device().key(c, down=False)
