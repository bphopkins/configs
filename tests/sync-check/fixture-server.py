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

The database's per-file records come from the table's "__files__" entry, a
map from folder id to a map from path to a record ({"type": "dir"|"file",
"version": [...], "modifiedBy": ..., "modified": ..., "local": {...}}): GET
/rest/db/browse answers the tree under its prefix as Syncthing 2.1 does (the
prefix itself left out, directories carrying "children" when they have any,
an unknown prefix []), and GET /rest/db/file a path's global and local
records, 404 "No such object in the index" for a path it does not hold. An
explicit table entry for the full request still wins, so a case can make
either answer fail.
"""
import http.server
import json
import os
import sys
import threading
import urllib.parse

PORT, DIR, KEY = int(sys.argv[1]), sys.argv[2], sys.argv[3]
seq_state = {}
seq_mtime = [None]     # a __seq__ starts again whenever responses.json is rewritten
lock = threading.Lock()


def record(path, rec, local=False):
    r = dict(rec.get("local") or rec) if local else dict(rec)
    r.pop("local", None)
    kind = r.pop("type", "file")
    out = {"name": path, "type": "FILE_INFO_TYPE_DIRECTORY" if kind == "dir" else "FILE_INFO_TYPE_FILE",
           "modified": "2026-10-10T14:34:13.746347596-07:00", "modifiedBy": "BIGFEDX", "version": ["BIGFEDX:1791668457"],
           "sequence": 1, "deleted": False, "invalid": False, "ignored": False, "size": 0 if kind == "dir" else 10}
    out.update(r)
    return out


def db_answer(files, method, path):
    """db/browse and db/file from the per-file records, or None."""
    if method != "GET":
        return None
    u = urllib.parse.urlsplit(path)
    q = dict(urllib.parse.parse_qsl(u.query, keep_blank_values=True))
    if u.path == "/rest/db/file" and "folder" in q and "file" in q:
        recs = files.get(q["folder"])
        if recs is None:
            return {"status": 404, "body": "no such folder\n"}
        rec = recs.get(q["file"])
        if rec is None and any(k.startswith(q["file"] + "/") for k in recs):
            rec = {"type": "dir"}       # a directory the records hold only by its contents
        if rec is None:
            return {"status": 404, "body": "No such object in the index\n"}
        return {"body": {"availability": [], "global": record(q["file"], rec), "local": record(q["file"], rec, local=True)}}
    if u.path == "/rest/db/browse" and "folder" in q:
        recs = files.get(q["folder"])
        if recs is None:
            return {"status": 404, "body": "no such folder\n"}
        prefix = q.get("prefix", "").strip("/")
        root = []
        nodes = {}
        for p in sorted(recs):
            if prefix and not p.startswith(prefix + "/"):
                continue
            rel = p[len(prefix) + 1:] if prefix else p
            parent = root
            parts = rel.split("/")
            for i, name in enumerate(parts):
                key = "/".join(parts[:i + 1])
                if key not in nodes:
                    full = (prefix + "/" + key) if prefix else key
                    rec = recs.get(full, {"type": "dir"})
                    node = {"name": name, "modTime": rec.get("modified", "2026-10-10T14:34:13.746347596-07:00"),
                            "size": 0 if rec.get("type") == "dir" else rec.get("size", 10),
                            "type": "FILE_INFO_TYPE_DIRECTORY" if rec.get("type") == "dir" else "FILE_INFO_TYPE_FILE"}
                    nodes[key] = node
                    parent.append(node)
                node = nodes[key]
                if i < len(parts) - 1:
                    parent = node.setdefault("children", [])
        return {"body": root}
    return None


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
            entry = db_answer(table.get("__files__") or {}, self.command, self.path)
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
