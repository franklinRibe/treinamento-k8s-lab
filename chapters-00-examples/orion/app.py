import json
import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/ready":
            self.respond(200, {"ready": True})
            return
        if self.path == "/":
            self.respond(
                200,
                {
                    "application": "orion-api",
                    "environment": os.environ.get("ORION_ENV", "undefined"),
                    "hostname": socket.gethostname(),
                    "tokenConfigured": bool(os.environ.get("API_TOKEN")),
                },
            )
            return
        self.respond(404, {"error": "not found"})

    def respond(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        print(f"http status={args[1]} request={args[0]}", flush=True)


print("orion-api listening on :8080", flush=True)
ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
