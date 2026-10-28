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

The gauge's readings, folded in at step 5c-b (2026-10-27; PLAN.md -> settled
79, 80, 81, from the rehearsal's counter-test cutover/rehearsal/refute-b/):
bin/sync-check runs as A (bigfed, the writer, no host file) and as B (fedxps,
a host file naming role = reader linked as host.inc, GIT_OPTIONAL_LOCKS=0),
its ssh and uname stubbed so that `ssh nousowl` and `ssh fedxps` run in H's
and B's sandboxes. After the commits: A's push line refuses on the needed
.git paths with "a split with no phantom", on fedxps, and on the differing
HEAD; its sync line names the split repair (settled 80); B's guard FAILs on
its disk events and on its own counter. After the repair: the push line
refuses on fedxps's counter alone and prints its KNOWN_WRITES lines, which are
pasted as printed into a copy of the gauge in the run's directory; with the
copy the push line reads OK, and B's guard clears its vector half while its
disk-event half still FAILs; after B's daemon restarts it reads OK with the
copy, the step him-2's repairs now end with. Then bigfed's own maintenance, a
`git gc` (which deletes refs/heads/main and B's fan-out directories, their
records keeping B's counter), and A's next commit, which writes
refs/heads/main again on its deleted record: the copy still reads OK on both
lines (refute-b.md -> A9, F2, the reason the entries name the counter). No API
key and no password in any ssh or gauge line.

A .git path the touch leaves listed (the lead's follow-ups, 2026-10-27): when
both commits write a new object into one fan-out directory, the directory's
two versions each carry one device's counter, of the same second, so the hub
cannot order them, and the touch moves only the directory's time, which is no
change to Syncthing: the directory stays listed towards the hub by A (seen by
coincidence in two runs of six that day, then in none of fifteen). So run 1
forces it, and the later runs keep the plain lines: B's line carries
FORCE_NONCE, which puts B's new LICENSE blob into objects/78 beside A's new
README.md blob by git's object naming (a loose object lives at
objects/<the first two hex digits of its SHA-1>, the SHA-1 of
"blob <size>\0<content>"); run 1 records whether the shared directory arose,
and checks it. Whatever the touch left listed is recorded with what each
machine holds there (a); the phantom repair goes on regardless; after it,
once the renamed branch is gone, `git gc -q` on A, which packs the loose
objects and removes the fan-out directories that leaves empty (c); if A still
lists the path, a permission change on B and back, as him-2's 2026-10-11
annotation did for a stranded directory (b); in run 1 the push line, read
once after the touch, must name the directory with that permission change in
its fix. Last (d): a copy A deleted in the repair that the hub refused,
since it recorded B's copy first and a concurrent modification beats a
deletion (the lead's rig run of 2026-10-27: both machines made the same two
conflict copies in one second), is touched on B, comes back to A and is
deleted there again, with its own `# ` line; the race is a tie at the hub,
so it is recorded when it recurs, never forced. One `# ` line names the step
that cleared it, or that none was needed, and a check asserts nothing stays
stranded under .git after these steps. Run 1 thus measures, on a shared
directory every time: ws-1's stranded criterion and bigfed-2's refusal on a
needed .git path in the gauge's sync and push lines, him-2's touch (settled
79) and split repair (settled 80), and which of the gc and the permission
change clears a directory the touch cannot move. Measured 2026-10-27 in run
1, two runs of two: the gc after the repair removes A's directory, B keeps
it, empty, and A still lists it; the permission change on B then clears it.
Before this order, in a scratch copy forcing the same directory, the
permission change before the repair cleared it twice of two, and a gc in its
place did not, leaving the two .git trees differing by that directory.

Each step is printed with its wall-clock time, so a run that departs from
him-2's text is a record of what happened instead. Runs RUNS times (argv[2],
default 3), each on fresh instances: the hub's ordering is the variable.

    python3 -I case_split.py ROOT [RUNS]
"""
import ast
import os
import re
import secrets
import shlex
import stat
import subprocess
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402

NODES = ["A", "B", "H"]
NAMES = {"A": "bigfed", "B": "fedxps", "H": "nousowl"}   # the devices as the gauge names them
REPO = "repo"       # a subdirectory of the folder, as each repository is of ~/Desktop after the cutover
GIT = REPO + "/.git"
GAP = 0.3
QUIET = 15          # him-2: the folder quiet 15 s before the phantom repair
GAUGE = os.path.realpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "bin", "sync-check"))
KEYS = ["on", "label", "counter", "since", "note"]
# Run 1's line on B (2026-10-27): the nonce that puts B's new LICENSE blob into
# objects/78, the fan-out directory of A's new README.md blob, so the shared
# directory arises every time. Found by trying n = 0, 1, ... until the SHA-1 of
# "blob <size>\0" + LICENSE + "edit made on B <n>\n" began with the first two
# hex digits of A's blob; 337 is the first. It depends on rig.seed_repo's
# README.md and LICENSE, on both edit lines in run_once and on git's SHA-1
# object names; on the gc after the seed, which packs the seed's loose objects
# so that objects/78 is new on both machines; on commit()'s append mode, the
# line added to the file as it stands; and on git with no clean or smudge
# filter and no autocrlf, so the blob is the file's bytes (the reviewer's
# list, 2026-10-27). Change any and it no longer collides, which run 1 records
# ("did not arise") and its checks fail.
FORCE_NONCE = 337
FORCE_DIR = "78"

# The gauge's ssh, stubbed: each host runs the command in its node's sandbox,
# with that node's config.xml and git configuration (case_refute_b.py's stub).
STUB_SSH = r"""#!/usr/bin/env bash
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
STUB_UNAME = "#!/bin/sh\necho \"${RIG_UNAME:-rig}\"\n"


def run_once(k, root, C):
    t_run = time.time()
    r = rig.Rig(os.path.join(root, "run%d" % k))
    r.trio(names=NAMES)
    fid = "split-%d-%s" % (k, secrets.token_hex(3))
    r.share(fid)
    A_dir, B_dir = r.path("A", fid, REPO), r.path("B", fid, REPO)
    a_id, b_id = r["A"].short_id, r["B"].short_id
    cfg_w = rig.write_gitconfig(os.path.join(r.root, "gitconfig-writer"))
    W = rig.git_env(cfg_w, home=r["A"].home)
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

    def carrying(n):
        """The paths under .git, files and directories, whose local or global
        version on n carries B's counter (the deleted ones are out of db/browse's
        reach, as they are of the gauge's)."""
        out = []
        for p in [k2 for k2 in r.manifest(n, fid, GIT)]:
            d = r.dbfile(n, fid, p) or {}
            if any(c.split(":", 1)[0][:7] == b_id for side in ("local", "global")
                   for c in ((d.get(side) or {}).get("version") or [])):
                out.append(p)
        return out

    # --- the gauge's two environments: A as bigfed, B as fedxps under role = reader ----------
    stub = os.path.join(r.root, "stub")
    os.makedirs(os.path.join(stub, "hosts"), exist_ok=True)
    for name, text in (("ssh", STUB_SSH), ("uname", STUB_UNAME)):
        with open(os.path.join(stub, name), "w") as f:
            f.write(text)
        os.chmod(os.path.join(stub, name), 0o755)
    # B as fedxps on cutover day: a host file naming role = reader, linked as
    # host.inc, which git includes; GIT_OPTIONAL_LOCKS=0 as 10-env.sh exports it
    hostdir = os.path.join(r["B"].dir, "Desktop", "configs", "git", "hosts")
    os.makedirs(hostdir, exist_ok=True)
    hostfile = os.path.join(hostdir, "fedxps.inc")
    with open(hostfile, "w") as f:
        f.write(rig.READER_GUARD + "[gsync]\n\trole = reader\n")
    os.makedirs(os.path.join(r["B"].dir, ".config", "git"), exist_ok=True)
    os.symlink(hostfile, os.path.join(r["B"].dir, ".config", "git", "host.inc"))
    bglobal = os.path.join(r.root, "gitconfig-B-guard")
    with open(bglobal, "w") as f:
        f.write(rig.GIT_IDENTITY + "[include]\n\tpath = %s\n" % os.path.join(r["B"].dir, ".config", "git", "host.inc"))
    ncfg = {"A": cfg_w, "B": bglobal, "H": rig.write_gitconfig(os.path.join(r.root, "gitconfig-hub"))}
    for host, n in (("nousowl", "H"), ("nousowl-vpn", "H"), ("fedxps", "B"), ("fedxps-vpn", "B")):
        d = os.path.join(stub, "hosts", host)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "env"), "w") as f:
            f.write("export HOME=%s SYNC_CHECK_CONFIG=%s GIT_CONFIG_GLOBAL=%s GIT_CONFIG_NOSYSTEM=1 RIG_UNAME=%s\n" % (
                shlex.quote(r[n].dir), shlex.quote(r[n].config_xml), shlex.quote(ncfg[n]), NAMES[n]))
            f.write("unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_DATA_HOME XDG_CACHE_HOME GIT_OPTIONAL_LOCKS\n")
    # Each gauge HOME is the node's directory, so a ~/data/<fid>/repo the gauge
    # names on A is B's copy when its HEAD is read over the stub. The case has
    # settled before each reading, so the gauge's own settle (15 s by default)
    # only confirms: 5 s here.
    base = {k2: v for k2, v in os.environ.items() if not k2.startswith(("GIT_", "XDG_", "SYNC_CHECK", "ST"))}
    path = stub + os.pathsep + os.environ.get("PATH", "/usr/bin:/bin")
    common = dict(base, GIT_CONFIG_NOSYSTEM="1", GIT_PAGER="cat", STUB_DIR=stub, PATH=path,
                  SYNC_CHECK_SETTLE="5", SYNC_CHECK_POLL="1")
    genv = dict(common, HOME=r["A"].dir, SYNC_CHECK_CONFIG=r["A"].config_xml, GIT_CONFIG_GLOBAL=cfg_w,
                RIG_UNAME=NAMES["A"])
    benv = dict(common, HOME=r["B"].dir, SYNC_CHECK_CONFIG=r["B"].config_xml, GIT_CONFIG_GLOBAL=bglobal,
                RIG_UNAME=NAMES["B"], GIT_OPTIONAL_LOCKS="0")
    printed = []

    def gauge(env, words, who, when, gauge_path=GAUGE):
        t0 = time.time()
        try:
            p = subprocess.run(["python3", "-I", "-B", gauge_path, "-v"] + words, env=env,
                               capture_output=True, text=True, timeout=240)
            out, rc = p.stdout + p.stderr, p.returncode
        except subprocess.TimeoutExpired:
            out, rc = "(the gauge did not finish within 240 s)", None
        printed.append(out)
        say("%s run as %s, %s%s: exit %s in %.1f s" % (" ".join(words), who, when,
                                                       "" if gauge_path == GAUGE else " (the KNOWN_WRITES copy)",
                                                       rc, time.time() - t0))
        for line in out.splitlines():
            if line.strip():
                say("  | " + line)
        return rc, out, [x for x in out.splitlines() if x.startswith("[")]

    def push(when, gp=GAUGE):
        return gauge(genv, ["push", A_dir], "A (bigfed)", when, gp)

    def guard_line(when, gp=GAUGE):
        return gauge(benv, ["guard"], "B (fedxps, role = reader)", when, gp)

    def tagged(lines, tag, word=""):
        label = " OK " if tag == "OK" else tag      # the gauge prints [ OK ]
        return [x for x in lines if x.startswith("[%s]" % label) and word in x]

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

    b_line = ("edit made on B %d\n" % FORCE_NONCE) if k == 1 else "edit made on B\n"     # run 1 forced
    tb = threading.Thread(target=commit, args=("B", "LICENSE", b_line, "split: on B", D))
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
    if k == 1:
        ba = rig.git(cwd["A"], ["rev-parse", "HEAD:README.md"], rd["A"]).stdout.strip()
        bb = rig.git(cwd["B"], ["rev-parse", "HEAD:LICENSE"], rd["B"]).stdout.strip()
        shared = bool(ba) and ba[:2] == bb[:2]
        say("forced run: the shared directory %s (A's new README.md blob %s, B's new LICENSE blob %s)" % (
            ("did arise, objects/%s" % ba[:2]) if shared else "did not arise", ba[:12] or "?", bb[:12] or "?"))
        C.check("run 1 (forced): both new blobs in one fan-out directory, objects/%s" % FORCE_DIR,
                shared and ba[:2] == FORCE_DIR, (ba, bb))
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

    # --- the gauge after the commits: the push line as A, the guard as B --------------------
    rc1, out1, l1 = push("after the commits")
    C.check("run %d: the push line as A refuses on the needed .git paths and the differing HEAD" % k,
            rc1 == 1 and bool(tagged(l1, "FAIL", "under its .git needed")) and bool(tagged(l1, "FAIL", "HEAD differs on fedxps")), l1)
    C.check("run %d:   its fix: a split with no phantom, the touch on fedxps" % k,
            "a split with no phantom: on fedxps, touch exactly these paths" in out1
            and "the hub holds the loser" not in out1, out1[-1500:])
    C.check("run %d:   its sync line names the split repair, never 'delete the copy' (settled 80)" % k,
            "a split of main: on fedxps, touch exactly these paths under the repository's .git and nothing else" in out1
            and "the phantom branch then appears on bigfed" in out1
            and ("sync-check push ~/data/%s/repo names each step" % fid) in out1
            and "merge it into the original and delete the copy" not in out1, out1[:1500])
    gr1, gout1, gl1 = guard_line("after the commits")
    C.check("run %d: the guard as B FAILs on both halves: its disk events and its own counter" % k,
            gr1 == 1 and bool(tagged(gl1, "FAIL", "seen under a .git")) and bool(tagged(gl1, "FAIL", "this machine's counter")), gl1)

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
    # what the touch left listed, directories included: a fan-out directory
    # both machines made in the split stayed listed after it (seen 2026-10-27
    # in one run of three, B's commit object landing in the objects/b6 that
    # A's tree object always makes)
    vectors(sorted(set(after_touch["A->H lists"] + after_touch["B->H lists"])))

    # --- (a) a .git path the touch left listed: recorded (2026-10-27) ---------------------------
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
    residue = [p for p in after_touch["A->H lists"] if p.startswith(GIT + "/")]
    if residue:
        say("still listed towards the hub by A after the touch: %s" % "; ".join(held(p) for p in residue))
    if k == 1:
        # the effect, not only its cause: a Syncthing whose touch clears a
        # shared directory fails this run loudly (the reviewer, 2026-10-27)
        C.check("run 1 (forced): after the touch the shared directory is still listed towards the hub by A",
                GIT + "/objects/" + FORCE_DIR in residue, after_touch["A->H lists"])
        # and the gauge's fix says so: the directory named, with the reader's
        # permission change set back (his word at the pause of 5c-b, 2026-10-27)
        rcd, outd, ld = push("after the touch")
        C.check("run 1 (forced): the push line names %s/objects/%s a directory, with the permission change on fedxps" % (GIT, FORCE_DIR),
                re.search(r"%s/objects/%s is a directory, which a touch does not move for Syncthing: on fedxps, change its "
                          r"permissions and set them back \(chmod g\+w \S*/%s/objects/%s; chmod g-w \S*/%s/objects/%s\)" % (
                              re.escape(GIT), FORCE_DIR, re.escape(GIT), FORCE_DIR, re.escape(GIT), FORCE_DIR), outd) is not None,
                outd[-1500:])
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

    # --- (c) then (b): what the touch left listed, after the repair (2026-10-27) ---------------
    listed_after = still = git_listed()
    steps = []
    if still:
        say("listed towards the hub by A after the repair: %s" % "; ".join(held(p) for p in still))
        g = rig.git(A_dir, ["gc", "-q"], W)
        t = settle(5)
        still = git_listed()
        steps.append("git gc on A after the repair")
        say("git gc -q on A: rc %d, settled in %ss: A lists under .git %s" % (
            g.returncode, t, "; ".join(held(p) for p in still) or "nothing"))
        vectors(still)
    dirs = [p for p in still if os.path.isdir(r.path("B", fid, p))]
    if dirs:
        changed = []
        for p in dirs:
            q = r.path("B", fid, p)
            mode = stat.S_IMODE(os.stat(q).st_mode)
            os.chmod(q, mode ^ stat.S_IWGRP)      # g+w, or g-w where it was set
            changed.append((p, q, mode))
        settle(5)
        for p, q, mode in changed:
            os.chmod(q, mode)
        t = settle(5)
        still = git_listed()
        steps.append("the permission change on B")
        say("a permission change on B and back (%s), settled in %ss: A lists under .git %s" % (
            ", ".join("%s %o -> %o -> %o" % (p, m, m ^ stat.S_IWGRP, m) for p, q, m in changed),
            t, "; ".join(held(p) for p in still) or "nothing"))
        vectors(still)
    # a copy A deleted that the hub refused (step (d) below) is no residue of
    # the touch: the reading here leaves it out
    def refused_deletion(p):
        return not os.path.lexists(r.path("A", fid, p)) and os.path.isfile(r.path("B", fid, p))
    stranded = [p for p in still if refused_deletion(p)]
    left = [p for p in still if p not in stranded]
    after_res = [p for p in listed_after if p not in stranded]
    found = ", ".join(residue) or ("none after the touch, %s after the repair" % ", ".join(after_res))
    if not residue and not after_res:
        say("the touch's residue: none, no further step needed%s" % (
            " (the steps above ran for the stranded copies below)" if steps else ""))
    elif not steps:
        say("the touch's residue: %s, gone by the end of the phantom repair, no further step needed" % found)
    elif not left:
        say("the touch's residue: %s, cleared by %s%s" % (found, steps[-1], (" (%s did not)" % steps[0]) if len(steps) > 1 else ""))
    else:
        say("the touch's residue: %s, not cleared by %s; still listed %s" % (found, " nor ".join(steps), left))

    # --- (d) a stranded deletion, after the repair (the lead's rig run, 2026-10-27) -------------
    # Both machines can make the same conflict copy in one second, each with
    # its own counter; when the hub records B's, A's later deletion (the
    # phantom's rename) meets a concurrent modification, which beats a
    # deletion: the hub refuses it, A lists the path to the end and B keeps
    # the file. him-2's first case and the sanctioned touch: on B a touch,
    # whose version descends from A's and returns to A; then on A the
    # deletion again. The race is a tie at the hub and cannot be forced; the
    # case records it when it recurs.
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
    C.check("run %d: nothing stranded under .git after the repair steps" % k, not still, still)
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

    # --- him-2's closing step (settled 79): the KNOWN_WRITES lines the push line prints -----------
    say("  .git paths carrying B's counter after the repair: on A %s" % carrying("A"))
    rc2, out2, l2 = push("after the repair")
    C.check("run %d: after the repair the push line refuses on another machine's counter alone" % k,
            rc2 == 1 and bool(tagged(l2, "FAIL")) and all("another machine's counter" in x for x in tagged(l2, "FAIL")), l2)
    lines = [x for x in out2.splitlines() if x.startswith("       {") and x.endswith("},")]
    try:
        entries = [ast.literal_eval(x.strip()[:-1]) for x in lines]
    except (ValueError, SyntaxError) as e:
        entries = ["(not a literal: %s)" % e]
    named = sorted(set(int(c) for c in re.findall(r"fedxps's counter (\d+)", out2)))
    cut = "       ... and " in out2       # past VECTOR_LIST_MAX paths, some counters' paths go unlisted
    say("the push line printed %d KNOWN_WRITES line(s); the counters its listed paths name: %s%s" % (
        len(lines), named, " (the list cut)" if cut else ""))
    ok_entries = bool(lines) and all(isinstance(e, dict) and list(e) == KEYS and e["on"] == "fedxps" and e["label"] == fid
                                     and type(e["counter"]) is int for e in entries)
    counters = [e["counter"] for e in entries] if ok_entries else []
    C.check("run %d:   it prints one KNOWN_WRITES line per fedxps counter, in counter order, each a Python literal of the entry" % k,
            ok_entries and counters == sorted(set(counters)) and (counters == named or (cut and set(named) <= set(counters))),
            (lines, named))
    known = os.path.join(r.root, "sync-check-known")
    with open(GAUGE) as f:
        text = f.read()
    if text.count("\nKNOWN_WRITES = [\n") != 1:
        C.check("run %d: the gauge's KNOWN_WRITES list found to paste into" % k, False)
        r.stop()
        return
    with open(known, "w") as f:
        f.write(text.replace("\nKNOWN_WRITES = [\n", "\nKNOWN_WRITES = [\n" + "".join(x + "\n" for x in lines), 1))
    say("the printed lines pasted as printed into %s" % known)
    rc3, out3, l3 = push("with the printed lines", known)
    C.check("run %d:   pasted as printed, the push line reads OK (exit 0)" % k, rc3 == 0 and not tagged(l3, "FAIL"), l3)
    gr3, gout3, gl3 = guard_line("with the printed lines", known)
    C.check("run %d:   and the guard as B clears its vector half while its disk-event half still FAILs" % k,
            not tagged(gl3, "FAIL", "this machine's counter") and bool(tagged(gl3, "OK", "beyond the known write"))
            and bool(tagged(gl3, "FAIL", "seen under a .git")), gl3)

    # --- systemctl --user restart syncthing on fedxps (his hand; the rig's restart of B) -------
    r.restart("B")
    r.wait_connected([("B", "H")])
    t = settle(5)
    say("B's daemon restarted; settled in %ss" % t)
    gr4, gout4, gl4 = guard_line("after B's daemon restarted", known)
    C.check("run %d: after B's restart the guard as B reads OK with the copy (exit 0)" % k,
            gr4 == 0 and not tagged(gl4, "FAIL"), gl4)

    # --- F2's re-test: bigfed's gc, then its next commit ------------------------------------------
    before_gc = set(carrying("A"))
    g = rig.git(A_dir, ["gc", "-q"], W)
    t = settle(5)
    after_gc = set(carrying("A"))
    loose = os.path.exists(os.path.join(A_dir, ".git/refs/heads/main"))
    say("git gc on A: rc %d, settled in %ss; refs/heads/main loose %s; B's counter on %d paths, was %d" % (
        g.returncode, t, loose, len(after_gc), len(before_gc)))
    rc5, out5, l5 = push("after a gc on A", known)
    C.check("run %d: after bigfed's gc the copy still reads OK (exit 0)" % k, rc5 == 0 and not tagged(l5, "FAIL"), l5)
    ci = rig.git(A_dir, ["commit", "-q", "--allow-empty", "-m", "the next commit"], W)
    t = settle(5)
    after_ci = set(carrying("A"))
    back = sorted(after_ci - after_gc)
    say("A's next commit: rc %d, settled in %ss; B's counter back on %s" % (ci.returncode, t, back))
    vectors(back[:6])
    C.check("run %d: F2's shape: the commit wrote refs/heads/main again on its deleted record, B's counter with it" % k,
            not loose and ci.returncode == 0 and GIT + "/refs/heads/main" in back, (loose, ci.returncode, back))
    rc6, out6, l6 = push("after A's next commit", known)
    C.check("run %d: after A's next commit the copy still reads OK (exit 0): the entries name the counter" % k,
            rc6 == 0 and not tagged(l6, "FAIL"), l6)
    gr6, gout6, gl6 = guard_line("after A's next commit", known)
    C.check("run %d:   and so does the guard as B (exit 0)" % k, gr6 == 0 and not tagged(gl6, "FAIL"), gl6)

    # --- where the gauge's ssh went, and no secret in any line ----------------------------------------
    try:
        with open(os.path.join(stub, "ssh.log")) as f:
            hosts = [x.strip() for x in f if x.strip()]
        with open(os.path.join(stub, "ssh-argv.log")) as f:
            argv = f.read()
    except OSError:
        hosts, argv = [], ""
    say("the gauge's ssh calls: %s" % {h: hosts.count(h) for h in sorted(set(hosts))})
    C.check("run %d: the gauge's ssh went to nousowl and fedxps alone" % k,
            bool(hosts) and set(hosts) <= {"nousowl", "fedxps"}, sorted(set(hosts)))
    seen = [s for s in [r[n].apikey for n in NODES] + [rig.PASSWORD] if s in argv or any(s in o for o in printed)]
    C.check("run %d: no API key and no password in any ssh line or gauge line" % k, not seen, "%d seen" % len(seen))
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
