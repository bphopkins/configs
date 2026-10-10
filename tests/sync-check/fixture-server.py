#!/usr/bin/env python3
"""A stand-in for one Syncthing instance's REST API, for tests/sync-check/run.sh.

    fixture-server.py PORT DIR KEY

Serves 127.0.0.1:PORT from DIR/responses.json, re-read on every request so a
case can change it without a restart: a map from "METHOD /rest/path?query" to
{"status": N, "body": ...}; a key without its query string is the fallback.
A body of {"__seq__": [b1, b2, ...]} is served in order, the last repeating,
which is how a need that clears on a re-read is staged. Every request needs
the X-API-Key header equal to KEY (403 otherwise, as Syncthing answers), and
an unknown path answers 404 "no such folder". Each request is appended to
DIR/requests.log as "METHOD /rest/path?query". Nothing else is written.
"""
import http.server
import json
import os
import sys
import threading

PORT, DIR, KEY = int(sys.argv[1]), sys.argv[2], sys.argv[3]
seq_state = {}
seq_mtime = [None]     # a __seq__ starts again whenever responses.json is rewritten
lock = threading.Lock()


class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def answer(self):
        with lock:
            with open(os.path.join(DIR, "requests.log"), "a") as fh:
                fh.write("%s %s\n" % (self.command, self.path))
        if self.headers.get("X-API-Key") != KEY:
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b"Forbidden")
            return
        try:
            path = os.path.join(DIR, "responses.json")
            with lock:
                m = os.stat(path).st_mtime_ns
                if m != seq_mtime[0]:
                    seq_mtime[0] = m
                    seq_state.clear()
            with open(path) as fh:
                table = json.load(fh)
        except (OSError, ValueError):
            table = {}
        key = "%s %s" % (self.command, self.path)
        entry = table.get(key)
        if entry is None:
            entry = table.get(key.split("?", 1)[0])
        if entry is None:
            self.send_response(404)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"no such folder\n")
            return
        body = entry.get("body", {})
        if isinstance(body, dict) and "__seq__" in body:
            with lock:
                n = seq_state.get(key, 0)
                seq_state[key] = n + 1
            seq = body["__seq__"]
            body = seq[min(n, len(seq) - 1)]
        data = json.dumps(body).encode() if not isinstance(body, str) else body.encode()
        self.send_response(int(entry.get("status", 200)))
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(data)

    do_GET = answer
    do_POST = answer


srv = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), H)
srv.serve_forever()
