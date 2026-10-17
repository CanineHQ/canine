"""canine-computer-use [--host 127.0.0.1] [--port 8000]  the server (or: python3 -m computer_use)
canine-computer-use mcp                              its tools as a local MCP server, for agent harnesses
canine-computer-use setup [--host ...] [--port ...]  get the desktop ready and install the server as a service"""

import argparse
import logging
import sys


def main():
    if sys.argv[1:2] == ["mcp"]:
        from .mcp import serve as serve_mcp
        return serve_mcp()
    if sys.argv[1:2] == ["setup"]:
        from .setup import main as setup
        return setup(sys.argv[2:])

    parser = argparse.ArgumentParser(description="Canine's computer-use server")
    parser.add_argument("--host", default="127.0.0.1", help="the address to listen on (0.0.0.0 for every interface)")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()

    from . import auth
    token = auth.token()
    if not token:
        parser.exit(1, f"No token: run `canine-computer-use setup`, or set {auth.ENV} (see auth.py)\n")

    from .server import serve
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    serve(args.host, args.port, token)


if __name__ == "__main__":
    main()
