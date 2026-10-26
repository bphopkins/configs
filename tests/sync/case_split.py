#!/usr/bin/env python3
"""Case 4, the split of main and its repair (rules.md him-2's last case,
bigfed-2; the r-git-cases attack's "silent split of main", RGC_REV=1
conflicts.py both).

A writes a repository (a subdirectory of the folder, as each repository is of
~/Desktop after the cutover) and B's copy arrives through H, as after a
seeding; A runs `git gc`, so the ref file B will write is one A deleted and
both recreate; settle. Then the forbidden write: B commits to its copy with git's
defaults, and A commits to the same .git 0.3 s later. Settle, and record what
each machine's .git holds (HEAD, phantom branches, conflict copies), what
each workstation lists towards the hub (db/remoteneed for H), the hub's
completion of each, and whether the HEADs differ (the push gauge's
refusal). him-2's prediction, reasoned from the hub's counter rule and never
run: no phantom and no conflict copy; A's commit-time files stranded on A,
listed by A's view of the hub; B reading clear.

Then the repair as him-2 writes it. On B, `touch` exactly the .git paths A's
view lists towards the hub (the reader's one sanctioned write); settle; on A
the phantom branch appears: once the folder has been quiet 15 s and
`git fsck --connectivity-only` passes, rename the phantom to a name without
sync-conflict, commit the working tree (which holds both edits; `git merge`
refuses), reusing the phantom commit's message so its subject survives;
after the next settle delete the inert copies under .git; delete the renamed
branch once its edit is in HEAD; settle. Asserted at the end: both .git trees
(and both whole trees) byte-identical, `git fsck` clean on both, every view
100 with nothing needed, no conflict copy left, both commits' subjects
reachable on both.

Each step is printed with its wall-clock time, so a run that departs from
him-2's text is a record of what happened instead. Runs RUNS times (argv[2],
default 3), each on fresh instances: the hub's ordering is the variable.

    python3 -I case_split.py ROOT [RUNS]
"""
import os
import secrets
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402

NODES = ["A", "B", "H"]
REPO = "repo"       # a subdirectory of the folder, as each repository is of ~/Desktop after the cutover
GIT = REPO + "/.git"
GAP = 0.3
QUIET = 15          # him-2: the folder quiet 15 s before the phantom repair


def run_once(k, root, C):
    t_run = time.time()
    r = rig.Rig(os.path.join(root, "run%d" % k))
    r.trio()
    fid = "split-%d-%s" % (k, secrets.token_hex(3))
    r.share(fid)
    A_dir, B_dir = r.path("A", fid, REPO), r.path("B", fid, REPO)
    a_id, b_id = r["A"].short_id, r["B"].short_id
    W = rig.git_env(rig.write_gitconfig(os.path.join(r.root, "gitconfig-writer")), home=r["A"].home)
    D = rig.git_env(rig.write_gitconfig(os.path.join(r.root, "gitconfig-defaults")), home=r["B"].home)
    guard = rig.write_gitconfig(os.path.join(r.root, "gitconfig-reader"), rig.READER_GUARD)
    RA = rig.git_env(guard, optional_locks=0, home=r["A"].home)    # records read, never write
    RB = rig.git_env(guard, optional_locks=0, home=r["B"].home)
    cwd = {"A": A_dir, "B": B_dir}
    rd = {"A": RA, "B": RB}

    def say(text):
        C.note("run %d [%s] %s" % (k, rig.stamp(), text))

    def settle(s=5, timeout=120):
        t = r.wait_idle(NODES, fid, settle=s, timeout=timeout, raise_on_timeout=False)
        if t is None:
            say("did NOT settle within %ds: %s" % (timeout, {n: (r.status(n, fid).get("state"),
                                                                 r.status(n, fid).get("needTotalItems"))
                                                             for n in NODES}))
        return t

    def head(n):
        g = rig.git(cwd[n], ["log", "-1", "--format=%h %s"], rd[n])
        return g.stdout.strip() or ("(no HEAD: %s)" % g.stderr.strip()[:80])

    def phantoms(n):
        g = rig.git(cwd[n], ["for-each-ref", "--format=%(refname)", "refs/"], rd[n])
        return [x for x in g.stdout.split() if "sync-conflict" in x]

    def subjects(n):
        return set(rig.git(cwd[n], ["log", "--all", "--format=%s"], rd[n]).stdout.splitlines())

    def gitcopies(n):
        return [p for p in r.conflict_copies(n, fid) if p.startswith(GIT + "/")]

    def record(tag):
        v = r.views(fid)
        out = {"views": {key: (x["completion"], x["needItems"], x["needDeletes"]) for key, x in v.items()},
               "A->H lists": r.remoteneed_names("A", fid, "H"), "B->H lists": r.remoteneed_names("B", fid, "H")}
        for n in ("A", "B"):
            st = rig.git(cwd[n], ["status", "--porcelain"], rd[n]).stdout.split("\n")
            out[n] = {"HEAD": head(n), "phantoms": phantoms(n), "copies": r.conflict_copies(n, fid),
                      "status": [x for x in st if x and "sync-conflict" not in x]}
        say("%s:" % tag)
        for n in ("A", "B"):
            say("  %s: HEAD %s; phantom refs %s; status %s" % (n, out[n]["HEAD"], out[n]["phantoms"], out[n]["status"]))
            say("  %s: conflict copies %s" % (n, out[n]["copies"]))
        say("  views (completion, needItems, needDeletes): %s" % out["views"])
        say("  A lists towards the hub: %s" % out["A->H lists"])
        say("  B lists towards the hub: %s" % out["B->H lists"])
        return out

    def vectors(paths):
        for p in paths:
            say("  vector %s: A local %s global %s | B local %s global %s" % (
                p, r.vector("A", fid, p, "local"), r.vector("A", fid, p), r.vector("B", fid, p, "local"),
                r.vector("B", fid, p)))

    # --- seed through the hub, then a gc on A --------------------------------------------
    rig.seed_repo(A_dir, W)
    rig.git(A_dir, ["status", "--porcelain"], W)        # the writer's own index, as on bigfed
    settle(3)
    say("seeded from A; B's copy arrived through H (%d paths)" % len(r.manifest("B", fid)))
    g = rig.git(A_dir, ["gc", "-q"], W)
    say("git gc on A: rc %d; refs/heads/main loose on A: %s" % (
        g.returncode, os.path.exists(os.path.join(A_dir, ".git/refs/heads/main"))))
    settle(3)
    same = r.manifest("A", fid) == r.manifest("B", fid)
    say("after the gc settled: trees identical %s; packed-refs on B %s; refs/heads/main on B %s" % (
        same, os.path.exists(os.path.join(B_dir, ".git/packed-refs")),
        os.path.exists(os.path.join(B_dir, ".git/refs/heads/main"))))
    if not same:
        C.check("run %d: the seed and the gc reached B byte-identical" % k, False,
                r.manifest_diff(r.manifest("A", fid), r.manifest("B", fid)))
        r.stop()
        return

    # --- the forbidden write, then A's commit GAP s later -----------------------------------
    done = {}

    def commit(n, file, line, subject, env):
        with open(os.path.join(cwd[n], file), "a") as f:
            f.write(line)
        g = rig.git(cwd[n], ["commit", "-qam", subject], env)
        done[n] = (rig.stamp(), g.returncode, g.stderr.strip()[:120])

    tb = threading.Thread(target=commit, args=("B", "LICENSE", "edit made on B\n", "split: on B", D))
    ta = threading.Thread(target=commit, args=("A", "README.md", "edit made on A\n", "split: on A", W))
    tb.start()
    time.sleep(GAP)
    ta.start()
    tb.join()
    ta.join()
    say("B committed (unguarded) at %s rc %d; A committed %.1f s after B's start, at %s rc %d"
        % (done["B"][0], done["B"][1], GAP, done["A"][0], done["A"][1]))
    t = settle(5)
    say("settled after the commits in %ss" % t)
    split = record("after the commits")
    gitlist = [p for p in split["A->H lists"] if p.startswith(GIT + "/")]
    vectors([p for p in gitlist if not os.path.isdir(r.path("A", fid, p))][:6])
    heads_differ = split["A"]["HEAD"] != split["B"]["HEAD"]
    say("HEADs differ (the push gauge's refusal): %s" % heads_differ)

    C.check("run %d: the split as him-2 reasons it: HEADs differ" % k, heads_differ,
            (split["A"]["HEAD"], split["B"]["HEAD"]))
    C.check("run %d: no phantom branch and no conflict copy on either machine" % k,
            not (split["A"]["phantoms"] or split["B"]["phantoms"] or split["A"]["copies"] or split["B"]["copies"]),
            {n: (split[n]["phantoms"], split[n]["copies"]) for n in ("A", "B")})
    C.check("run %d: A's view lists .git paths towards the hub (stranded on A)" % k, bool(gitlist),
            split["A->H lists"])
    C.check("run %d: B lists nothing towards the hub, and B's and the hub's views of B read clear" % k,
            not split["B->H lists"] and split["views"]["B->H"] == (100, 0, 0) and split["views"]["H->B"] == (100, 0, 0),
            split["views"])

    # --- the sanctioned reader write: touch on B what A lists --------------------------------
    touched, missing = [], []
    for p in gitlist:
        q = r.path("B", fid, p)
        if os.path.lexists(q):
            os.utime(q)
            touched.append(p)
        else:
            missing.append(p)
    say("touched on B: %s; listed but absent on B: %s" % (touched, missing))
    t = settle(5)
    say("settled after the touch in %ss" % t)
    after_touch = record("after the touch")
    phantom = after_touch["A"]["phantoms"]
    C.check("run %d: after the touch the phantom branch appears on A" % k, bool(phantom), after_touch["A"])
    if not phantom:
        say("no phantom on A: the repair as written cannot continue; state left as recorded")
        r.stop()
        return

    # --- the phantom repair on A -------------------------------------------------------------
    t = settle(QUIET)
    say("quiet %ds (waited %ss)" % (QUIET, t))
    fsck = rig.git(A_dir, ["fsck", "--connectivity-only", "--no-progress"], W)
    say("fsck --connectivity-only on A: rc %d %s" % (fsck.returncode, fsck.stderr.strip()[:200]))
    ph = phantom[0][len("refs/heads/"):]
    rescue = "rescue-split-%d" % k
    mv = rig.git(A_dir, ["branch", "-m", ph, rescue], W)
    say("git branch -m %s %s: rc %d %s" % (ph, rescue, mv.returncode, mv.stderr.strip()[:200]))
    mg = rig.git(A_dir, ["merge", "--no-edit", rescue], W)
    say("(git merge %s, for the record: rc %d, %s)" % (rescue, mg.returncode,
                                                       (mg.stderr.strip() or mg.stdout.strip()).splitlines()[:1]))
    ci = rig.git(A_dir, ["commit", "-qa", "-C", rescue], W)
    say("git commit -a -C %s on A: rc %d %s; HEAD now %s" % (rescue, ci.returncode, ci.stderr.strip()[:200], head("A")))
    settle(5)
    copies = gitcopies("A")
    for p in copies:
        os.remove(r.path("A", fid, p))
    say("deleted on A the inert copies under .git: %s" % copies)
    settle(5)
    left = rig.git(A_dir, ["diff", "--name-only", rescue, "HEAD"], W).stdout.split()
    in_head = left == ["LICENSE"]
    say("files differing between %s and HEAD: %s (its edit in HEAD: %s)" % (rescue, left, in_head))
    if in_head:
        rig.git(A_dir, ["branch", "-D", rescue], W)
        say("deleted the branch %s" % rescue)
    settle(5)
    final = record("after the repair")

    # --- the end state ---------------------------------------------------------------------------
    ma, mb = r.manifest("A", fid, GIT), r.manifest("B", fid, GIT)
    C.check("run %d: both .git trees byte-identical (%d paths)" % (k, len(ma)), ma == mb, r.manifest_diff(ma, mb))
    C.check("run %d: both whole trees byte-identical" % k, r.manifest("A", fid) == r.manifest("B", fid),
            r.manifest_diff(r.manifest("A", fid), r.manifest("B", fid)))
    for n in ("A", "B"):
        f = rig.git(cwd[n], ["fsck", "--no-progress", "--no-dangling"], rd[n])
        C.check("run %d: git fsck clean on %s" % (k, n), f.returncode == 0, f.stderr[:300])
    v = r.views(fid)
    C.check("run %d: every view 100 with nothing needed" % k, r.views_clear(v), v)
    C.check("run %d: no conflict copy and no phantom left" % k,
            not (final["A"]["copies"] or final["B"]["copies"] or final["A"]["phantoms"] or final["B"]["phantoms"]),
            {n: (final[n]["copies"], final[n]["phantoms"]) for n in ("A", "B")})
    C.check("run %d: HEAD equal on both" % k, final["A"]["HEAD"] == final["B"]["HEAD"],
            (final["A"]["HEAD"], final["B"]["HEAD"]))
    for n in ("A", "B"):
        s = subjects(n)
        C.check("run %d: both commits' subjects reachable on %s" % (k, n),
                {"split: on A", "split: on B"} <= s, sorted(x for x in s if x.startswith("split")))
    C.check("run %d: B's working tree clean under the guard" % k, not final["B"]["status"], final["B"]["status"])
    say("run took %.0f s" % (time.time() - t_run))
    r.stop()


def main(root, runs=3):
    C = rig.Checks()
    for k in range(1, runs + 1):
        try:
            run_once(k, root, C)
        except rig.RigError as e:
            C.check("run %d ran to its end" % k, False, e)
    return C


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 3).exit()
