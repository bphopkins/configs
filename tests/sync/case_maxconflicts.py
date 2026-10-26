#!/usr/bin/env python3
"""Case 3, ws-7: conflicts keep their copies.

A folder made through POST /rest/config/folders with no maxConflicts in the
body reads maxConflicts 10 on every instance -- the writer, the reader (as
sendreceive, and as receiveonly, its type in the seeding window), and the
receive-encrypted hub -- read back from config/folders/<id> structurally,
the password field never shown. A control proves the read-back is real: a
POST that names maxConflicts 0 reads 0. And a reading, printed rather than
asserted: what `syncthing cli config folders add` gives, the route ws-7
forbids.

    python3 -I case_maxconflicts.py ROOT
"""
import json
import os
import secrets
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402


def main(root):
    C = rig.Checks()
    r = rig.Rig(root)
    r.trio()
    for label, types in (("sendreceive on both workstations", {}), ("B receiveonly", {"B": "receiveonly"})):
        fid = r.share("ws7-" + secrets.token_hex(3), types=types)
        for n in ("A", "B", "H"):
            f = r.folder_config(n, fid)
            C.check("%s: %s's folder (%s) reads maxConflicts 10" % (label, n, f.get("type")),
                    f.get("maxConflicts") == 10, {k: f.get(k) for k in ("id", "type", "maxConflicts")})
            blob = json.dumps(f)
            C.check("%s: %s's read-back carries no password field" % (label, n),
                    "encryptionPassword" not in blob and r.password not in blob)
    fid = "ws7-zero-" + secrets.token_hex(3)
    r.add_folder("A", fid, [], maxConflicts=0)
    C.check("control: a POST naming maxConflicts 0 reads 0", r.folder_config("A", fid).get("maxConflicts") == 0)

    fid = "ws7-cli-" + secrets.token_hex(3)
    p = r.path("A", fid)
    os.makedirs(p)
    cli = subprocess.run([rig.SYNCTHING, "cli", "--home=" + r["A"].st_home, "config", "folders", "add",
                          "--id", fid, "--path", p], capture_output=True, text=True, env=r["A"].clean_env())
    if cli.returncode == 0:
        C.note("reading: `syncthing cli config folders add` with no --max-conflicts gives maxConflicts %s"
               % r.folder_config("A", fid).get("maxConflicts"))
    else:
        C.note("reading: `syncthing cli config folders add` failed (rc %d): %s" % (cli.returncode, cli.stderr.strip()[:200]))
    r.stop()
    return C


if __name__ == "__main__":
    main(sys.argv[1]).exit()
