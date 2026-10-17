"""`canine-computer-use setup`: gets a Hyprland desktop ready for the server, then installs it as a service.

Run it once as the desktop user, from the venv the package is installed in. Safe to run again: it only changes what
isn't set up yet, so a second run needs no sudo. Steps that need root (the virtual input device, the firewall) go
through sudo, which asks for a password if it has to.

  - /dev/uinput writable by the user: the server clicks and presses keys through a virtual keyboard and mouse
  - accessibility turned on for GTK, Qt and Chromium, so apps publish the tree /accessibility/* reads
  - Chromium's DevTools port (127.0.0.1:9222), which browse and open_url drive the browser through. Open-source
    Chromium (Arch's) allows it on the normal profile; Google Chrome-branded builds refuse it there.
  - the server's token (auth.py): COMPUTER_USE_TOKEN's if set, else a random one if there's none yet
  - a systemd user service running the server with the desktop session

Changes to Chromium's flags take effect once Chromium restarts, and QT_ACCESSIBILITY in Qt apps started after the
next login.
"""

import argparse
import grp
import os
import shutil
import subprocess
import sys
from pathlib import Path

from . import auth
from .cdp import CDP_URL

SERVICE = "canine-computer-use"
CDP_PORT = CDP_URL.rsplit(":", 1)[1]
CHROMIUM_FLAGS = ["--force-renderer-accessibility", f"--remote-debugging-port={CDP_PORT}"]
NEEDED = {"hyprctl": "Hyprland", "grim": "screenshots", "wtype": "typing text", "tmux": "terminal sessions",
          "chromium": "browse and open_url"}


def main(argv):
    parser = argparse.ArgumentParser(prog="canine-computer-use setup", description=__doc__.split("\n")[0])
    parser.add_argument("--host", default="127.0.0.1", help="the address the server listens on (default 127.0.0.1)")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--open-firewall", action="store_true", help="allow the port through ufw, for a --host other "
                        "than 127.0.0.1")
    args = parser.parse_args(argv)

    home = Path.home()
    for command, used_for in NEEDED.items():
        if not shutil.which(command):
            print(f"warning: {command} isn't installed ({used_for} won't work)")

    uinput()
    accessibility(home)
    chromium_flags(home)
    token_changed = auth.save(os.environ.get(auth.ENV))
    service(home, args.host, args.port, restart=token_changed)
    if args.open_firewall:
        sudo("ufw", "allow", f"{args.port}/tcp", "comment", "Computer use")
    print(f"Set up. The server runs as the {SERVICE} user service, on {args.host}:{args.port}; send its token, in "
          f"{auth.token_file()}, as Authorization: Bearer <token>.")


def uinput():
    """The virtual input device, writable by the user's group, now and after every boot."""
    group = grp.getgrgid(os.getgid()).gr_name
    rule = f'KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", GROUP="{group}", MODE="0660"\n'
    changed = write_as_root("/etc/modules-load.d/canine-uinput.conf", "uinput\n")
    changed |= write_as_root("/etc/udev/rules.d/60-canine-uinput.rules", rule)
    if changed or not os.access("/dev/uinput", os.W_OK):
        sudo("modprobe", "uinput")
        sudo("udevadm", "control", "--reload")
        sudo("udevadm", "trigger", "--settle", "/dev/uinput")


def accessibility(home):
    if shutil.which("gsettings"):
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "toolkit-accessibility", "true"], check=True)
    write(home / ".config/environment.d/60-canine-accessibility.conf", "QT_ACCESSIBILITY=1\n")


def chromium_flags(home):
    """Adds the flags Chromium's launcher reads from ~/.config/chromium-flags.conf (Arch's chromium package)."""
    path = home / ".config/chromium-flags.conf"
    lines = path.read_text().splitlines() if path.exists() else []
    missing = [flag for flag in CHROMIUM_FLAGS if flag not in lines]
    if missing:
        write(path, "".join(f"{line}\n" for line in lines + missing))
        print(f"Added {' '.join(missing)} to {path}: restart Chromium for them to take effect.")


def service(home, host, port, restart=False):
    # The console script next to this interpreter: the venv's, which --system-site-packages gives PyGObject
    command = Path(sys.executable).parent / SERVICE
    unit = f"""[Unit]
Description=Computer-use server (canine-computer-use)
After=graphical-session.target
PartOf=graphical-session.target

[Service]
ExecStart={command} --host {host} --port {port}
Restart=always
RestartSec=2
# Restarting the server (an upgrade) mustn't take the terminal sessions it started with it: tmux runs in this unit
KillMode=process

[Install]
WantedBy=graphical-session.target
"""
    units = home / ".config/systemd/user"
    changed = write(units / f"{SERVICE}.service", unit)
    wanted = units / "graphical-session.target.wants" / f"{SERVICE}.service"
    if not wanted.is_symlink():
        wanted.parent.mkdir(parents=True, exist_ok=True)
        wanted.symlink_to(f"../{SERVICE}.service")
    # Start it now if there's a desktop session to run it in (over SSH there may be none: it starts at the next login)
    session = subprocess.run(["systemctl", "--user", "is-active", "--quiet", "graphical-session.target"], stderr=subprocess.DEVNULL)
    if session.returncode == 0:
        subprocess.run(["systemctl", "--user", "daemon-reload"], check=True)
        subprocess.run(["systemctl", "--user", "restart" if changed or restart else "start", f"{SERVICE}.service"], check=True)


def write(path, content):
    """Writes the file unless it already holds this; returns whether it changed."""
    path = Path(path)
    if path.exists() and path.read_text() == content:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    return True


def write_as_root(path, content):
    if Path(path).exists() and Path(path).read_text() == content:
        return False
    sudo("mkdir", "-p", str(Path(path).parent))
    subprocess.run(["sudo", "tee", path], input=content, text=True, stdout=subprocess.DEVNULL, check=True)
    return True


def sudo(*command):
    subprocess.run(["sudo", *command], check=True)
