"""A virtual keyboard and mouse, created with the kernel's uinput interface.

The desktop treats it like any other plugged-in device, so its key presses reach Hyprland's shortcuts exactly like a
real keyboard's (by physical key code), and its clicks go wherever the cursor is.

/dev/uinput is opened as the desktop user; omarchy-setup.sh gives the wheel group access to it.
"""

import fcntl
import os
import struct
import time

# Linux input event types and codes (linux/input-event-codes.h)
EV_SYN, EV_KEY, EV_REL = 0x00, 0x01, 0x02
SYN_REPORT = 0
REL_X, REL_Y, REL_HWHEEL, REL_WHEEL = 0x00, 0x01, 0x06, 0x08
BUTTONS = {"left": 0x110, "right": 0x111, "middle": 0x112}

# uinput ioctls (linux/uinput.h)
UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_RELBIT = 0x40045564, 0x40045565, 0x40045566
UI_DEV_SETUP, UI_DEV_CREATE = 0x405C5503, 0x5501

KEY_CODES = range(1, 256)  # every ordinary keyboard key


class VirtualDevice:
    def __init__(self, name="canine-computer-use"):
        self.fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
        fcntl.ioctl(self.fd, UI_SET_EVBIT, EV_KEY)
        fcntl.ioctl(self.fd, UI_SET_EVBIT, EV_REL)
        for code in [*KEY_CODES, *BUTTONS.values()]:
            fcntl.ioctl(self.fd, UI_SET_KEYBIT, code)
        for code in (REL_X, REL_Y, REL_WHEEL, REL_HWHEEL):
            fcntl.ioctl(self.fd, UI_SET_RELBIT, code)
        # struct uinput_setup: input_id (bustype, vendor, product, version), name[80], ff_effects_max
        fcntl.ioctl(self.fd, UI_DEV_SETUP, struct.pack("HHHH80sI", 0x06, 0x1234, 0x5678, 1, name.encode(), 0))
        fcntl.ioctl(self.fd, UI_DEV_CREATE)
        time.sleep(0.5)  # let the compositor pick up the new device

    def emit(self, event_type, code, value):
        # struct input_event: timeval (seconds, microseconds), type, code, value
        os.write(self.fd, struct.pack("llHHi", 0, 0, event_type, code, value))

    def sync(self):
        self.emit(EV_SYN, SYN_REPORT, 0)

    def key(self, code, down):
        self.emit(EV_KEY, code, 1 if down else 0)
        self.sync()


_device = None


def device():
    """The one virtual device, created on first use."""
    global _device
    if _device is None:
        _device = VirtualDevice()
    return _device
