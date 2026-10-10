"""The local MCP server's protocol handling, with the computer-use server faked."""

import json
import unittest
from unittest import mock

from computer_use import mcp


class McpTest(unittest.TestCase):
    def test_initialize_and_list_tools(self):
        init = mcp.handle({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18"}})
        self.assertEqual(init["result"]["capabilities"], {"tools": {}})
        self.assertIsNone(mcp.handle({"jsonrpc": "2.0", "method": "notifications/initialized"}))
        names = [t["name"] for t in mcp.handle({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})["result"]["tools"]]
        self.assertIn("computer_run", names)
        self.assertIn("computer_terminal", names)

    def test_calls_go_to_the_local_server(self):
        with mock.patch.object(mcp, "call_tool", return_value={"content": [{"type": "text", "text": "{}"}], "isError": False}) as call:
            reply = mcp.handle({"jsonrpc": "2.0", "id": 3, "method": "tools/call",
                                "params": {"name": "computer_run", "arguments": {"command": "uname"}}})
        call.assert_called_once_with("computer_run", {"command": "uname"})
        self.assertFalse(reply["result"]["isError"])
        self.assertEqual(mcp.TOOLS["computer_run"][2]({"command": "uname"}), ("POST", "/run", {"command": "uname", "timeout": 30}))
        self.assertEqual(mcp.TOOLS["computer_terminal"][2]({"operation": "wait", "session": "t", "timeout_seconds": 5}),
                         ("POST", "/terminal/wait", {"session": "t", "timeout": 5}))


if __name__ == "__main__":
    unittest.main()
