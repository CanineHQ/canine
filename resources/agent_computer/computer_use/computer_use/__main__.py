"""canine-computer-use [--host 0.0.0.0] [--port 8000]  (or: python3 -m computer_use)"""

import argparse
import logging

from .server import serve


def main():
    parser = argparse.ArgumentParser(description="Canine's computer-use server")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    serve(args.host, args.port)


if __name__ == "__main__":
    main()
