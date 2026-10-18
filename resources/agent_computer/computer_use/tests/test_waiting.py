"""Waiting until something appears, without really sleeping."""

import unittest

from computer_use import waiting


class FakeClock:
    def __init__(self):
        self.now = 0.0

    def __call__(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds


class WaitingTest(unittest.TestCase):
    def test_returns_once_the_check_passes(self):
        clock = FakeClock()
        checks = iter([None, None, {"found": True}])
        result, waited = waiting.until(lambda: next(checks), timeout=10, clock=clock, sleep=clock.sleep)
        self.assertEqual(result, {"found": True})
        self.assertEqual(waited, 1.0)

    def test_gives_up_at_the_timeout_capped_at_max_wait(self):
        clock = FakeClock()
        result, waited = waiting.until(lambda: None, timeout=999, clock=clock, sleep=clock.sleep)
        self.assertIsNone(result)
        self.assertEqual(waited, waiting.MAX_WAIT)


if __name__ == "__main__":
    unittest.main()
