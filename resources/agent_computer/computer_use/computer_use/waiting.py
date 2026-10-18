"""Waiting for something on screen, e.g. a page to load: check, sleep, check again, until it's there or time is up."""

import time

MAX_WAIT = 30  # seconds: Canine's request to this server times out after 120


def until(check, timeout, interval=0.5, clock=time.monotonic, sleep=time.sleep):
    """Call check() until it returns something truthy, or `timeout` seconds pass. Returns (result, seconds waited);
    the result is the last check's, falsy if time ran out."""
    start = clock()
    deadline = start + min(max(timeout, 0), MAX_WAIT)
    while True:
        result = check()
        if result or clock() >= deadline:
            return result, round(clock() - start, 1)
        sleep(interval)
