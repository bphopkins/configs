#!/usr/bin/env python3
"""Writes the three fixture instances of a case for tests/sync-check/run.sh.

    scenario.py SB ME [dotted.override=JSON ...]

SB is the suite's sandbox; ME the host the gauge runs on (fedxps or bigfed).
Writes, for each of fedxps, bigfed and nousowl: SB/ssh/<host>/config.xml (the
instance's Syncthing configuration, structurally the real thing: gui address
and key, devices, folders with their devices, the hub's entry carrying a
password on a workstation) and SB/fx/<host>/responses.json (its REST
answers). The base case is everything up to date; an override names a value
by a dotted path into the spec below and sets it, e.g.
    fedxps.folders.f1.state=\"syncing\"
    bigfed.folders.f3.completion.HUB.needItems=1
    nousowl.connected.BIG=false
Device ids may be written as the aliases FED, BIG, HUB. Ports come from
SB/ports (three lines: fedxps, bigfed, nousowl) and the key from SB/key.
"""
import json
import os
import sys
import xml.sax.saxutils as X

SB, ME = sys.argv[1], sys.argv[2]
IDS = {"FED": "FEDXPSX-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG",
       "BIG": "BIGFEDX-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG",
       "HUB": "HUBHUBH-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG"}
NAMES = {"FED": "fedxps", "BIG": "bigfed", "HUB": "nousowl"}
ports = dict(zip(["fedxps", "bigfed", "nousowl"], open(os.path.join(SB, "ports")).read().split()))
key = open(os.path.join(SB, "key")).read().strip()
HOMES = {"fedxps": os.path.join(SB, "ssh", "fedxps", "home"), "bigfed": os.path.join(SB, "ssh", "bigfed", "home"),
         "nousowl": os.path.join(SB, "ssh", "nousowl", "home")}
FOLDERS = [("f1", "alpha", "Desktop/alpha"), ("f2", "nousowl", "Desktop/nousowl"), ("f3", "gamma", ".local/share/adelotype")]
# f3's label is gamma; the cases for the known stuck item override it to the
# label KNOWN names, so every other case reads a folder nothing is known about.


def workstation(alias):
    other = "BIG" if alias == "FED" else "FED"
    spec = {"myID": IDS[alias], "startTime": "2026-10-10T10:04:50-07:00", "connected": {"HUB": True},
            "devices": ["HUB", alias], "folders": {}, "events": [], "hub_enc": True, "type": "sendreceive"}
    for fid, label, rel in FOLDERS:
        spec["folders"][fid] = {"label": label, "path": os.path.join(HOMES[NAMES[alias]], rel), "paused": False, "maxConflicts": 10,
                                "state": "idle", "needTotalItems": 0, "needDeletes": 0, "needNames": [], "pullErrors": 0, "error": "",
                                "globalTotalItems": 10, "localTotalItems": 10,
                                "completion": {"HUB": {"remoteState": "valid", "needItems": 0, "needDeletes": 0, "completion": 100, "names": []}}}
    return spec


def hub():
    spec = {"myID": IDS["HUB"], "startTime": "2026-10-09T15:46:45-07:00", "connected": {"FED": True, "BIG": True},
            "devices": ["HUB", "FED", "BIG"], "folders": {}, "events": [], "hub_enc": False, "type": "receiveencrypted"}
    for fid, label, rel in FOLDERS:
        spec["folders"][fid] = {"label": label, "path": os.path.join(HOMES["nousowl"], "sync", label), "paused": False, "maxConflicts": 10,
                                "state": "idle", "needTotalItems": 0, "needDeletes": 0, "needNames": [], "pullErrors": 0, "error": "",
                                "globalTotalItems": 10, "localTotalItems": 10,
                                "completion": {"FED": {"remoteState": "valid", "needItems": 0, "needDeletes": 0, "completion": 100, "names": []},
                                               "BIG": {"remoteState": "valid", "needItems": 0, "needDeletes": 0, "completion": 100, "names": []}}}
    return spec


specs = {"fedxps": workstation("FED"), "bigfed": workstation("BIG"), "nousowl": hub()}

for ov in sys.argv[3:]:
    path, val = ov.split("=", 1)
    parts = path.split(".")
    cur = specs
    for p in parts[:-1]:
        cur = cur.setdefault(p, {})
    last = parts[-1]
    v = val if val == "__delete__" else json.loads(val)
    if v == "__delete__":
        cur.pop(last, None)
    else:
        cur[last] = v


def write_config(host, spec):
    d = os.path.join(SB, "ssh", host)
    os.makedirs(d, exist_ok=True)
    lines = ['<configuration version="50">']
    for fid, f in spec["folders"].items():
        lines.append('    <folder id=%s label=%s path=%s type=%s rescanIntervalS="3600" fsWatcherEnabled="true" fsWatcherDelayS="2" ignorePerms="false" autoNormalize="true">'
                     % (X.quoteattr(fid), X.quoteattr(f["label"]), X.quoteattr(f["path"]), X.quoteattr(spec["type"])))
        for alias in spec["devices"]:
            enc = "secret" if (alias == "HUB" and spec["hub_enc"]) else ""
            lines.append('        <device id=%s introducedBy=""><encryptionPassword>%s</encryptionPassword></device>' % (X.quoteattr(IDS[alias]), enc))
        lines.append("        <maxConflicts>%d</maxConflicts>" % f["maxConflicts"])
        lines.append("        <paused>%s</paused>" % ("true" if f["paused"] else "false"))
        lines.append("    </folder>")
    for alias in spec["devices"]:
        lines.append('    <device id=%s name=%s compression="metadata" introducer="false" skipIntroductionRemovals="false" introducedBy=""><address>dynamic</address></device>'
                     % (X.quoteattr(IDS[alias]), X.quoteattr(NAMES[alias])))
    for d in spec.get("extra_devices", []):     # devices known to the instance but on no folder
        lines.append('    <device id=%s name=%s compression="metadata" introducer="false" skipIntroductionRemovals="false" introducedBy=""><address>dynamic</address></device>'
                     % (X.quoteattr(d["id"]), X.quoteattr(d["name"])))
    lines.append('    <gui enabled="true" tls="false" sendBasicAuthPrompt="false"><address>127.0.0.1:%s</address><apikey>%s</apikey></gui>' % (ports[host], key))
    lines.append("    <options><listenAddress>tcp://127.0.0.1:0</listenAddress></options>")
    lines.append("</configuration>")
    with open(os.path.join(d, "config.xml"), "w") as fh:
        fh.write("\n".join(lines) + "\n")


def write_responses(host, spec):
    d = os.path.join(SB, "fx", host)
    os.makedirs(d, exist_ok=True)
    t = {}
    t["GET /rest/system/status"] = {"body": {"myID": spec["myID"], "startTime": spec["startTime"], "uptime": 100}}
    t["GET /rest/system/connections"] = {"body": {"connections": {IDS[a]: {"connected": c, "paused": False} for a, c in spec["connected"].items()}, "total": {}}}
    for fid, f in spec["folders"].items():
        t["POST /rest/db/scan?folder=%s" % fid] = {"body": {}}
        status = {"state": f["state"], "needTotalItems": f["needTotalItems"], "needFiles": f["needTotalItems"] - f["needDeletes"],
                  "needDirectories": 0, "needSymlinks": 0, "needDeletes": f["needDeletes"], "needBytes": 0,
                  "pullErrors": f["pullErrors"], "errors": 0, "error": f["error"], "watchError": f.get("watchError", ""),
                  "globalTotalItems": f["globalTotalItems"], "localTotalItems": f["localTotalItems"], "sequence": 1, "stateChanged": "2026-10-10T11:00:00-07:00"}
        if "status_seq" in f:
            t["GET /rest/db/status?folder=%s" % fid] = {"body": {"__seq__": [dict(status, **s) for s in f["status_seq"]]}}
        else:
            t["GET /rest/db/status?folder=%s" % fid] = {"body": status}
        t["GET /rest/db/need?folder=%s" % fid] = {"body": {"progress": [{"name": n, "type": "FILE_INFO_TYPE_FILE"} for n in f["needNames"]], "queued": [], "rest": [], "page": 1, "perpage": 65536}}
        for alias, c in f["completion"].items():
            did = IDS[alias]
            t["GET /rest/db/completion?folder=%s&device=%s" % (fid, did)] = {"body": {"completion": c["completion"], "globalBytes": 1, "needBytes": 0, "globalItems": f["globalTotalItems"],
                                                                                   "needItems": c["needItems"], "needDeletes": c["needDeletes"], "remoteState": c["remoteState"], "sequence": 1}}
            t["GET /rest/db/remoteneed?folder=%s&device=%s" % (fid, did)] = {"body": {"files": [{"name": n, "type": "FILE_INFO_TYPE_FILE"} for n in c["names"]], "page": 1, "perpage": 65536}}
    t["GET /rest/events/disk?since=0&limit=1000&timeout=0"] = {"body": spec["events"]}
    with open(os.path.join(d, "responses.json"), "w") as fh:
        json.dump(t, fh, indent=1)


for host, spec in specs.items():
    write_config(host, spec)
    write_responses(host, spec)
