#!/usr/bin/env python3
"""Case 2, fedxps-3 on a real reader: the guard's two checks.

A git repository written on A (the writer) reaches B (the reader) through H,
in a subdirectory of the folder as each repository is of ~/Desktop after the
cutover.
(a) On B, under the reader guard -- rules.md fedxps-1's host file
(core.checkStat=minimal, core.trustctime=false, diff.autoRefreshIndex=false,
gc.auto=0, maintenance.auto=false) and GIT_OPTIONAL_LOCKS=0 -- a `touch` of a
tracked file, then `git status` and `git diff`, write nothing under .git: B's
events/disk carry no LocalChangeDetected under .git (the touch itself is
seen, the control that the events are being kept), and every .git path's
version vector (db/file -> global.version) carries A's counter alone.
(b) With git's defaults and no variable, the same `git status` rewrites
.git/index: B's disk events show it, and once the folder settles the index's
vector carries B's counter and A's copy of the index is B's version.

These are the REST facts the gauge's guard line rests on (the disk events,
and since the 2026-10-25 revision the vector, pilot/verdict.md -> D5); the
case asserts the facts, not the gauge's text.

    python3 -I case_guard.py ROOT
"""
import os
import secrets
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402

REPO = "repo"       # a subdirectory of the folder, as each repository is of ~/Desktop after the cutover
GIT = REPO + "/.git"


def git_paths(r, n, fid):
    """Every path under the repository's .git in n's copy (files and directories)."""
    return [p for p in r.manifest(n, fid, GIT)]


def main(root):
    C = rig.Checks()
    r = rig.Rig(root)
    r.trio()
    fid = r.share("guard-" + secrets.token_hex(3))
    W = rig.git_env(rig.write_gitconfig(os.path.join(root, "gitconfig-writer")), home=r["A"].home)
    G = rig.git_env(rig.write_gitconfig(os.path.join(root, "gitconfig-reader"), rig.READER_GUARD),
                    optional_locks=0, home=r["B"].home)
    D = rig.git_env(rig.write_gitconfig(os.path.join(root, "gitconfig-defaults")), home=r["B"].home)
    A_dir, B_dir = r.path("A", fid, REPO), r.path("B", fid, REPO)
    a_id, b_id = r["A"].short_id, r["B"].short_id

    t0 = time.time()
    rig.seed_repo(A_dir, W)
    rig.git(A_dir, ["status", "--porcelain"], W)        # the writer's own index, as on bigfed
    r.wait_idle(["A", "B", "H"], fid, settle=2)
    C.note("the seed (%d paths under .git) reached B and settled in %.1f s"
           % (len(git_paths(r, "A", fid)), time.time() - t0))
    C.check("B's copy is byte-identical to A's", r.manifest("A", fid) == r.manifest("B", fid),
            r.manifest_diff(r.manifest("A", fid), r.manifest("B", fid)))
    C.check("B's guarded git reads the repository (HEAD resolves, fsck clean)",
            rig.git(B_dir, ["fsck", "--no-progress", "--no-dangling"], G).returncode == 0
            and rig.git(B_dir, ["rev-parse", "HEAD"], G).returncode == 0)

    def vectors(paths):
        return {p: r.vector_devices("B", fid, p) for p in paths}

    base = vectors(git_paths(r, "B", fid))
    C.check("after the seed every .git path's vector carries A's counter alone (%d paths)" % len(base),
            base and all(v == [a_id] for v in base.values()),
            {p: v for p, v in base.items() if v != [a_id]})

    # --- (a) guarded ----------------------------------------------------------------
    mark = r.last_disk_event("B")
    before = r.manifest("B", fid, GIT)
    st_idx = os.stat(os.path.join(B_dir, ".git", "index"))
    os.utime(os.path.join(B_dir, "README.md"))           # touch a tracked file
    s = rig.git(B_dir, ["status"], G)
    d = rig.git(B_dir, ["diff"], G)
    C.check("(a) guarded `git status` and `git diff` ran (rc 0, 0)", s.returncode == 0 and d.returncode == 0,
            (s.returncode, s.stderr[:200], d.returncode, d.stderr[:200]))
    C.note("(a) guarded status reads: %s" % (rig.git(B_dir, ["status", "--porcelain"], G).stdout.strip() or "clean"))
    r.wait_idle(["A", "B", "H"], fid, settle=2)
    after = r.manifest("B", fid, GIT)
    st_idx2 = os.stat(os.path.join(B_dir, ".git", "index"))
    C.check("(a) nothing under B's .git changed on disk (content), the index's inode and mtime kept",
            before == after and (st_idx.st_ino, st_idx.st_mtime_ns) == (st_idx2.st_ino, st_idx2.st_mtime_ns),
            r.manifest_diff(before, after))
    lc = r.local_changes("B", fid, since=mark)
    C.check("(a) control: B's events/disk recorded the touch of README.md as a local change",
            any(p == REPO + "/README.md" for _, _, _, p in lc), lc)
    gitlc = [e for e in lc if e[3] == GIT or e[3].startswith(GIT + "/")]
    C.check("(a) B's events/disk: no LocalChangeDetected under .git", not gitlc, gitlc)
    va = vectors(git_paths(r, "B", fid))
    C.check("(a) every .git path's vector still carries A's counter alone (%d paths)" % len(va),
            va and all(v == [a_id] for v in va.values()), {p: v for p, v in va.items() if v != [a_id]})
    readme = r.vector_devices("B", fid, REPO + "/README.md")
    C.check("(a) control: the touched README.md's vector carries B's counter", b_id in (readme or []), readme)

    # --- (b) unguarded --------------------------------------------------------------
    mark = r.last_disk_event("B")
    s = rig.git(B_dir, ["status"], D)
    C.check("(b) unguarded `git status` ran (rc 0)", s.returncode == 0, s.stderr[:200])
    t1 = time.time()
    r.wait_idle(["A", "B", "H"], fid, settle=2)
    C.note("(b) settled %.1f s after the unguarded status" % (time.time() - t1))
    lc = r.local_changes("B", fid, since=mark, under=GIT)
    C.check("(b) B's events/disk show .git/index written by B", any(p == GIT + "/index" for _, _, _, p in lc), lc)
    C.note("(b) the unguarded status's writes under .git: %s" % sorted(set(p for _, _, _, p in lc)))
    vb = r.vector_devices("B", fid, GIT + "/index")
    C.check("(b) the index's vector on B carries B's counter", b_id in (vb or []), vb)
    va_idx = r.vector_devices("A", fid, GIT + "/index")
    C.check("(b) the index's vector on A carries B's counter (A took B's version)", b_id in (va_idx or []), va_idx)
    ha = rig.sha256_file(os.path.join(A_dir, ".git", "index"))
    hb = rig.sha256_file(os.path.join(B_dir, ".git", "index"))
    C.check("(b) A's copy of .git/index is byte-identical to B's", ha == hb, (ha[:12], hb[:12]))
    C.check("(b) A's git still reads its repository (fsck clean)",
            rig.git(A_dir, ["fsck", "--no-progress", "--no-dangling"], W).returncode == 0)
    others = {p: v for p, v in vectors(git_paths(r, "B", fid)).items() if v != [a_id] and p != GIT + "/index"}
    C.note("(b) other .git paths now carrying B's counter: %s" % (others or "none"))
    r.stop()
    return C


if __name__ == "__main__":
    main(sys.argv[1]).exit()
