"""terminal.py against a real tmux (skipped where there's none), without opening a window."""

import shutil
import unittest
from unittest import mock

from computer_use import terminal


@unittest.skipUnless(shutil.which("tmux"), "needs tmux")
class TerminalTest(unittest.TestCase):
    def setUp(self):
        patcher = mock.patch.object(terminal, "SOCKET", "canine-test")
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(lambda: terminal._tmux("kill-server", check=False))

    def test_send_read_wait_close(self):
        session = terminal.open_session("bash --norc --noprofile", show=False)["session"]
        self.assertEqual(session, "term1")
        terminal.send(session, "echo $((6 * 7))", enter=True)
        self.assertIn("42", terminal.wait(session, text="42", timeout=10)["screen"])

        terminal.send(session, "sleep 30", enter=True)
        terminal.send(session, keys=["C-c"])  # interrupt it
        terminal.send(session, "echo after", enter=True)
        self.assertIn("after", terminal.wait(session, text="after", timeout=10)["screen"])

        terminal.send(session, "exit", enter=True)
        self.assertTrue(terminal.wait(session, timeout=10)["finished"])  # the last screen stays readable
        terminal.close(session)
        self.assertEqual(terminal.list_sessions(), {"sessions": []})

    def test_unknown_session(self):
        with self.assertRaises(LookupError):
            terminal.read("nope")


if __name__ == "__main__":
    unittest.main()
