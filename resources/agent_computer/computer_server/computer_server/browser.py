"""Semantic control of the user's own Chrome over CDP, so agents act in the window the person sees.

The image's Chrome wrapper always enables the debugging port (on localhost) with a non-default profile, which
Chrome requires before it will honour --remote-debugging-port.
"""

import asyncio
import os
import subprocess

from playwright.async_api import async_playwright

CDP_URL = "http://127.0.0.1:9222"
MAX_TEXT = 20_000

_playwright = None
_browser = None
_lock = asyncio.Lock()


async def _connect():
    global _playwright, _browser
    async with _lock:
        if _browser is not None and _browser.is_connected():
            return _browser
        if _playwright is None:
            _playwright = await async_playwright().start()
        try:
            _browser = await _playwright.chromium.connect_over_cdp(CDP_URL, timeout=3000)
        except Exception:
            # Not running yet: start it the way the user would, then wait for its debugging port
            subprocess.Popen(["google-chrome"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True, env=os.environ.copy())
            for _ in range(30):
                await asyncio.sleep(0.5)
                try:
                    _browser = await _playwright.chromium.connect_over_cdp(CDP_URL, timeout=2000)
                    break
                except Exception:
                    continue
            else:
                raise RuntimeError("Chrome didn't start with its debugging port; is google-chrome installed?")
        return _browser


async def _page():
    """The tab the person is looking at: the visible, focused one if we can tell, else the last opened."""
    browser = await _connect()
    pages = [page for context in browser.contexts for page in context.pages if not page.url.startswith("devtools://")]
    if not pages:
        return await browser.contexts[0].new_page()
    for page in reversed(pages):
        try:
            if await page.evaluate("document.visibilityState === 'visible' && document.hasFocus()"):
                return page
        except Exception:
            continue
    for page in reversed(pages):
        try:
            if await page.evaluate("document.visibilityState === 'visible'"):
                return page
        except Exception:
            continue
    return pages[-1]


def _locator(page, role=None, name=None, selector=None, text=None, index=0):
    if selector:
        locator = page.locator(selector)
    elif role:
        locator = page.get_by_role(role, name=name) if name else page.get_by_role(role)
    elif text or name:
        locator = page.get_by_text(text or name)
    else:
        raise ValueError("Provide selector, role (optionally with name), or text")
    return locator.nth(index)


async def browser_open(url: str = None):
    page = await _page()
    if url:
        await page.goto(url, wait_until="domcontentloaded")
    await page.bring_to_front()
    return {"url": page.url, "title": await page.title()}


async def browser_snapshot(selector: str = "body"):
    """ARIA outline of the current page: roles, names and text, like a screen reader sees it."""
    page = await _page()
    return {"url": page.url, "title": await page.title(), "snapshot": await page.locator(selector).aria_snapshot()}


async def browser_url():
    page = await _page()
    return {"url": page.url, "title": await page.title()}


async def browser_goto(url: str):
    page = await _page()
    await page.goto(url, wait_until="domcontentloaded")
    return {"url": page.url, "title": await page.title()}


async def browser_back():
    page = await _page()
    await page.go_back(wait_until="domcontentloaded")
    return {"url": page.url}


async def browser_click(role: str = None, name: str = None, selector: str = None, text: str = None, index: int = 0):
    page = await _page()
    await _locator(page, role, name, selector, text, index).click(timeout=5000)
    return {"url": page.url}


async def browser_fill(value: str, role: str = None, name: str = None, selector: str = None, index: int = 0):
    page = await _page()
    await _locator(page, role or ("textbox" if not selector else None), name, selector, None, index).fill(value, timeout=5000)
    return {}


async def browser_press(key: str):
    page = await _page()
    await page.keyboard.press(key)
    return {}


async def browser_text(selector: str = "body", max_chars: int = MAX_TEXT):
    page = await _page()
    return {"url": page.url, "text": (await page.locator(selector).inner_text(timeout=5000))[:max_chars]}


async def browser_tabs():
    browser = await _connect()
    tabs = [page for context in browser.contexts for page in context.pages]
    return {"tabs": [{"index": i, "url": page.url, "title": await page.title()} for i, page in enumerate(tabs)]}


async def browser_switch_tab(index: int):
    browser = await _connect()
    tabs = [page for context in browser.contexts for page in context.pages]
    await tabs[index].bring_to_front()
    return {"url": tabs[index].url}
