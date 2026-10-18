"""The server's token: every request needs `Authorization: Bearer <token>`.

It comes from COMPUTER_USE_TOKEN, or else the token file, which `setup` creates (readable only by the desktop user;
`canine-computer-use mcp`, running as that user, reads it too). Whoever drives the server needs it:

    curl -H "Authorization: Bearer $(cat ~/.config/canine-computer-use/token)" http://127.0.0.1:8000/status
"""

import hmac
import os
import secrets
from pathlib import Path

ENV = "COMPUTER_USE_TOKEN"


def token_file():
    return Path.home() / ".config/canine-computer-use/token"


def token():
    """The token, or None if there's none set up."""
    path = token_file()
    value = os.environ.get(ENV) or (path.read_text().strip() if path.exists() else "")
    return value or None


def save(value=None):
    """Writes the token file (a new random token unless given one), readable only by this user. Returns whether it
    changed."""
    path = token_file()
    if path.exists() and (value is None or path.read_text().strip() == value):
        return False
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "w") as file:
        file.write((value or secrets.token_urlsafe(32)) + "\n")
    os.chmod(path, 0o600)  # in case the file was already there with looser permissions
    return True


def authorized(header, expected):
    return bool(header) and hmac.compare_digest(header.encode(), f"Bearer {expected}".encode())
