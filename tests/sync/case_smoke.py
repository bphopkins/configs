#!/usr/bin/env python3
"""Case 1, the smoke test: the rig itself.

Three instances generated and locked down before their first start, started,
paired through the hub; every socket they listen on is on 127.0.0.1; a folder
with two files written on A reaches B through H byte-identical within 30 s;
every view reads 100; the read helpers the cases lean on answer in the shapes
they expect (db/browse, db/need, db/remoteneed, folder/errors, db/file's
vector), and on a receive-only B a file made there is listed by
db/localchanged and undone by db/revert; with A and B paired as well, a file
crosses the direct link (ws-16); the hub holds ciphertext only (neither
file's name nor content anywhere under its copy); and once stopped, no
process of the rig is left.

    python3 -I case_smoke.py ROOT     (ROOT: an empty directory in the sandbox)
"""
import os
import secrets
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402


def main(root):
    C = rig.Checks()
    r = rig.Rig(root)
    t0 = time.time()
    r.trio()
    C.note("three instances up and paired through the hub in %.1f s" % (time.time() - t0))

    for n in ("A", "B", "H"):
        for when, v in (("before the first start", r[n].before_start), ("as running", r[n].locked_down())):
            C.check("%s, %s: announce, relays, NAT, crash and usage reporting, upgrades, STUN off" % (n, when),
                    all(v[k] == "false" for k in ("globalAnnounceEnabled", "localAnnounceEnabled", "relaysEnabled",
                                                  "natEnabled", "crashReportingEnabled", "startBrowser",
                                                  "announceLANAddresses"))
                    and v["urAccepted"] == "-1" and v["autoUpgradeIntervalH"] == "0"
                    and v["stunKeepaliveStartS"] == "0" and v["globalAnnounceServer"] == [rig.NO_ANNOUNCE], v)
            C.check("%s, %s: GUI and listen address on 127.0.0.1 only, no folder" % (n, when),
                    v["gui"].startswith("127.0.0.1:") and len(v["listen"]) == 1
                    and v["listen"][0].startswith("tcp://127.0.0.1:") and v["folders"] == [], v)
    socks = r.sockets()
    C.check("every socket a rig process listens on is on 127.0.0.1 (%d sockets)" % len(socks),
            len(socks) >= 6 and all(a.startswith("127.0.0.1:") for _, _, a in socks), socks)
    o = r["A"].api("GET", "config/options")
    C.check("the running instance agrees: discovery, relays and NAT off",
            not (o["globalAnnounceEnabled"] or o["localAnnounceEnabled"] or o["relaysEnabled"] or o["natEnabled"]
                 or o["crashReportingEnabled"]) and o["urAccepted"] == -1, {k: o.get(k) for k in (
                     "globalAnnounceEnabled", "localAnnounceEnabled", "relaysEnabled", "natEnabled", "urAccepted")})

    fid = r.share("smoke-" + secrets.token_hex(3))
    marks = {"plaintext-alpha-%s.txt" % secrets.token_hex(4): "alpha content %s\n" % secrets.token_hex(8),
             os.path.join("plainsub", "plaintext-beta-%s.md" % secrets.token_hex(4)): "beta content %s\n" % secrets.token_hex(8) * 50}
    os.makedirs(r.path("A", fid, "plainsub"), exist_ok=True)
    tw = time.time()
    for name, text in marks.items():
        with open(r.path("A", fid, name), "w") as f:
            f.write(text)
    want = {name: rig.sha256_file(r.path("A", fid, name)) for name in marks}
    arrived = None
    while time.time() - tw < 30:
        try:
            if all(os.path.exists(r.path("B", fid, n)) and rig.sha256_file(r.path("B", fid, n)) == h
                   for n, h in want.items()):
                arrived = time.time() - tw
                break
        except OSError:
            pass
        time.sleep(0.05)
    C.check("two files from A reach B through H byte-identical within 30 s",
            arrived is not None, "B holds: %s" % r.files("B", fid))
    if arrived is not None:
        C.note("arrival A -> H -> B: %.2f s after the write (A's watcher delay 2 s)" % arrived)
    try:
        C.note("idle everywhere %.1f s later" % r.wait_idle(["A", "B", "H"], fid, settle=2))
    except rig.RigError as e:
        C.check("the folder settles", False, e)
    C.check("every view reads 100 with nothing needed", r.views_clear(r.views(fid)), r.views(fid))

    # the remaining read helpers answer, in the shapes the cases use
    alpha = [n for n in marks if "/" not in n][0]
    b = r.browse("B", fid)
    C.check("db/browse on B lists the folder's top level",
            isinstance(b, list) and {e.get("name") for e in b} >= {alpha, "plainsub"}, b)
    nd = r.need("B", fid)
    C.check("db/need on B: nothing in progress, queued or waiting",
            isinstance(nd, dict) and not any(nd.get(k) for k in ("progress", "queued", "rest")), nd)
    C.check("db/remoteneed from A for H: nothing", r.remoteneed_names("A", fid, "H") == [])
    C.check("folder/errors on B: none", r.folder_errors("B", fid) == [])
    C.check("db/file on B: the file's vector carries A's counter alone",
            r.vector_devices("B", fid, alpha) == [r["A"].short_id], r.vector("B", fid, alpha))
    rid = r.share("smoke-ro-" + secrets.token_hex(3), types={"B": "receiveonly"})
    with open(r.path("B", rid, "local-only.txt"), "w") as f:
        f.write("made on the receive-only side\n")
    r.scan("B", rid)
    lc = r.localchanged("B", rid)
    C.check("db/localchanged on a receive-only B lists a file made there",
            [x.get("name") for x in (lc or {}).get("files") or []] == ["local-only.txt"], lc)
    r.revert("B", rid)
    r.wait_idle(["A", "B", "H"], rid, settle=1, timeout=30)
    C.check("db/revert undoes it: the file gone and nothing listed",
            not os.path.exists(r.path("B", rid, "local-only.txt"))
            and not (r.localchanged("B", rid) or {}).get("files"), r.localchanged("B", rid))

    # the direct link (ws-16): A and B paired as well, a folder shared both ways and through H
    r.pair("A", "B")
    r.pair("B", "A")
    r.wait_connected([("A", "B")])
    did = r.share("smoke-direct-" + secrets.token_hex(3), direct=True)
    with open(r.path("A", did, "direct.txt"), "w") as f:
        f.write("over the direct link\n")
    tw = time.time()
    while not os.path.exists(r.path("B", did, "direct.txt")) and time.time() - tw < 30:
        time.sleep(0.05)
    C.check("the direct link: A and B connected, a file from A reaches B",
            r.connected("B", "A") and os.path.exists(r.path("B", did, "direct.txt")))
    C.note("arrival A -> B with the direct link: %.2f s after the write" % (time.time() - tw))
    r.wait_idle(["A", "B", "H"], did, settle=1)
    C.check("the direct link: every view of the hub still 100 with nothing needed", r.views_clear(r.views(did)),
            r.views(did))

    hub_files = r.files("H", fid)
    names = [os.path.basename(n) for n in marks] + ["plainsub"]
    leaks = [p for p in r.manifest("H", fid) if any(x in p for x in names)]
    blobs = []
    for p in hub_files:
        with open(r.path("H", fid, p), "rb") as f:
            b = f.read()
        blobs += [p for text in marks.values() if text.strip().split()[-1].encode() in b]
    C.check("the hub holds the two files (%d files under its copy)" % len(hub_files),
            len(hub_files) >= 2, hub_files)
    C.check("no plaintext name under the hub's copy", not leaks, leaks)
    C.check("no plaintext content under the hub's copy", not blobs, blobs)

    pids = r.pids()
    C.check("the rig runs a monitor and a child per instance (%d processes)" % len(pids), len(pids) >= 3, pids)
    r.stop()
    C.check("all three stopped, no process of the rig left", not r.pids(), r.pids())
    return C


if __name__ == "__main__":
    main(sys.argv[1]).exit()
