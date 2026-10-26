#!/usr/bin/env python3
"""Case 5, hub-1: the hub keeps every deletion record.

The hub collects deletion records at each database maintenance pass, and on
an encrypted folder every record's modification time is fixed in 2009, so
the default retention (10920h on 2.1.6) never protects one: a workstation
away across a pass never receives the deletion, and no view shows it
(rules.md hub-1; phase2/live-t2-hubfix.md, T2 on the real hub, 2026-10-09).
STDBDELETERETENTIONINTERVAL=0 keeps every record.

One half per run, on fresh instances, the rig hub started with
STDBMAINTENANCEINTERVAL=1m (and STTRACE=db/sqlite, whose trace lines are the
only sign of a pass the hub gives). In each, B pauses its hub device, and
during the pause A deletes x.txt and changes y.txt; the change is the
control, read after B resumes, so whatever B lacks is read against
something that did arrive.

    lost   the default retention. Decided on REST facts alone: the hub's
           db/status shows the record held, then gone (globalDeleted 0)
           within the bound; B resumes: y.txt's change arrives, x.txt stays,
           and every view reads 100 with nothing needed -- the deletion is
           lost, and silently. A record still held at the bound is a FAIL,
           and B's reading is then taken and shown all the same. The trace's
           passes are a note.
    kept   STDBDELETERETENTIONINTERVAL=0. Here nothing in REST changes at a
           pass, so the half needs the trace's sign of one: B resumes after a
           pass seen in the trace, the record still held, and B deletes the
           file. No pass seen within the bound is a FAIL: the half could not
           decide, and that is never a pass.

The first pass comes one minute after the hub starts, then every interval
(measured, 2.1.6: "Next periodic run due (after=1m0s)" at start whatever the
interval), so a half takes about a minute and a half; each waits at most
BOUND seconds from the deletion for its pass. A Syncthing whose trace text
changes turns the kept half red, never green.

Syncthing 2.1.7 fixes the fault upstream (rules.md hub-1, PR #10916); on it
the `lost` half's checks fail by design, and that FAIL says the fix has
arrived: the half is then revised to assert delivery, and the drop-in stays.

    python3 -I case_retention.py ROOT lost|kept
"""
import os
import re
import secrets
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402

BOUND = 170          # seconds from the deletion to the resume, at most
PASS_RE = re.compile(r"Periodic done")


def passes_since(log, offset):
    """(count, new offset) of maintenance passes the trace logged after `offset`."""
    with open(log, "rb") as f:
        f.seek(offset)
        text = f.read().decode("utf-8", "replace")
        return len(PASS_RE.findall(text)), offset + len(text.encode("utf-8"))


def main(root, mode):
    C = rig.Checks()
    if mode not in ("lost", "kept"):
        print("usage: case_retention.py ROOT lost|kept", file=sys.stderr)
        sys.exit(2)
    t_case = time.time()
    hub_env = {"STDBMAINTENANCEINTERVAL": "1m", "STTRACE": "db/sqlite"}
    if mode == "kept":
        hub_env["STDBDELETERETENTIONINTERVAL"] = "0"
    tag = "hub-1 %s (%s)" % (mode, "retention 0" if mode == "kept" else "default retention")
    r = rig.Rig(root)
    r.trio(hub_env=hub_env)
    fid = "ret-%s-%s" % (mode, secrets.token_hex(3))
    r.share(fid)
    for name in ("x.txt", "y.txt"):
        with open(r.path("A", fid, name), "w") as f:
            f.write("%s written on A\n" % name)
    r.wait_idle(["A", "B", "H"], fid, settle=2)
    C.check("%s: x.txt reached B" % tag, os.path.exists(r.path("B", fid, "x.txt")))

    r.pause_device("B", "H")
    t0 = time.time()
    while r.connected("H", "B") and time.time() - t0 < 30:
        time.sleep(0.2)
    C.note("%s [%s] B paused its hub device (H sees B connected: %s)" % (tag, rig.stamp(), r.connected("H", "B")))
    _, off = passes_since(r["H"].log, 0)
    os.remove(r.path("A", fid, "x.txt"))
    t_del = time.time()
    with open(r.path("A", fid, "y.txt"), "a") as f:
        f.write("y.txt changed on A during B's pause\n")
    y_want = rig.sha256_file(r.path("A", fid, "y.txt"))
    C.note("%s [%s] A deleted x.txt and changed y.txt (the control)" % (tag, rig.stamp()))
    r.wait_idle(["A", "H"], fid, settle=1, timeout=30)
    h = r.status("H", fid)
    C.check("%s: the hub holds the deletion record after it arrives (globalDeleted %s)" % (tag, h.get("globalDeleted")),
            h.get("globalDeleted", 0) >= 1, {k: h.get(k) for k in ("globalFiles", "globalDeleted", "localDeleted")})

    # the lost half waits for the hub's record to go (REST), the kept half for a
    # pass in the trace; both at most BOUND s from the deletion
    seen, gone_at = 0, None
    while time.time() - t_del < BOUND:
        n, off = passes_since(r["H"].log, off)
        seen += n
        h = r.status("H", fid)
        if gone_at is None and not h.get("globalDeleted"):
            gone_at = time.time()
            C.note("%s [%s] the hub's record is gone: globalDeleted %s, globalFiles %s"
                   % (tag, rig.stamp(), h.get("globalDeleted"), h.get("globalFiles")))
        if (mode == "lost" and gone_at is not None) or (mode == "kept" and seen):
            break
        time.sleep(1)
    n, off = passes_since(r["H"].log, off)
    seen += n
    h = r.status("H", fid)
    held = {k: h.get(k) for k in ("globalFiles", "globalDeleted", "localDeleted")}
    C.note("%s [%s] %.0f s after the deletion: hub %s; passes in the trace: %d (a note: the trace is"
           " debug text)" % (tag, rig.stamp(), time.time() - t_del, held, seen))
    if mode == "lost":
        C.check("%s: the hub's deletion record is gone within %d s (db/status globalDeleted 0)" % (tag, BOUND),
                gone_at is not None and not h.get("globalDeleted"), held)
    else:
        if not C.check("%s: a maintenance pass seen in the hub's trace within %d s of the deletion" % (tag, BOUND),
                       seen > 0, "no line matching %r in %s: the half cannot tell a kept record from a pass"
                       " that never ran, so it decides nothing" % (PASS_RE.pattern, r["H"].log)):
            r.stop()
            return C
        time.sleep(2)
        h = r.status("H", fid)
        C.check("%s: the pass kept the hub's deletion record" % tag, h.get("globalDeleted", 0) >= 1,
                {k: h.get(k) for k in ("globalFiles", "globalDeleted", "localDeleted")})

    r.resume_device("B", "H")
    r.wait_connected([("B", "H")])
    t_res = time.time()
    C.note("%s [%s] B resumed and reconnected" % (tag, rig.stamp()))
    y = r.path("B", fid, "y.txt")
    while time.time() - t_res < 30:
        if os.path.exists(y) and rig.sha256_file(y) == y_want:
            break
        time.sleep(0.2)
    C.check("%s: control: y.txt's change made during the pause reached B after the resume" % tag,
            os.path.exists(y) and rig.sha256_file(y) == y_want)
    C.note("%s: the control arrived %.1f s after the resume" % (tag, time.time() - t_res))
    if mode == "kept":
        while os.path.exists(r.path("B", fid, "x.txt")) and time.time() - t_res < 30:
            time.sleep(0.2)
        r.wait_idle(["A", "B", "H"], fid, settle=3, timeout=60, raise_on_timeout=False)
        C.check("%s: B received the deletion (x.txt gone from B's disk)" % tag,
                not os.path.exists(r.path("B", fid, "x.txt")))
        C.note("%s: deletion applied on B %.1f s after the resume" % (tag, time.time() - t_res))
        v = r.views(fid)
        C.check("%s: every view 100 with nothing needed" % tag, r.views_clear(v), v)
    else:
        r.wait_idle(["A", "B", "H"], fid, settle=3, timeout=60, raise_on_timeout=False)
        time.sleep(15)        # past the index exchange, so a late arrival would show
        r.wait_idle(["A", "B", "H"], fid, settle=3, timeout=60, raise_on_timeout=False)
        C.check("%s: the deletion never reached B (x.txt still on B's disk)" % tag,
                os.path.exists(r.path("B", fid, "x.txt")))
        v = r.views(fid)
        C.check("%s: and every view reads 100 with nothing needed: the loss is silent" % tag, r.views_clear(v), v)
        sb = r.status("B", fid)
        C.note("%s: B globalFiles %s, A globalFiles %s, hub globalFiles %s" % (
            tag, sb.get("globalFiles"), r.status("A", fid).get("globalFiles"), r.status("H", fid).get("globalFiles")))
    C.note("%s: half took %.0f s" % (tag, time.time() - t_case))
    r.stop()
    return C


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "").exit()
