"""The arrows on screen now, one JSON file each in $XDG_RUNTIME_DIR/bigarrow, so `stop` and `list` can find them.
An overlay writes its file once it's showing and removes it as it goes."""

import json
import os
import signal
from pathlib import Path


def directory():
    base = os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/bigarrow-{os.getuid()}"
    path = Path(base) / "bigarrow"
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    return path


def save(arrow):
    path = directory() / f"{arrow['id']}.json"
    path.write_text(json.dumps(arrow))


def remove(arrow_id):
    (directory() / f"{arrow_id}.json").unlink(missing_ok=True)


def showing(arrow_id):
    return (directory() / f"{arrow_id}.json").exists()


def arrows():
    """The arrows showing, oldest first; files left by an overlay that died are cleared away."""
    found = []
    for path in sorted(directory().glob("*.json"), key=lambda p: p.stat().st_mtime):
        try:
            arrow = json.loads(path.read_text())
            os.kill(arrow["pid"], 0)
        except (ValueError, KeyError, ProcessLookupError):
            path.unlink(missing_ok=True)
            continue
        except PermissionError:
            pass
        found.append(arrow)
    return found


def stop(arrow_ids=None):
    """Ends the given arrows (every one without ids); returns the ids it stopped."""
    stopped = []
    for arrow in arrows():
        if arrow_ids is None or arrow["id"] in arrow_ids:
            try:
                os.kill(arrow["pid"], signal.SIGTERM)
            except ProcessLookupError:
                pass
            remove(arrow["id"])
            stopped.append(arrow["id"])
    return stopped
