"""canine-computer-use [--host 0.0.0.0] [--port 8000]  the server (or: python3 -m computer_use)
canine-computer-use mcp                              its tools as a local MCP server, for agent harnesses"""

import argparse
import logging
import sys


def main():
    if sys.argv[1:2] == ["mcp"]:
        from .mcp import serve as serve_mcp
        return serve_mcp()

    parser = argparse.ArgumentParser(description="Canine's computer-use server")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()

    from .server import serve
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    serve(args.host, args.port)


if __name__ == "__main__":
    main()
