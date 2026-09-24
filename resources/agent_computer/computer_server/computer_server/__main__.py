"""python -m computer_server [--host 0.0.0.0] [--port 8000]; run inside the desktop session (needs DISPLAY)."""

import argparse
import logging

import uvicorn

from . import takeover
from .server import app


def main():
    parser = argparse.ArgumentParser(description="Canine computer server")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    takeover.start()
    uvicorn.run(app, host=args.host, port=args.port, ws="websockets", log_level="info")


if __name__ == "__main__":
    main()
