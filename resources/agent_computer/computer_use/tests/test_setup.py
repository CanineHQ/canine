"""setup.py against a temporary home, with sudo and systemctl stubbed out: what it writes, and that a second run
changes nothing but a token it's given."""

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from computer_use import setup


class SetupTest(unittest.TestCase):
    def test_sets_up_once_then_leaves_it_alone(self):
        home = Path(tempfile.mkdtemp())
        (home / ".config").mkdir()
        (home / ".config/chromium-flags.conf").write_text("--ozone-platform=wayland\n")
        root_files = {}

        def write_as_root(path, content):
            changed = root_files.get(path) != content
            root_files[path] = content
            return changed

        with mock.patch.object(Path, "home", return_value=home), \
             mock.patch.object(setup.subprocess, "run", return_value=mock.Mock(returncode=0)) as subprocess_run, \
             mock.patch.object(setup.os, "access", return_value=True), \
             mock.patch.object(setup, "write_as_root", side_effect=write_as_root):
            setup.main(["--port", "8123"])
            unit = (home / ".config/systemd/user/canine-computer-use.service").read_text()
            self.assertIn("canine-computer-use --host 127.0.0.1 --port 8123", unit)
            self.assertTrue((home / ".config/systemd/user/graphical-session.target.wants/canine-computer-use.service").is_symlink())
            self.assertEqual((home / ".config/chromium-flags.conf").read_text().splitlines(),
                             ["--ozone-platform=wayland", "--force-renderer-accessibility", "--remote-debugging-port=9222"])
            token_file = home / ".config/canine-computer-use/token"
            self.assertEqual(token_file.stat().st_mode & 0o777, 0o600)
            token = token_file.read_text()
            self.assertIn("uinput", root_files["/etc/modules-load.d/canine-uinput.conf"])
            self.assertIn(["sudo", "modprobe", "uinput"], [c.args[0] for c in subprocess_run.call_args_list])
            self.assertIn(["systemctl", "--user", "restart", "canine-computer-use.service"],
                          [c.args[0] for c in subprocess_run.call_args_list])

            subprocess_run.reset_mock()
            setup.main(["--port", "8123"])
            commands = [c.args[0] for c in subprocess_run.call_args_list]
            self.assertFalse([c for c in commands if c[0] == "sudo"])  # nothing left needing root
            self.assertIn(["systemctl", "--user", "start", "canine-computer-use.service"], commands)
            self.assertEqual(len((home / ".config/chromium-flags.conf").read_text().splitlines()), 3)
            self.assertEqual(token_file.read_text(), token)  # kept, not a new one

            with mock.patch.dict(setup.os.environ, {"COMPUTER_USE_TOKEN": "from-canine"}):
                subprocess_run.reset_mock()
                setup.main(["--port", "8123"])  # a given token replaces it, and the server restarts to use it
            self.assertEqual(token_file.read_text(), "from-canine\n")
            self.assertIn(["systemctl", "--user", "restart", "canine-computer-use.service"],
                          [c.args[0] for c in subprocess_run.call_args_list])


if __name__ == "__main__":
    unittest.main()
