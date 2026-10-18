"""The server: requests need its token, except for the docs, which cover every route."""

import importlib.util
import json
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer


@unittest.skipUnless(importlib.util.find_spec("gi"), "the server needs PyGObject")
class ServerTest(unittest.TestCase):
    def test_requests_need_the_token(self):
        from computer_use import server

        httpd = ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)
        httpd.token = "secret"
        threading.Thread(target=httpd.serve_forever, daemon=True).start()
        self.addCleanup(httpd.shutdown)

        def status(authorization):
            headers = {"Authorization": authorization} if authorization else {}
            request = urllib.request.Request(f"http://127.0.0.1:{httpd.server_port}/nowhere", headers=headers)
            try:
                urllib.request.urlopen(request)
            except urllib.error.HTTPError as error:
                return error.code, json.loads(error.read())["error"]

        self.assertEqual(status(None)[0], 401)
        self.assertEqual(status("Bearer wrong")[0], 401)
        self.assertEqual(status("Bearer secret"), (404, "No route GET /nowhere"))  # through to the routes

        docs = urllib.request.urlopen(f"http://127.0.0.1:{httpd.server_port}/docs")
        self.assertIn("swagger-ui", docs.read().decode())
        spec = json.load(urllib.request.urlopen(f"http://127.0.0.1:{httpd.server_port}/openapi.json"))
        documented = {(method.upper(), path) for path, operations in spec["paths"].items() for method in operations}
        self.assertEqual(documented, set(server.ROUTES))


if __name__ == "__main__":
    unittest.main()
