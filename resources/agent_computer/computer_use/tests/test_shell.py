"""shell.run against the local machine: output, exit codes, closed stdin, timeouts and long output."""

import time
import unittest
from unittest import mock

from computer_use import shell


class ShellTest(unittest.TestCase):
    def test_output_and_exit_code(self):
        result = shell.run("echo hi; echo oops >&2; exit 3")
        self.assertEqual((result["exit_code"], result["stdout"]), (3, "hi\n"))
        self.assertTrue(result["stderr"].endswith("oops\n"))  # after anything the login profile prints

    def test_stdin_is_closed_so_reading_input_does_not_hang(self):
        self.assertEqual(shell.run("read line; echo got:$line")["stdout"], "got:\n")

    def test_timeout_kills_the_command_and_what_it_started(self):
        started = time.monotonic()
        result = shell.run("sleep 30 & sleep 30", timeout=1)
        self.assertLess(time.monotonic() - started, 5)
        self.assertIsNone(result["exit_code"])
        self.assertIn("open_app", result["timed_out"])

    def test_background_processes_do_not_hold_up_the_reply_and_keep_running(self):
        started = time.monotonic()
        result = shell.run("sleep 3 & echo $! > /tmp/canine-shell-test.pid; echo started", timeout=10)
        self.assertLess(time.monotonic() - started, 2)
        self.assertEqual(result["stdout"], "started\n")
        self.assertEqual(shell.run("kill -0 $(cat /tmp/canine-shell-test.pid) && echo alive")["stdout"], "alive\n")

    def test_long_output_is_cut(self):
        with mock.patch.object(shell, "MAX_OUTPUT", 10):
            self.assertEqual(shell.run("printf 0123456789abcdef")["stdout"], "0123456789\n[... 6 more characters cut]")


if __name__ == "__main__":
    unittest.main()
