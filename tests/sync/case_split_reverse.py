#!/usr/bin/env python3
"""Case split-reverse, the split of main in the reverse order (rules.md him-2's
last case, bigfed-2), beside case_split.py, which runs the covered order: B,
the reader, commits unguarded first and A, the writer, 0.3 s later.

Here A writes a repository in the folder and B's copy arrives through H, as
after a seeding; then A commits first and B commits to the same .git with
git's defaults 0.3 s after, through the hub with no direct link, as in
case_split. Variants, each run on fresh instances:
  gc       A runs `git gc` before the commits and the folder settles, as in
           case_split: refs/heads/main is a file A deleted and both recreate,
           and the commits freshen the pack
  nogc     no gc: loose refs and loose objects
  forward  case_split's covered order (B first, A 0.3 s later, after a gc),
           run here only for the push-line readings below, which case_split
           does not take; not in run.sh's default
What it asserts, as the hub's counter rule and the workstations' rule predict
(rules.md him-2, 2026-10-25 and 2026-10-26; Syncthing 2.1.6: an untrusted
device is handed one counter, the sum of the real ones, lib/protocol/
encryption.go; between concurrent versions the newer modification time wins,
lib/protocol/bep_fileinfo.go WinsConflict): every path both commits write
carries A's counter alone in A's version and A's and B's in B's, so the hub
keeps B's whatever the order, and in the reverse order B's is also the newer,
so the workstations keep it too. The two rules agree, so nothing strands: A
moves its own version aside as a conflict copy named after B, the winner's
modifier, and the phantom branch refs/heads/main.sync-conflict-...-<B> appears
on A with no touch, holding A's commit, and reaches B as new files; HEAD is
B's commit on both; a path whose versions differ in metadata alone (a
freshened pack or loose object) takes B's with no copy. The repair is him-2's
phantom case on A alone, with no write on B. Asserted at the end, as in
case_split: both .git trees (and both whole trees) byte-identical, `git fsck`
clean on both, every view 100 with nothing needed, no conflict copy left, both
commits' subjects reachable on both; then once more after a `git gc` on A,
bigfed's routine maintenance. If a run strands instead, B touches exactly the
.git paths listed towards the hub (him-2's one sanctioned reader write) and
the phantom repair follows; the run records what happened. After the
repair, step (d), as in case_split.py: a path A deleted in it that the hub
refused, since it held B's concurrent modification of the path and a
modification beats a deletion, is touched on B, comes back to A and is
deleted there again, with its own `# ` line, and a check asserts nothing stays
stranded under .git. Measured once in eight variant runs on 2026-10-27, the
gc variant on fedxps: the renamed branch's ref and reflog, deleted by `git
branch -D`, refused at the hub and kept by B. The race is a tie at the hub,
so it is recorded when it recurs, never forced.

Read beside it: bin/sync-check's push line (bigfed-2), run as A against the
rig after the commits, after the repair and after the gc, with a stub ssh that
runs its remote reads in H's and B's sandboxes (nousowl and fedxps; the device
names are the hosts) and a stub uname naming each machine, as case_addfolder's
stub does for its tool. The gauge runs with HOME at each instance's own
directory, so a folder path written with ~ reads each machine's own copy. Its
lines are shown as `# ... | ` readings; the checks are on which refusal it
gives and which machine its fix names: in the reverse order the phantom and
its copies, with the repair here and no touch asked of fedxps; in the covered
order the needed .git paths and the differing HEAD, with the touch on fedxps.
What it reads after the repair, and after the gc that follows, is shown as a
reading: its vector check (fedxps-3's durable form on the writer's side) names
every .git path whose version carries B's counter, and a counter stays in a
path's vector for good: on 2.1.6 it still FAILs after the repair in both
orders, and after the gc on the four files no gc removes (COMMIT_EDITMSG,
index, logs/HEAD, logs/refs/heads/main), until KNOWN_WRITES carries them
(measured 2026-10-26).

Each step is printed with its wall-clock time. Runs RUNS times per variant
(argv[2], default 1: the two rules fix the outcome, and three runs of each
reverse variant did not vary, 2026-10-26), each on fresh instances, about
70 s a run in the reverse order and 110 s forward; VARIANTS is a comma list
(argv[3], default gc,nogc).

    python3 -I case_split_reverse.py ROOT [RUNS] [VARIANTS]
"""
import os
import secrets
import shlex
import subprocess
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402

NODES = ["A", "B", "H"]
NAMES = {"A": "bigfed", "B": "fedxps", "H": "nousowl"}   # the device names are the gauge's ssh hosts
REPO = "repo"       # a subdirectory of the folder, as each repository is of ~/Desktop after the cutover
GIT = REPO + "/.git"
GAP = 0.3
QUIET = 15          # him-2: the folder quiet 15 s before the phantom repair
GAUGE = os.path.realpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "bin", "sync-check"))
VARIANTS = ("gc", "nogc", "forward")

STUB_SSH = r"""#!/usr/bin/env bash
# stub ssh for case_split_reverse: the command words run in the sandbox of the
# instance the host names, with its HOME, config.xml and git config; any other
# host answers ssh's own 255; every call is logged
printf '%s\n' "$*" >> "$STUB_DIR/ssh-argv.log"
host=""
while [ $# -gt 0 ]; do
  case "$1" in -o|-p|-i|-l|-F) shift 2 ;; -*) shift ;; *) host=$1; shift; break ;; esac
done
printf '%s\n' "$host" >> "$STUB_DIR/ssh.log"
d="$STUB_DIR/hosts/$host"
[ -f "$d/env" ] || { echo "ssh: Could not resolve hostname $host: Name or service not known" >&2; exit 255; }
. "$d/env"
exec bash -c "$*"
"""
STUB_UNAME = "#!/bin/sh\n# stub uname for case_split_reverse: the machine the gauge plays\necho \"${RIG_UNAME:-rig}\"\n"


def run_once(k, variant, root, C):
    t_run = time.time()
    order = "forward" if variant == "forward" else "reverse"
    do_gc = variant != "nogc"
    r = rig.Rig(os.path.join(root, "run%d" % k))
    r.trio(names=NAMES)
    fid = "splitrev-%d-%s" % (k, secrets.token_hex(3))
    r.share(fid)
    A_dir, B_dir = r.path("A", fid, REPO), r.path("B", fid, REPO)
    a_id, b_id, h_id = r["A"].short_id, r["B"].short_id, r["H"].short_id
    cfg = {"A": rig.write_gitconfig(os.path.join(r.root, "gitconfig-writer")),
           "B": rig.write_gitconfig(os.path.join(r.root, "gitconfig-reader"), rig.READER_GUARD),
           "H": rig.write_gitconfig(os.path.join(r.root, "gitconfig-hub"))}
    W = rig.git_env(cfg["A"], home=r["A"].home)
    D = rig.git_env(rig.write_gitconfig(os.path.join(r.root, "gitconfig-defaults")), home=r["B"].home)
    RA = rig.git_env(cfg["B"], optional_locks=0, home=r["A"].home)    # records read, never write
    RB = rig.git_env(cfg["B"], optional_locks=0, home=r["B"].home)
    cwd = {"A": A_dir, "B": B_dir}
    rd = {"A": RA, "B": RB}
    tag = "run %d (%s)" % (k, variant)

    def say(text):
        C.note("%s [%s] %s" % (tag, rig.stamp(), text))

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

    def subject(n, ref):
        return rig.git(cwd[n], ["log", "-1", "--format=%s", ref], rd[n]).stdout.strip()

    def subjects(n):
        return set(rig.git(cwd[n], ["log", "--all", "--format=%s"], rd[n]).stdout.splitlines())

    def gitcopies(n):
        return [p for p in r.conflict_copies(n, fid) if p.startswith(GIT + "/")]

    def record(when):
        v = r.views(fid)
        out = {"views": {key: (x["completion"], x["needItems"], x["needDeletes"]) for key, x in v.items()},
               "A->H lists": r.remoteneed_names("A", fid, "H"), "B->H lists": r.remoteneed_names("B", fid, "H")}
        for n in ("A", "B"):
            st = rig.git(cwd[n], ["status", "--porcelain"], rd[n]).stdout.split("\n")
            out[n] = {"HEAD": head(n), "phantoms": phantoms(n), "copies": r.conflict_copies(n, fid),
                      "status": [x for x in st if x and "sync-conflict" not in x]}
        say("%s:" % when)
        for n in ("A", "B"):
            say("  %s: HEAD %s; phantom refs %s; status %s" % (n, out[n]["HEAD"], out[n]["phantoms"], out[n]["status"]))
            say("  %s: conflict copies %s" % (n, out[n]["copies"]))
        say("  views (completion, needItems, needDeletes): %s" % out["views"])
        say("  A lists towards the hub: %s" % out["A->H lists"])
        say("  B lists towards the hub: %s" % out["B->H lists"])
        return out

    def vector(n, p, which="global"):
        return r.vector(n, fid, p, which)

    def holders(n, p):
        """Short ids n's database says hold p's global version (db/file availability)."""
        d = r.dbfile(n, fid, p) or {}
        out = []
        for a in d.get("availability") or []:
            did = a.get("id") if isinstance(a, dict) else a
            if isinstance(did, str):
                out.append(did[:7])
        return sorted(out)

    def carrying(n, short):
        """The .git files whose version on n carries `short`'s counter."""
        return [p for p in r.files(n, fid, GIT)
                if any(c.split(":", 1)[0] == short for c in (vector(n, p, "local") or []))]

    # --- the gauge, run as A, its remote reads in H's and B's sandboxes ---------------------
    stub = os.path.join(r.root, "stub")
    os.makedirs(os.path.join(stub, "hosts"), exist_ok=True)
    for name, text in (("ssh", STUB_SSH), ("uname", STUB_UNAME)):
        with open(os.path.join(stub, name), "w") as f:
            f.write(text)
        os.chmod(os.path.join(stub, name), 0o755)
    for host, n in (("nousowl", "H"), ("nousowl-vpn", "H"), ("fedxps", "B"), ("fedxps-vpn", "B")):
        d = os.path.join(stub, "hosts", host)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "env"), "w") as f:
            f.write("export HOME=%s SYNC_CHECK_CONFIG=%s GIT_CONFIG_GLOBAL=%s GIT_CONFIG_NOSYSTEM=1 RIG_UNAME=%s\n" % (
                shlex.quote(r[n].dir), shlex.quote(r[n].config_xml), shlex.quote(cfg[n]), NAMES[n]))
            f.write("unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_DATA_HOME XDG_CACHE_HOME GIT_OPTIONAL_LOCKS\n")
    genv = {k2: v for k2, v in os.environ.items() if not k2.startswith(("GIT_", "XDG_", "SYNC_CHECK", "ST"))}
    genv.update(HOME=r["A"].dir, SYNC_CHECK_CONFIG=r["A"].config_xml, GIT_CONFIG_GLOBAL=cfg["A"],
                GIT_CONFIG_NOSYSTEM="1", GIT_PAGER="cat", STUB_DIR=stub, RIG_UNAME=NAMES["A"],
                PATH=stub + os.pathsep + os.environ.get("PATH", "/usr/bin:/bin"))
    printed = []

    def push_line(when):
        t0 = time.time()
        try:
            p = subprocess.run(["python3", "-I", "-B", GAUGE, "-v", "push", A_dir], env=genv,
                               capture_output=True, text=True, timeout=240)
            out, rc = p.stdout + p.stderr, p.returncode
        except subprocess.TimeoutExpired:
            out, rc = "(the gauge did not finish within 240 s)", None
        printed.append(out)
        say("push line run as A (bigfed), %s: exit %s in %.1f s" % (when, rc, time.time() - t0))
        for line in out.splitlines():
            if line.strip():
                say("  | " + line)
        fails = [x for x in out.splitlines() if x.startswith("[FAIL]")]
        return rc, out, fails

    # --- seed through the hub, (a gc on A,) settle -------------------------------------------
    rig.seed_repo(A_dir, W)
    rig.git(A_dir, ["status", "--porcelain"], W)        # the writer's own index, as on bigfed
    settle(3)
    say("seeded from A; B's copy arrived through H (%d paths); A %s, B %s, H %s" % (
        len(r.manifest("B", fid)), a_id, b_id, h_id))
    if do_gc:
        g = rig.git(A_dir, ["gc", "-q"], W)
        say("git gc on A: rc %d; refs/heads/main loose on A: %s" % (
            g.returncode, os.path.exists(os.path.join(A_dir, ".git/refs/heads/main"))))
        settle(3)
    same = r.manifest("A", fid) == r.manifest("B", fid)
    say("before the commits: trees identical %s; packed-refs on B %s; refs/heads/main loose on B %s" % (
        same, os.path.exists(os.path.join(B_dir, ".git/packed-refs")),
        os.path.exists(os.path.join(B_dir, ".git/refs/heads/main"))))
    if not same:
        C.check("%s: the seed%s reached B byte-identical" % (tag, " and the gc" if do_gc else ""), False,
                r.manifest_diff(r.manifest("A", fid), r.manifest("B", fid)))
        r.stop()
        return

    # --- the two commits, GAP s apart ----------------------------------------------------------
    done = {}

    def commit(n, file, line, subj, env):
        with open(os.path.join(cwd[n], file), "a") as f:
            f.write(line)
        g = rig.git(cwd[n], ["commit", "-qam", subj], env)
        done[n] = (rig.stamp(), g.returncode, g.stderr.strip()[:120])

    ta = threading.Thread(target=commit, args=("A", "README.md", "edit made on A\n", "split: on A", W))
    tb = threading.Thread(target=commit, args=("B", "LICENSE", "edit made on B\n", "split: on B", D))
    first, second = (ta, tb) if order == "reverse" else (tb, ta)
    first.start()
    time.sleep(GAP)
    second.start()
    first.join()
    second.join()
    if order == "reverse":
        say("A committed at %s rc %d; B committed (unguarded) %.1f s after A's start, at %s rc %d"
            % (done["A"][0], done["A"][1], GAP, done["B"][0], done["B"][1]))
    else:
        say("B committed (unguarded) at %s rc %d; A committed %.1f s after B's start, at %s rc %d"
            % (done["B"][0], done["B"][1], GAP, done["A"][0], done["A"][1]))
    C.check("%s: both commits made" % tag, done["A"][1] == 0 and done["B"][1] == 0, done)
    t = settle(5)
    say("settled after the commits in %ss" % t)
    split = record("after the commits")
    listed_A = [p for p in split["A->H lists"] if p.startswith(GIT + "/")]
    listed_B = [p for p in split["B->H lists"] if p.startswith(GIT + "/")]
    bwrote = carrying("A", b_id)
    say("  .git files whose version on A carries B's counter: %d %s" % (len(bwrote), bwrote))
    shared = sorted(set(p[:p.index(".sync-conflict-")] for p in gitcopies("A")))
    for p in sorted(set(shared + listed_A + listed_B + [x for x in bwrote if "/objects/pack/" in x]))[:8]:
        say("  vector %s: A local %s global %s | B local %s global %s | held by (A's db) %s (B's db) %s" % (
            p, vector("A", p, "local"), vector("A", p), vector("B", p, "local"), vector("B", p),
            holders("A", p), holders("B", p)))
    rc1, out1, fails1 = push_line("after the commits")

    if order == "reverse":
        ph = split["A"]["phantoms"]
        C.check("%s: nothing strands: neither machine lists anything towards the hub, every view 100" % tag,
                not split["A->H lists"] and not split["B->H lists"] and r.views_clear(r.views(fid)),
                (split["A->H lists"], split["B->H lists"], split["views"]))
        C.check("%s: HEAD equal on both, and it is B's commit" % tag,
                split["A"]["HEAD"] == split["B"]["HEAD"] and split["A"]["HEAD"].endswith("split: on B"),
                (split["A"]["HEAD"], split["B"]["HEAD"]))
        C.check("%s: the phantom branch appears on A with no touch, named after B, holding A's commit" % tag,
                len(ph) == 1 and ph[0].endswith("-" + b_id) and subject("A", ph[0]) == "split: on A",
                (ph, subject("A", ph[0]) if ph else None))
        C.check("%s: the phantom and its copies reach B" % tag,
                split["B"]["phantoms"] == ph and sorted(gitcopies("B")) == sorted(gitcopies("A")),
                (split["B"]["phantoms"], gitcopies("B")))
        C.check("%s: each path with a copy on A holds B's version on both, carrying both counters" % tag,
                bool(shared) and all(vector("A", p, "local") == vector("B", p, "local") and
                                     sorted(c.split(":")[0] for c in (vector("A", p, "local") or [])) == sorted([a_id, b_id])
                                     for p in shared),
                {p: (vector("A", p, "local"), vector("B", p, "local")) for p in shared})
        C.check("%s: the hub holds B's version of each (in A's and B's databases)" % tag,
                bool(shared) and all(h_id in holders("A", p) and h_id in holders("B", p) for p in shared),
                {p: (holders("A", p), holders("B", p)) for p in shared})
        C.check("%s: the push line refuses on the phantom and its copies, the repair here" % tag,
                rc1 not in (0, None) and any("phantom ref" in x for x in fails1) and "rename the phantom" in out1, fails1)
        C.check("%s: the push line asks no touch of fedxps and finds no HEAD differing" % tag,
                "touch exactly these paths" not in out1 and "HEAD differs" not in out1
                and "did not answer" not in out1 and "gave no HEAD" not in out1, fails1)
    else:
        C.check("%s: the covered order: HEADs differ, A lists .git paths towards the hub, B nothing" % tag,
                split["A"]["HEAD"] != split["B"]["HEAD"] and bool(listed_A) and not split["B->H lists"],
                (split["A"]["HEAD"], split["B"]["HEAD"], split["A->H lists"], split["B->H lists"]))
        C.check("%s: the push line refuses on the needed .git paths and the differing HEAD" % tag,
                rc1 not in (0, None) and any("under its .git needed" in x for x in fails1)
                and any("HEAD differs on fedxps" in x for x in fails1), fails1)
        C.check("%s: its fix names fedxps for the touch" % tag,
                "a split with no phantom: on fedxps, touch exactly these paths" in out1, out1[-1500:])

    # --- a strand, if any: the sanctioned reader write, touch on B what is listed ------------------
    listed = sorted(set(listed_A + listed_B))
    if listed:
        touched, missing = [], []
        for p in listed:
            q = r.path("B", fid, p)
            if os.path.lexists(q):
                os.utime(q)
                touched.append(p)
            else:
                missing.append(p)
        say("listed towards the hub (A %s, B %s); touched on B: %s; absent on B: %s" % (
            listed_A, listed_B, touched, missing))
        t = settle(5)
        say("settled after the touch in %ss" % t)
        record("after the touch")
    phantom = phantoms("A")
    if order == "forward":
        C.check("%s: after the touch the phantom branch appears on A" % tag, bool(phantom), phantom)
    if not phantom:
        say("no phantom on A: the repair as written cannot continue; state left as recorded")
        r.stop()
        return

    # --- the phantom repair on A (him-2), as case_split runs it --------------------------------
    t = settle(QUIET)
    say("quiet %ds (waited %ss)" % (QUIET, t))
    fsck = rig.git(A_dir, ["fsck", "--connectivity-only", "--no-progress"], W)
    say("fsck --connectivity-only on A: rc %d %s" % (fsck.returncode, fsck.stderr.strip()[:200]))
    ph = phantom[0][len("refs/heads/"):]
    rescue = "rescue-splitrev-%d" % k
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

    # --- (d) a stranded deletion, after the repair (case_split.py's step (d), 2026-10-27) -------
    # A deletion of the repair's on A -- the renamed branch's ref and reflog
    # by `git branch -D`, an inert copy -- can meet at the hub a concurrent
    # modification of the same path by B, which beats a deletion: the hub
    # refuses it, A lists the path to the end and B keeps the file (the gc
    # variant on fedxps, 2026-10-27). him-2's first case and the sanctioned
    # touch: on B a touch, whose version descends from A's and returns to A;
    # then on A the deletion again. The race is a tie at the hub and cannot be
    # forced; the case records it when it recurs.
    def git_listed():
        return [p for p in r.remoteneed_names("A", fid, "H") if p.startswith(GIT + "/")]

    def held(p):
        """What A and B hold at p: absent, a file, or a directory of N entries."""
        out = []
        for n in ("A", "B"):
            q = r.path(n, fid, p)
            out.append("%s %s" % (n, ("a directory of %d entries" % len(os.listdir(q))) if os.path.isdir(q)
                                  else "a file" if os.path.lexists(q) else "absent"))
        return "%s (%s)" % (p, ", ".join(out))

    def vectors(paths):
        for p in paths:
            say("  vector %s: A local %s global %s | B local %s global %s" % (
                p, vector("A", p, "local"), vector("A", p), vector("B", p, "local"), vector("B", p)))

    def refused_deletion(p):
        return not os.path.lexists(r.path("A", fid, p)) and os.path.isfile(r.path("B", fid, p))
    still = git_listed()
    stranded = [p for p in still if refused_deletion(p)]
    if stranded:
        say("stranded copies after the repair, deleted on A and refused by the hub: %s" % "; ".join(held(p) for p in stranded))
        vectors(stranded)
        for p in stranded:
            os.utime(r.path("B", fid, p))
        t = settle(5)
        back = [p for p in stranded if os.path.lexists(r.path("A", fid, p))]
        say("touched on B, settled in %ss: back on A %s of %s; A lists under .git %s" % (
            t, len(back), len(stranded), git_listed() or "nothing"))
        vectors(stranded)
        under_refs = [p for p in back if p.startswith(GIT + "/refs/")]
        ph_before = phantoms("A") if under_refs else None
        refs_before = rig.git(A_dir, ["for-each-ref", "--format=%(refname)", "refs/"], rd["A"]).stdout.split() if under_refs else None
        for p in back:
            os.remove(r.path("A", fid, p))
        ph_after = phantoms("A") if under_refs else None
        refs_after = rig.git(A_dir, ["for-each-ref", "--format=%(refname)", "refs/"], rd["A"]).stdout.split() if under_refs else None
        t = settle(5)
        still = git_listed()
        say("deleted on A again, settled in %ss: A lists under .git %s%s" % (
            t, still or "nothing",
            ("; phantom refs on A before the deletion %s, after %s; refs gone %s" % (
                ph_before, ph_after, sorted(set(refs_before) - set(refs_after)))) if under_refs else ""))
        left_d = [p for p in still if p in stranded]
        if not left_d:
            say("stranded copies after the repair: %s, cleared by the touch on B and the deletion on A again" % ", ".join(stranded))
        else:
            say("stranded copies after the repair: %s, not cleared; still listed %s" % (", ".join(stranded), left_d))
    else:
        say("stranded copies after the repair: none")
    C.check("%s: nothing stranded under .git after the repair steps" % tag, not still, still)
    final = record("after the repair")

    # --- the end state ---------------------------------------------------------------------------
    ma, mb = r.manifest("A", fid, GIT), r.manifest("B", fid, GIT)
    C.check("%s: both .git trees byte-identical (%d paths)" % (tag, len(ma)), ma == mb, r.manifest_diff(ma, mb))
    C.check("%s: both whole trees byte-identical" % tag, r.manifest("A", fid) == r.manifest("B", fid),
            r.manifest_diff(r.manifest("A", fid), r.manifest("B", fid)))
    for n in ("A", "B"):
        f = rig.git(cwd[n], ["fsck", "--no-progress", "--no-dangling"], rd[n])
        C.check("%s: git fsck clean on %s" % (tag, n), f.returncode == 0, f.stderr[:300])
    v = r.views(fid)
    C.check("%s: every view 100 with nothing needed" % tag, r.views_clear(v), v)
    C.check("%s: no conflict copy and no phantom left" % tag,
            not (final["A"]["copies"] or final["B"]["copies"] or final["A"]["phantoms"] or final["B"]["phantoms"]),
            {n: (final[n]["copies"], final[n]["phantoms"]) for n in ("A", "B")})
    C.check("%s: HEAD equal on both" % tag, final["A"]["HEAD"] == final["B"]["HEAD"],
            (final["A"]["HEAD"], final["B"]["HEAD"]))
    for n in ("A", "B"):
        s = subjects(n)
        C.check("%s: both commits' subjects reachable on %s" % (tag, n),
                {"split: on A", "split: on B"} <= s, sorted(x for x in s if x.startswith("split")))
    C.check("%s: B's working tree clean under the guard" % tag, not final["B"]["status"], final["B"]["status"])
    bwrote = carrying("A", b_id)
    say("  .git files whose version on A carries B's counter after the repair: %d %s" % (len(bwrote), bwrote))

    # --- the push line after the repair -----------------------------------------------------------
    rc2, out2, fails2 = push_line("after the repair")
    C.check("%s: after the repair the push line finds no phantom, no copy, no needed .git path, no HEAD differing" % tag,
            rc2 is not None and not any(("phantom ref" in x or "under its .git needed" in x or "HEAD differs" in x)
                                        for x in fails2), fails2)
    vfail = [x for x in fails2 if "another machine's counter" in x]
    say("after the repair the push line exits %s; its vector check %s" % (
        rc2, ("FAILs: " + vfail[0]) if vfail else "passes"))

    # --- then a gc on A, bigfed's routine maintenance: what still carries B's counter ----------
    g = rig.git(A_dir, ["gc", "-q"], W)
    settle(5)
    ma, mb = r.manifest("A", fid, GIT), r.manifest("B", fid, GIT)
    C.check("%s: after a gc on A both .git trees byte-identical (%d paths), fsck clean on both" % (tag, len(ma)),
            g.returncode == 0 and ma == mb and all(
                rig.git(cwd[n], ["fsck", "--no-progress", "--no-dangling"], rd[n]).returncode == 0 for n in ("A", "B")),
            (g.returncode, r.manifest_diff(ma, mb)))
    bwrote = carrying("A", b_id)
    say("  after a gc on A, .git files whose version on A carries B's counter: %d %s" % (len(bwrote), bwrote))
    rc3, out3, fails3 = push_line("after a gc on A")
    vfail = [x for x in fails3 if "another machine's counter" in x]
    say("after the gc the push line exits %s; its vector check %s" % (
        rc3, ("FAILs: " + vfail[0]) if vfail else "passes"))

    # --- the stub ssh: where the gauge's reads went, and no secret in them ----------------------------
    try:
        with open(os.path.join(stub, "ssh.log")) as f:
            hosts = [x.strip() for x in f if x.strip()]
        with open(os.path.join(stub, "ssh-argv.log")) as f:
            argv = f.read()
    except OSError:
        hosts, argv = [], ""
    say("the gauge's ssh calls: %s" % {h: hosts.count(h) for h in sorted(set(hosts))})
    C.check("%s: the gauge's ssh went to nousowl and fedxps alone" % tag,
            bool(hosts) and set(hosts) <= {"nousowl", "fedxps"}, hosts)
    secrets_seen = [s for s in [r[n].apikey for n in NODES] + [rig.PASSWORD] if s in argv or any(s in o for o in printed)]
    C.check("%s: no API key and no password in any ssh command line or gauge line" % tag, not secrets_seen,
            "%d secret(s) seen" % len(secrets_seen))
    say("run took %.0f s" % (time.time() - t_run))
    r.stop()


def main(root, runs=1, variants=("gc", "nogc")):
    C = rig.Checks()
    bad = [v for v in variants if v not in VARIANTS]
    if bad:
        C.check("variants known (%s)" % ", ".join(VARIANTS), False, bad)
        return C
    if not os.path.isfile(GAUGE):
        C.check("bin/sync-check present at %s" % GAUGE, False)
        return C
    k = 0
    for variant in variants:
        for _ in range(runs):
            k += 1
            try:
                run_once(k, variant, root, C)
            except rig.RigError as e:
                C.check("run %d (%s) ran to its end" % (k, variant), False, e)
    return C


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 1,
         tuple(x for x in (sys.argv[3] if len(sys.argv) > 3 else "gc,nogc").split(",") if x)).exit()
