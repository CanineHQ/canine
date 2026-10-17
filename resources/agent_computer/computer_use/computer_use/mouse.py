"""The mouse: Hyprland moves the cursor, and the virtual device (uinput.py) clicks and scrolls.

Hyprland can put the cursor anywhere (`hl.dsp.cursor.move`) but has no way to click, so clicks and scrolling come
from the virtual device, like a real mouse's. Modifier keys held during a click ("shift + click") are pressed on the
same device, so they arrive together.
"""

import time
from contextlib import contextmanager

from . import desktop, keyboard
from .uinput import BUTTONS, EV_REL, REL_HWHEEL, REL_WHEEL, REL_X, device


def move_to(x, y):
    """Put the cursor on pixel (x, y)."""
    layout_x, layout_y = desktop.to_layout(x, y)
    desktop.hyprctl("dispatch", f"hl.dsp.cursor.move({{ x = {round(layout_x)}, y = {round(layout_y)} }})")
    # A zero-distance nudge makes the app under the cursor notice it arrived (hover state, drag targets)
    device().emit(EV_REL, REL_X, 0)
    device().sync()


def position():
    x, y = (float(part) for part in desktop.hyprctl("cursorpos").split(","))
    return desktop.to_pixels(x, y)


def press(button="left"):
    device().key(BUTTONS[button], down=True)


def release(button="left"):
    device().key(BUTTONS[button], down=False)


def click(button="left", count=1, modifiers=()):
    with holding(modifiers):
        for _ in range(count):
            press(button)
            release(button)
            time.sleep(0.05)


def scroll(direction, amount=3, modifiers=()):
    axis = REL_WHEEL if direction in ("up", "down") else REL_HWHEEL
    step = 1 if direction in ("up", "right") else -1
    with holding(modifiers):
        for _ in range(amount):
            device().emit(EV_REL, axis, step)
            device().sync()
            time.sleep(0.02)


def drag(start, end, steps=20):
    move_to(*start)
    press()
    for i in range(1, steps + 1):
        move_to(start[0] + (end[0] - start[0]) * i / steps, start[1] + (end[1] - start[1]) * i / steps)
        time.sleep(0.01)
    release()


@contextmanager
def holding(modifiers):
    """Hold modifier keys ("shift", "ctrl", "alt", "super") down for the duration of a `with` block."""
    codes = [keyboard.MODIFIER_CODES[m] for m in modifiers]
    for code in codes:
        device().key(code, down=True)
    try:
        yield
    finally:
        for code in reversed(codes):
            device().key(code, down=False)
