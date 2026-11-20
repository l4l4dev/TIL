"""Answers every GET with the number of requests the server has seen so far.

MODE=plain    Last-Modified only, no Cache-Control (default)
MODE=bare     neither Last-Modified nor Cache-Control
MODE=nostore  Last-Modified and Cache-Control: no-store
AGE_SECONDS   how long ago Last-Modified is (default: 30 days)
"""
import os
import sys
from datetime import datetime, timedelta, timezone
from email.utils import format_datetime
from http.server import BaseHTTPRequestHandler, HTTPServer

MODE = os.environ.get("MODE", "plain")
AGE = float(os.environ.get("AGE_SECONDS", 30 * 24 * 3600))
LAST_MODIFIED = format_datetime(datetime.now(timezone.utc) - timedelta(seconds=AGE), usegmt=True)
count = 0


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        global count
        count += 1
        body = f"answer #{count}".encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        if MODE != "bare":
            self.send_header("Last-Modified", LAST_MODIFIED)
        if MODE == "nostore":
            self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        sys.stderr.write(f"server: request {count}\n")


HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
