"""Shell commands in the desktop session: the structured alternative to typing into a terminal and reading the
screen. A command runs with the session's environment (so hyprctl, wtype and GUI apps work), and its output comes back
as text.

It gives an agent nothing new: sudo already needs no password, and an agent could open a terminal and type the same
thing. It's just faster and exact. Every command is logged to the server's journal.
"""

import logging
import os
import signal
import subprocess
import tempfile

log = logging.getLogger("computer_use")

MAX_TIMEOUT = 100    # seconds; Canine waits 120 for a reply
MAX_OUTPUT = 20_000  # characters of stdout and of stderr, each


def run(command, timeout=30):
    """Run `command` with bash in the home directory and return its exit code and output. stdin is closed, so a
    command that waits for input fails instead of hanging.

    The command is done when bash exits. Output goes to temporary files rather than pipes, so something it leaves
    running in the background (wl-copy serving the clipboard, `app &`) neither holds up the reply nor gets killed. On
    timeout, the command and everything it started is killed."""
    timeout = min(max(float(timeout), 1), MAX_TIMEOUT)
    log.info("run: %s", command)
    with tempfile.TemporaryFile("w+", errors="replace") as out, tempfile.TemporaryFile("w+", errors="replace") as err:
        process = subprocess.Popen(["bash", "-lc", command], cwd=os.path.expanduser("~"), stdin=subprocess.DEVNULL,
                                   stdout=out, stderr=err,
                                   start_new_session=True)  # its own process group, so a timeout can kill all of it
        try:
            process.wait(timeout=timeout)
            timed_out = False
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            timed_out = True
        out.seek(0)
        err.seek(0)
        result = {"exit_code": None if timed_out else process.returncode, "stdout": _cut(out.read()),
                  "stderr": _cut(err.read())}
    if timed_out:
        result["timed_out"] = f"killed after {timeout:g}s. To start an app that keeps running, use open_app instead."
    return result


def _cut(text):
    if len(text) <= MAX_OUTPUT:
        return text
    return text[:MAX_OUTPUT] + f"\n[... {len(text) - MAX_OUTPUT} more characters cut]"
