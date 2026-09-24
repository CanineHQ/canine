// Prints one line per keyboard, mouse button or pointer motion event on the X display, for the takeover lock.
// Listens for XInput2 *raw* events on the root window: unlike regular button presses (which only one client may
// select, and the desktop already has), raw events can be watched by any number of clients.
// Built by provision.sh: gcc -O2 -o input-watch input_watch.c -lX11 -lXi
#include <stdio.h>
#include <sys/select.h>
#include <X11/Xlib.h>
#include <X11/extensions/XInput2.h>

int main(void) {
  Display *display = XOpenDisplay(NULL);
  if (!display) { fprintf(stderr, "input-watch: cannot open display\n"); return 1; }

  int opcode, event, error, major = 2, minor = 0;
  if (!XQueryExtension(display, "XInputExtension", &opcode, &event, &error) ||
      XIQueryVersion(display, &major, &minor) != Success) {
    fprintf(stderr, "input-watch: XInput 2 not available\n");
    return 1;
  }

  unsigned char bits[XIMaskLen(XI_LASTEVENT)] = {0};
  XIEventMask mask = { XIAllMasterDevices, sizeof(bits), bits };
  XISetMask(bits, XI_RawKeyPress);
  XISetMask(bits, XI_RawButtonPress);
  XISetMask(bits, XI_RawMotion);
  XISelectEvents(display, DefaultRootWindow(display), &mask, 1);
  XSync(display, False);
  setvbuf(stdout, NULL, _IOLBF, 0);

  // Pointer moves injected through XTest (how Selkies delivers the person's mouse) don't raise raw motion events on
  // Xvfb, so also poll the pointer position a few times a second
  Window root = DefaultRootWindow(display), root_return, child;
  int last_x = -1, last_y = -1, x, y, win_x, win_y;
  unsigned int buttons;
  int fd = ConnectionNumber(display);

  for (;;) {
    while (XPending(display)) {
      XEvent xevent;
      XNextEvent(display, &xevent);
      XGenericEventCookie *cookie = &xevent.xcookie;
      if (cookie->type == GenericEvent && cookie->extension == opcode && XGetEventData(display, cookie)) {
        puts(cookie->evtype == XI_RawMotion ? "motion" : cookie->evtype == XI_RawKeyPress ? "key" : "button");
        XFreeEventData(display, cookie);
      }
    }

    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(fd, &fds);
    struct timeval timeout = { 0, 200000 };
    if (select(fd + 1, &fds, NULL, NULL, &timeout) == 0 &&
        XQueryPointer(display, root, &root_return, &child, &x, &y, &win_x, &win_y, &buttons)) {
      if (last_x >= 0 && (x != last_x || y != last_y)) puts("motion");
      last_x = x;
      last_y = y;
    }
  }
}
