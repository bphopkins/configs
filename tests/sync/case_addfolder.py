#!/usr/bin/env python3
"""Case addfolder: bin/syncthing-addfolder on the rig (rules.md -> mig-4, mig-3,
hub-3, ws-7, ws-16; the tool's docstring is the design).

The tool runs as bigfed: A's sandbox HOME, A's config.xml named by
SYNC_CHECK_CONFIG (the gauge's variable), a git config whose gsync.role reads
writer. A stub ssh, first on the tool's PATH alone, runs the command words in
the sandbox of the instance a host name names (nousowl and nousowl-vpn -> H,
fedxps and fedxps-vpn -> B), with that instance's HOME, config.xml and git
config, so the tool's remote mode runs against the rig; a door marked down
answers ssh's 255; every call is logged. The tool's waits are shortened by
its knobs (poll 0.5 s, bounce hold 1 s, switch watch 6 s). Its every line is
shown below as a `#   ` reading.

On one trio (A, B, H, with the direct link A<->B), each sub-case on a fresh
folder id:
  1. no cluster password on A yet: refused before any write (no hub to name;
     with --hub, no terminal for the password)
  2. refusals, nothing written: a nested .stfolder under the reader's path;
     an existing hub directory (hub-3); a hub path under ~/sync that is no
     mount; a repository at the writer's root that does not ignore .stfolder/
  3. --dry-run: the plan, nothing written (config.xml bytes on all three),
     with fedxps's first door down and its -vpn door answering
  4. fresh end to end: A and B equal by manifest, H ciphertext only,
     maxConflicts 10 everywhere, H staggered maxAge 31536000 and minDiskFree
     1 %, the device lists, the bounce seen in startedAt, every view clear;
     then a re-run that verifies and writes nothing; then --undo
  5. a half-made cluster: Ctrl-C while bigfed bounces the hub (the hub's
     folder made, fedxps's not), the paused device resumed; the re-run
     completes without re-creating (markers' inodes kept), --hub-only
  6. join end to end: B's repository gc'd (packs against A's loose objects)
     and one .git file edited; every B-only and differing .git path listed by
     localchanged and found in the trashcan, the manifests equal, the hub's
     sequence unchanged across the switch, fsck clean, the link shared
  7. join stopping on a path outside .git; the re-run with --allow-outside
  8. the rebuild's password paths: fedxps holding no encrypted folder (bigfed's
     password reaches it in the program text); then neither workstation, the
     password asked once on a pseudo-terminal (a whitespace one refused first)
  9. the reader's gsync keys (R2's H2): role = writer, no key, a readerRepo
     naming another path refused; a readerRepo naming READER-PATH passes; an
     unreadable git config on either machine is exit 2
 10. each preflight refusal in its failing direction: a label taken, a folder
     configured inside the path (paused at an absent path, so no marker shows
     it), crash reporting on, a join with an empty writer, a hub path under a
     regular file
 11. stub-based (the stub's pre and filter hooks): a bounce that never drops
     the connection; gate 7 before the hub's index; localchanged one short;
     gate 9 with a file changed at the same size and a trashcan file gone; an
     edit on bigfed during the switch's watch (real, with the hub's link
     paused); a hub view a sequence behind; one good round and then none
  4 also refuses a re-run on a folder at maxConflicts 0, and on a hub folder
  at minDiskFree 0; 8 also refuses two different passwords
  and over every run: no password in any line printed, none and no API key
  in any ssh command line

    python3 -I case_addfolder.py ROOT     (ROOT: an empty directory in the sandbox)
"""
import glob
import hashlib
import json
import os
import re
import secrets
import shlex
import shutil
import signal
import subprocess
import sys
import threading
import time
import urllib.error

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402

TOOL = os.path.realpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "bin",
                                     "syncthing-addfolder"))
TOOL = os.environ.get("SYNCTHING_ADDFOLDER", TOOL)   # another copy, for the mutation runs
ALPHA = "abcdefghjkmnopqrstuvwxyz23456789"
C = rig.Checks()

STUB = r"""#!/usr/bin/env bash
# stub ssh for case_addfolder: the host's sandbox, or ssh's own 255
printf '%s\n' "$*" >> "$STUB_DIR/ssh-argv.log"
host=""
while [ $# -gt 0 ]; do
  case "$1" in -o|-p|-i|-l|-F) shift 2 ;; -*) shift ;; *) host=$1; shift; break ;; esac
done
printf '%s %s\n' "$host" "${5:-}" >> "$STUB_DIR/ssh.log"
d="$STUB_DIR/hosts/$host"
[ -f "$d/env" ] || { echo "ssh: Could not resolve hostname $host: Name or service not known" >&2; exit 255; }
[ -e "$d/down" ] && { echo "ssh: connect to host $host port 22: Connection timed out" >&2; exit 255; }
. "$d/env"
op="${5:-}"
# hooks a sub-case installs for readings real instances cannot be made to give:
# pre runs before the operation, filter rewrites its JSON answer
[ -x "$d/pre" ] && "$d/pre" "$op"
if [ -x "$d/filter" ]; then
  bash -c "$*" | "$d/filter" "$op"
  exit "${PIPESTATUS[0]}"
fi
exec bash -c "$*"
"""


def new_id():
    return "-".join("".join(secrets.choice(ALPHA) for _ in range(5)) for _ in range(2))


class Bench:
    def __init__(self, root):
        self.root = root
        self.r = rig.Rig(os.path.join(root, "rig"))
        self.stub = os.path.join(root, "stub")
        os.makedirs(os.path.join(self.stub, "hosts"), exist_ok=True)
        with open(os.path.join(self.stub, "ssh"), "w") as f:
            f.write(STUB)
        os.chmod(os.path.join(self.stub, "ssh"), 0o755)
        self.gitcfg = {}
        self.outputs = []      # every line the tool printed, for the secrets check
        self.typed = []        # passwords typed on the terminal

    def setup(self):
        r = self.r
        t0 = time.time()
        r.trio(direct=True, names={"A": "bigfed", "B": "fedxps", "H": "nousowl"})
        C.note("trio up with the direct link in %.1f s" % (time.time() - t0))
        self.gitcfg["A"] = rig.write_gitconfig(os.path.join(self.root, "gitconfig-A"), "[gsync]\n\trole = writer\n")
        self.gitcfg["B"] = rig.write_gitconfig(os.path.join(self.root, "gitconfig-B"),
                                               rig.READER_GUARD + "[gsync]\n\trole = reader\n")
        self.gitcfg["H"] = rig.write_gitconfig(os.path.join(self.root, "gitconfig-H"))
        for host, n in (("nousowl", "H"), ("nousowl-vpn", "H"), ("fedxps", "B"), ("fedxps-vpn", "B")):
            d = os.path.join(self.stub, "hosts", host)
            os.makedirs(d, exist_ok=True)
            with open(os.path.join(d, "env"), "w") as f:
                f.write("export HOME=%s SYNC_CHECK_CONFIG=%s GIT_CONFIG_GLOBAL=%s GIT_CONFIG_NOSYSTEM=1\n" % (
                    shlex.quote(r[n].home), shlex.quote(r[n].config_xml), shlex.quote(self.gitcfg[n])))
                f.write("unset XDG_CONFIG_HOME XDG_STATE_HOME GIT_OPTIONAL_LOCKS\n")

    def env(self):
        e = {k: v for k, v in os.environ.items() if not k.startswith(("XDG_", "GIT_", "SYNCTHING_ADDFOLDER"))}
        e.update(HOME=self.r["A"].home, SYNC_CHECK_CONFIG=self.r["A"].config_xml, STUB_DIR=self.stub,
                 PATH=self.stub + os.pathsep + os.environ.get("PATH", ""),
                 GIT_CONFIG_GLOBAL=self.gitcfg["A"], GIT_CONFIG_NOSYSTEM="1",
                 SYNCTHING_ADDFOLDER_POLL="0.5", SYNCTHING_ADDFOLDER_HOLD="1", SYNCTHING_ADDFOLDER_WATCH="6")
        return e

    def set_git(self, n, text):
        with open(self.gitcfg[n], "w") as f:
            f.write(text)

    def hook(self, host, filt=None, pre=None):
        """Install the stub's hooks for host: `filt` rewrites the JSON answer
        `d` of operation `op`, `pre` runs before it; both Python bodies."""
        d = os.path.join(self.stub, "hosts", host)
        for name, body, tail in (("filter", filt, True), ("pre", pre, False)):
            if body is None:
                continue
            text = HOOK_HEAD % name + (FILTER_HEAD if tail else "") + body + (FILTER_TAIL if tail else "")
            with open(os.path.join(d, name), "w") as f:
                f.write(text)
            os.chmod(os.path.join(d, name), 0o755)

    def unhook(self, host):
        d = os.path.join(self.stub, "hosts", host)
        for name in os.listdir(d):
            if name in ("filter", "pre") or name.endswith(".count"):
                os.remove(os.path.join(d, name))

    def tool(self, args, kill_on=None, timeout=300, label="", env_extra=None, kill_delay=0.0, act_on=None):
        """Run the tool; every line shown as a reading. kill_on: a pattern on
        whose first line SIGINT is sent kill_delay seconds later (his Ctrl-C).
        act_on: (pattern, function), the function run on that pattern's first
        line while the tool goes on. (rc, text, seconds)."""
        C.note("$ syncthing-addfolder %s" % " ".join(shlex.quote(a) for a in args))
        t0 = time.time()
        env = self.env()
        env.update(env_extra or {})
        p = subprocess.Popen([TOOL] + args, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             stdin=subprocess.DEVNULL, text=True, cwd=self.root, start_new_session=True)
        lines = []
        killed = False
        deadline = t0 + timeout
        for ln in p.stdout:
            ln = ln.rstrip("\n")
            lines.append(ln)
            C.note("  " + ln)
            if act_on and re.search(act_on[0], ln):
                threading.Thread(target=act_on[1]).start()
                C.note("(acting on this line)")
                act_on = None
            if kill_on and not killed and re.search(kill_on, ln):
                threading.Timer(kill_delay, p.send_signal, (signal.SIGINT,)).start()
                killed = True
                C.note("(SIGINT %.1f s after this line)" % kill_delay)
            if time.time() > deadline:
                p.kill()
                C.note("(killed after %d s)" % timeout)
                break
        rc = p.wait()
        secs = time.time() - t0
        self.outputs.append("\n".join(lines))
        C.note("rc %d after %.1f s%s" % (rc, secs, (" (" + label + ")") if label else ""))
        return rc, "\n".join(lines), secs

    # --- readings -------------------------------------------------------------------
    def folder(self, n, fid):
        try:
            return self.r[n].api("GET", "config/folders/" + fid)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            raise

    def devices(self, n, fid):
        """{device name: password set?} of n's folder, the password itself never kept."""
        f = self.folder(n, fid)
        names = {self.r[x].device_id: self.r[x].device_name for x in ("A", "B", "H")}
        return {names.get(d["deviceID"], d["deviceID"][:7]): bool(d.get("encryptionPassword")) for d in f["devices"]}

    def config_hashes(self):
        out = {}
        for n in ("A", "B", "H"):
            with open(self.r[n].config_xml, "rb") as f:
                out[n] = hashlib.sha256(f.read()).hexdigest()
        return out

    def pending(self, n, fid):
        p = self.r[n].api("GET", "cluster/pending/folders") or {}
        return fid in p

    def untouched(self, what, fid, paths):
        held = [n for n in ("A", "B", "H") if self.folder(n, fid) is not None]
        C.check("%s: no instance holds the folder" % what, not held, held)
        C.check("%s: the hub's directory absent" % what, not os.path.exists(paths["H"]), paths["H"])
        marks = [n for n in ("A", "B") if os.path.exists(os.path.join(paths[n], ".stfolder"))]
        C.check("%s: no marker made on either workstation" % what, not marks, marks)
        pend = [n for n in ("B", "H") if self.pending(n, fid)]
        C.check("%s: nothing pending on fedxps or the hub" % what, not pend, pend)

    def started_after(self, n, peer, t, wait=10):
        """The connection's startedAt, once it reads a real time (it flips
        between the zero time and the real one), at or after t."""
        t0 = time.time()
        last = ""
        while time.time() - t0 < wait:
            c = self.r[n].api("GET", "system/connections")["connections"].get(self.r[peer].device_id, {})
            s = c.get("startedAt") or ""
            if s and not s.startswith("0001-"):
                last = s
                break
            time.sleep(0.25)
        if not last:
            return False, "no real startedAt within %d s" % wait
        when = time.mktime(time.strptime(last[:19], "%Y-%m-%dT%H:%M:%S"))
        return when >= int(t), "startedAt %s, the run began %s" % (last, time.strftime("%H:%M:%S", time.localtime(t)))

    def views_all(self, fid, link=True):
        v = self.r.views(fid)
        if link:
            for a, b in (("A", "B"), ("B", "A")):
                c = self.r.completion(a, fid, b)
                v["%s->%s" % (a, b)] = {k: c.get(k) for k in ("completion", "needItems", "needDeletes", "remoteState")}
        return v

    def ssh_log(self):
        try:
            with open(os.path.join(self.stub, "ssh.log")) as f:
                return f.read().splitlines()
        except OSError:
            return []

    def clear_log(self):
        open(os.path.join(self.stub, "ssh.log"), "w").close()

    def paths(self, fid, hub=None):
        return {"A": self.r.path("A", fid), "B": self.r.path("B", fid), "H": hub or self.r.path("H", fid)}

    def args(self, fid, label, paths, *extra):
        return [fid, label, paths["A"], paths["B"], paths["H"]] + list(extra)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def plain_tree(base, tag):
    """A small tree: nested files, a symlink, 200 KB of random bytes."""
    write(os.path.join(base, "plain-%s-alpha.txt" % tag), "alpha %s\n" % tag)
    write(os.path.join(base, "docs", "plain-%s-beta.md" % tag), ("beta %s\n" % tag) * 40)
    with open(os.path.join(base, "docs", "blob.bin"), "wb") as f:
        f.write(os.urandom(200000))
    os.symlink("plain-%s-alpha.txt" % tag, os.path.join(base, "link-to-alpha"))
    return ["plain-%s-alpha.txt" % tag, "plain-%s-beta.md" % tag, "docs"]


def inode(p):
    """The marker's identity: its inode and its folder file's bytes, whose
    `created:` line a re-creation would rewrite. (ctime moves whenever
    Syncthing writes into the marker, the hub's token file among them.)"""
    out = [os.stat(p).st_ino]
    for f in sorted(glob.glob(os.path.join(p, "syncthing-folder-*.txt"))):
        out.append((os.path.basename(f), rig.sha256_file(f)))
    return tuple(out)


def do_lines(text):
    return [l.split("] ", 1)[1] for l in text.splitlines() if "[ DO ]" in l]


# =============================================================================
def case_no_password(B):
    C.note("== 1. no cluster password on bigfed yet")
    fid = new_id()
    P = B.paths(fid)
    plain_tree(P["A"], "nopw")
    rc, out, _ = B.tool(B.args(fid, "nopw", P, "--yes"))
    C.check("no folder names the hub: exit 2, asking for --hub", rc == 2 and "--hub NAME" in out, rc)
    rc, out, _ = B.tool(B.args(fid, "nopw", P, "--hub", "nousowl", "--yes"))
    C.check("with --hub and --yes: refused for want of a terminal for the password (exit 1)",
            rc == 1 and "needs the password typed on a terminal" in out, rc)
    B.untouched("no password", fid, P)


def case_refusals(B):
    C.note("== 2. refusals")
    # (a) a nested marker under the reader's path
    fid = new_id()
    P = B.paths(fid)
    plain_tree(P["A"], "nest")
    plain_tree(P["B"], "nest")
    os.makedirs(os.path.join(P["B"], "docs", "inner", ".stfolder"))
    trash = os.path.join(B.root, "trash-" + fid)
    rc, out, _ = B.tool(B.args(fid, "nest", P, "--trash", trash, "--yes"))
    C.check("a .stfolder under the reader's path: exit 1, the marker named",
            rc == 1 and re.search(r"\[FAIL\] fedxps: 1 \.stfolder marker\(s\) under .*docs/inner/\.stfolder", out), rc)
    C.check("... and nothing else refused", out.count("[FAIL]") == 1, [l for l in out.splitlines() if "[FAIL]" in l])
    B.untouched("nested marker", fid, P)
    C.check("nested marker: no trashcan made", not os.path.exists(trash))
    # (b) an existing hub directory
    fid = new_id()
    P = B.paths(fid)
    plain_tree(P["A"], "hubdir")
    os.makedirs(P["H"])
    rc, out, _ = B.tool(B.args(fid, "hubdir", P, "--yes"))
    C.check("an existing hub directory: exit 1, hub-3 named",
            rc == 1 and re.search(r"\[FAIL\] nousowl: .* exists; a new hub folder gets a new, empty directory \(hub-3\)", out), rc)
    C.check("... and nothing else refused", out.count("[FAIL]") == 1, [l for l in out.splitlines() if "[FAIL]" in l])
    held = [n for n in ("A", "B", "H") if B.folder(n, fid) is not None]
    C.check("existing hub directory: no instance holds the folder", not held, held)
    C.check("existing hub directory: left as it was, empty", os.listdir(P["H"]) == [])
    # (c) a hub path under ~/sync where no volume is mounted
    fid = new_id()
    hub = os.path.join(B.r["H"].home, "sync", fid)
    os.makedirs(os.path.dirname(hub), exist_ok=True)
    P = B.paths(fid, hub=hub)
    plain_tree(P["A"], "vol")
    rc, out, _ = B.tool(B.args(fid, "vol", P, "--yes"))
    C.check("a hub path under ~/sync on no volume of its own: exit 1, the mount named, its fix printed",
            rc == 1 and "the sync volume is not mounted" in out and "sudo systemctl start" in out, rc)
    B.untouched("no volume", fid, P)
    # (d) a repository at the writer's root that does not ignore the marker:
    # the rig's git config carries the exclude, as the real machines' do, so
    # this run gets one without it
    fid = new_id()
    P = B.paths(fid)
    rig.seed_repo(P["A"], rig.git_env(B.gitcfg["A"]))
    rc, out, _ = B.tool(B.args(fid, "rootrepo", P, "--dry-run"))
    C.check("a repository at the root that ignores .stfolder/ passes that check (dry run)",
            rc == 0 and "the repository at %s ignores .stfolder/" % P["A"] in out, rc)
    bare = os.path.join(B.root, "gitconfig-A-noexclude")
    write(bare, "[user]\n\tname = Rig\n\temail = rig@example.invalid\n[gsync]\n\trole = writer\n")
    rc, out, _ = B.tool(B.args(fid, "rootrepo", P, "--yes"), env_extra={"GIT_CONFIG_GLOBAL": bare})
    C.check("a repository at the root without .stfolder/ ignored: exit 1, the exclude named",
            rc == 1 and "does not ignore .stfolder/" in out and "org/claude-config/git/ignore" in out, rc)
    B.untouched("repository at the root", fid, P)


def case_dry_run(B):
    C.note("== 3. --dry-run, fedxps's first door down")
    fid = new_id()
    P = B.paths(fid)
    plain_tree(P["A"], "dry")
    before = B.config_hashes()
    down = os.path.join(B.stub, "hosts", "fedxps", "down")
    open(down, "w").close()
    B.clear_log()
    rc, out, _ = B.tool(B.args(fid, "dry", P, "--dry-run"))
    os.remove(down)
    C.check("dry run: exit 0, the plan printed, nothing written said",
            rc == 0 and "[PLAN]" in out and "nothing was written" in out, rc)
    C.check("dry run: config.xml byte-identical on all three", B.config_hashes() == before)
    B.untouched("dry run", fid, P)
    C.check("dry run: the reader's path still absent", not os.path.exists(P["B"]))
    log = B.ssh_log()
    C.check("dry run: fedxps tried first, fedxps-vpn answered and was used after",
            "fedxps probe" in log and "fedxps-vpn probe" in log and "over ssh fedxps-vpn" in out, log)
    C.check("dry run: no write operation reached either remote",
            not [l for l in log if l.split()[-1:] and l.split()[-1] in ("post", "patch", "share", "bounce", "revert", "delete")], log)


def case_fresh(B):
    C.note("== 4. fresh, end to end")
    r = B.r
    fid = new_id()
    P = B.paths(fid)
    names = plain_tree(P["A"], "fresh")
    logf = os.path.join(B.root, "fresh.log")
    t_run = time.time()
    rc, out, secs = B.tool(B.args(fid, "fresh", P, "--yes", "--log", logf), label="fresh")
    C.check("fresh: exit 0, done", rc == 0 and "] done: " in out, rc)
    C.note("fresh: the writes in order: " + " / ".join(do_lines(out)))
    ma, mb = r.manifest("A", fid), r.manifest("B", fid)
    C.check("fresh: A and B equal by manifest (%d entries)" % len(ma), ma == mb and len(ma) >= 5, r.manifest_diff(ma, mb))
    hub_paths = list(r.manifest("H", fid))
    leaks = [p for p in hub_paths if any(n in p for n in names)]
    content = []
    for p in r.files("H", fid):
        with open(r.path("H", fid, p), "rb") as f:
            b = f.read()
        if b"alpha fresh" in b or b"beta fresh" in b:
            content.append(p)
    C.check("fresh: the hub holds ciphertext only (no plain name, no plain content)", not leaks and not content
            and len(hub_paths) > 3, (leaks, content))
    C.check("fresh: maxConflicts 10 on A, B and H",
            all((B.folder(n, fid) or {}).get("maxConflicts") == 10 for n in ("A", "B", "H")),
            {n: (B.folder(n, fid) or {}).get("maxConflicts") for n in ("A", "B", "H")})
    hf = r.folder_config("H", fid)
    C.check("fresh: the hub receiveencrypted, staggered maxAge 31536000, minDiskFree 1 %",
            hf["type"] == "receiveencrypted" and hf["versioning"]["type"] == "staggered"
            and hf["versioning"]["params"].get("maxAge") == "31536000" and hf["minDiskFree"] == {"value": 1, "unit": "%"},
            (hf["type"], hf["versioning"], hf["minDiskFree"]))
    C.check("fresh: A and B sendreceive, versioning none, watcher 2 s, rescan 3600 s",
            all(r.folder_config(n, fid)["type"] == "sendreceive" and not r.folder_config(n, fid)["versioning"]["type"]
                and r.folder_config(n, fid)["fsWatcherDelayS"] == 2 and r.folder_config(n, fid)["rescanIntervalS"] == 3600
                for n in ("A", "B")))
    C.check("fresh: A's devices bigfed, nousowl (password), fedxps", B.devices("A", fid) ==
            {"bigfed": False, "nousowl": True, "fedxps": False}, B.devices("A", fid))
    C.check("fresh: B's devices fedxps, nousowl (password), bigfed", B.devices("B", fid) ==
            {"fedxps": False, "nousowl": True, "bigfed": False}, B.devices("B", fid))
    C.check("fresh: H's devices nousowl, bigfed, fedxps, no password", B.devices("H", fid) ==
            {"nousowl": False, "bigfed": False, "fedxps": False}, B.devices("H", fid))
    for n in ("A", "B"):
        ok, why = B.started_after(n, "H", t_run)
        C.check("fresh: %s's connection to the hub restarted during the run (the bounce)" % n, ok, why)
    C.check("fresh: the bounce seen by the tool on both workstations",
            len(re.findall(r"the connection to nousowl dropped [0-9.]+ s after the pause", out)) == 2, out.count("dropped"))
    v = B.views_all(fid)
    C.check("fresh: every view 100 with nothing needed, the link's too", rig.Rig.views_clear(v), v)
    with open(logf) as f:
        logged = f.read().splitlines()
    C.check("fresh: --log holds every line printed", logged == out.splitlines(), (len(logged), len(out.splitlines())))
    C.note("fresh: %.1f s" % secs)

    marks = {n: inode(r.path(n, fid, ".stfolder")) for n in ("A", "B", "H")}
    seq = {n: r.status(n, fid)["sequence"] for n in ("A", "B", "H")}
    rc, out2, _ = B.tool(B.args(fid, "fresh", P, "--yes"), label="re-run, complete")
    C.check("fresh re-run: exit 0, done", rc == 0 and "] done: " in out2, rc)
    C.check("fresh re-run: no write at all (verified, no POST, no bounce, no PATCH)", not do_lines(out2), do_lines(out2))
    after = {n: inode(r.path(n, fid, ".stfolder")) for n in ("A", "B", "H")}
    C.check("fresh re-run: the three markers untouched (inode, folder file)", marks == after, (marks, after))
    C.check("fresh re-run: the sequences unchanged", seq == {n: r.status(n, fid)["sequence"] for n in ("A", "B", "H")})

    r.patch_folder("A", fid, maxConflicts=0)
    rc, out6, _ = B.tool(B.args(fid, "fresh", P, "--yes"), label="re-run, bigfed's maxConflicts 0")
    r.patch_folder("A", fid, maxConflicts=10)
    C.check("a re-run on bigfed's folder at maxConflicts 0: exit 1, held differently, no write",
            rc == 1 and re.search(r"\[FAIL\] bigfed: holds it differently: maxConflicts 0", out6) and not do_lines(out6), rc)
    r.patch_folder("H", fid, minDiskFree={"value": 0, "unit": "%"})
    rc, out7, _ = B.tool(B.args(fid, "fresh", P, "--yes"), label="re-run, the hub's minDiskFree 0")
    r.patch_folder("H", fid, minDiskFree={"value": 1, "unit": "%"})
    C.check("a re-run on the hub's folder with minDiskFree 0: exit 1, held differently, no write",
            rc == 1 and re.search(r"\[FAIL\] nousowl: holds it differently: minDiskFree", out7) and not do_lines(out7), rc)
    rc, out3, _ = B.tool(B.args(fid, "other-label", P, "--yes"), label="re-run, another label")
    C.check("a re-run with another label: exit 1, held differently", rc == 1 and "holds it differently" in out3, rc)
    C.check("... and the undo printed", "syncthing-addfolder --undo %s" % fid in out3)

    rc, out4, _ = B.tool(["--undo", fid, "wrong-label", "--yes"], label="undo, wrong label")
    C.check("--undo with a label the folder does not carry: exit 1, nothing removed",
            rc == 1 and all(B.folder(n, fid) is not None for n in ("A", "B", "H")), rc)
    before = {n: r.manifest(n, fid) for n in ("A", "B")}
    rc, out5, _ = B.tool(["--undo", fid, "fresh", "--yes"], label="undo")
    C.check("--undo: exit 0", rc == 0 and "undone" in out5, rc)
    C.check("--undo: the hub first, then bigfed, then fedxps",
            [l.split(":")[0] for l in do_lines(out5)] == ["nousowl", "bigfed", "fedxps"], do_lines(out5))
    C.check("--undo: no instance holds the folder", all(B.folder(n, fid) is None for n in ("A", "B", "H")))
    C.check("--undo: every workstation file stays", all(r.manifest(n, fid) == before[n] for n in ("A", "B")))
    C.check("--undo: the hub keeps its blobs and a renamed marker",
            glob.glob(os.path.join(P["H"], ".stfolder.removed-*")) and len(os.listdir(P["H"])) > 2, os.listdir(P["H"]))
    C.check("--undo: no marker left at either workstation's root",
            not any(os.path.exists(r.path(n, fid, ".stfolder")) for n in ("A", "B")))


def case_half_made(B):
    C.note("== 5. half-made: Ctrl-C during bigfed's bounce of the hub, then the re-run (--hub-only)")
    r = B.r
    fid = new_id()
    P = B.paths(fid)
    plain_tree(P["A"], "half")
    rc, out, _ = B.tool(B.args(fid, "half", P, "--hub-only", "--yes"), kill_on=r"\] bigfed: bounce of nousowl",
                        kill_delay=0.4, label="interrupted")
    C.check("interrupted: exit 1, STOP, the undo printed",
            rc == 1 and "[STOP] interrupted" in out and "syncthing-addfolder --undo %s" % fid in out, rc)
    C.check("interrupted inside the bounce's hold: the tool says its resume answered",
            "the bounce under way here was cut short; its resume answered 200" in out)
    held = {n: B.folder(n, fid) is not None for n in ("A", "B", "H")}
    C.check("interrupted: bigfed and the hub hold the folder, fedxps does not", held == {"A": True, "H": True, "B": False}, held)
    C.check("interrupted: the hub device not left paused on bigfed",
            r["A"].api("GET", "config/devices/" + r["H"].device_id)["paused"] is False)
    marks = {n: inode(r.path(n, fid, ".stfolder")) for n in ("A", "H")}
    r.wait_connected([("A", "H")])
    rc, out2, _ = B.tool(B.args(fid, "half", P, "--hub-only", "--yes"), label="re-run, half-made")
    C.check("re-run: exit 0, done", rc == 0 and "] done: " in out2, rc)
    C.check("re-run: bigfed and the hub verified, not re-created",
            "[SKIP] bigfed: holds it as specified" in out2 and "[SKIP] nousowl: holds it as specified" in out2)
    posts = [l for l in do_lines(out2) if "POST /rest/config/folders" in l]
    C.check("re-run: one POST, fedxps's", len(posts) == 1 and posts[0].startswith("fedxps:"), posts)
    after = {n: inode(r.path(n, fid, ".stfolder")) for n in ("A", "H")}
    C.check("re-run: bigfed's and the hub's markers untouched (inode, folder file)", marks == after, (marks, after))
    ma, mb = r.manifest("A", fid), r.manifest("B", fid)
    C.check("re-run: A and B equal by manifest", ma == mb, r.manifest_diff(ma, mb))
    C.check("--hub-only: no direct link in either device list",
            B.devices("A", fid) == {"bigfed": False, "nousowl": True} and B.devices("B", fid) == {"fedxps": False, "nousowl": True},
            (B.devices("A", fid), B.devices("B", fid)))
    v = r.views(fid)
    C.check("re-run: every hub view 100 with nothing needed", rig.Rig.views_clear(v), v)


def join_trees(B, fid, outside=None):
    """A's tree with a repository of loose objects; B's a copy whose
    repository is gc'd (packs, packed-refs) with .git/description edited;
    `outside` adds a file only B has, outside .git."""
    r = B.r
    P = B.paths(fid)
    plain_tree(P["A"], "join")
    envA = rig.git_env(B.gitcfg["A"])
    rig.seed_repo(os.path.join(P["A"], "repo"), envA)
    shutil.copytree(P["A"], P["B"], symlinks=True)
    envB = rig.git_env(B.gitcfg["B"])
    rig.git(os.path.join(P["B"], "repo"), ["gc", "-q"], envB, check=True)
    with open(os.path.join(P["B"], "repo", ".git", "description"), "a") as f:
        f.write("edited on fedxps\n")
    if outside:
        write(os.path.join(P["B"], outside), "only on fedxps\n")
    ma = r.manifest("A", fid)
    mb = {k: v for k, v in r.manifest("B", fid).items()}
    only_b = sorted(k for k in mb if k not in ma and mb[k] != "dir")
    differ = sorted(k for k in mb if k in ma and ma[k] != mb[k] and mb[k] != "dir")
    head = rig.git(os.path.join(P["A"], "repo"), ["rev-parse", "HEAD"], envA).stdout.strip()
    return P, ma, mb, only_b, differ, head


def listed(out):
    """The paths the tool printed under its localchanged reading."""
    items, on = [], False
    for l in out.splitlines():
        if "GET /rest/db/localchanged" in l:
            on = True
            continue
        if on:
            m = re.match(r"^\s{20}(?:deleted )?(file|directory|symlink)\s+(.*)$", l)
            if m:
                items.append(m.group(2))
                continue
            on = False
    return items


def case_join(B):
    C.note("== 6. join, end to end")
    r = B.r
    fid = new_id()
    P, ma, mb, only_b, differ, head = join_trees(B, fid)
    C.note("B-only paths: %s; differing: %s" % (only_b, differ))
    C.check("join setup: B's .git differs from A's (packs and the edited description)",
            only_b and differ and all(".git" in p.split("/") for p in only_b + differ), (only_b, differ))
    trash = os.path.join(B.root, "trash-join-" + fid)
    rc, out, secs = B.tool(B.args(fid, "join", P, "--trash", trash, "--yes"), label="join")
    C.check("join: exit 0, done", rc == 0 and "] done: " in out, rc)
    C.note("join: the writes in order: " + " / ".join(do_lines(out)))
    items = listed(out)
    C.note("join: localchanged listed %d: %s" % (len(items), items))
    C.check("join: every B-only .git path listed by localchanged", all(p in items for p in only_b),
            [p for p in only_b if p not in items])
    C.check("join: every differing .git path listed as a conflict copy",
            all(any(i.startswith(p + ".sync-conflict-") or i.startswith(os.path.splitext(p)[0] + ".sync-conflict-")
                    for i in items) for p in differ), (differ, items))
    C.check("join: every listed path lies under .git", items and all(".git" in i.split("/") for i in items), items)
    tfiles = sorted(os.path.relpath(os.path.join(dp, f), trash) for dp, _, fs in os.walk(trash) for f in fs)
    C.check("join: every listed file found in the trashcan", all(i in tfiles for i in items), (items, tfiles))
    C.check("join: B's own copies kept there byte for byte",
            all(rig.sha256_file(os.path.join(trash, p)) == mb[p] for p in only_b), only_b)
    ma2, mb2 = r.manifest("A", fid), r.manifest("B", fid)
    C.check("join: A and B equal by manifest (%d entries), A's tree unchanged" % len(ma2), ma2 == mb2 and ma2 == ma,
            r.manifest_diff(ma2, mb2))
    m = re.search(r"sequences before the switch: nousowl (\d+)", out)
    m2 = re.search(r"sequences after [0-9.]+ s: nousowl (\d+)", out)
    C.check("join: the hub's sequence the same before and after the switch (the tool's reading)",
            m and m2 and m.group(1) == m2.group(1), (m and m.group(1), m2 and m2.group(1)))
    C.check("join: the hub's sequence now still the one read before the switch",
            m and str(r.status("H", fid)["sequence"]) == m.group(1), (m and m.group(1), r.status("H", fid)["sequence"]))
    envB = rig.git_env(B.gitcfg["B"], optional_locks=0)
    fk = rig.git(os.path.join(P["B"], "repo"), ["fsck", "--connectivity-only"], envB)
    C.check("join: git fsck clean on B under the guard", fk.returncode == 0, fk.stderr[-300:])
    C.check("join: B's HEAD is A's", rig.git(os.path.join(P["B"], "repo"), ["rev-parse", "HEAD"], envB).stdout.strip() == head)
    bf = r.folder_config("B", fid)
    C.check("join: B sendreceive with versioning none at the end", bf["type"] == "sendreceive" and not bf["versioning"]["type"],
            (bf["type"], bf["versioning"]))
    C.check("join: the link shared both ways after the switch, the hub's entries kept",
            B.devices("A", fid) == {"bigfed": False, "nousowl": True, "fedxps": False}
            and B.devices("B", fid) == {"fedxps": False, "nousowl": True, "bigfed": False},
            (B.devices("A", fid), B.devices("B", fid)))
    C.check("join: maxConflicts 10 on A, B and H",
            all((B.folder(n, fid) or {}).get("maxConflicts") == 10 for n in ("A", "B", "H")))
    v = B.views_all(fid)
    C.check("join: every view 100 with nothing needed, the link's too", rig.Rig.views_clear(v), v)
    C.check("join: the trashcan left in place", os.path.isdir(trash))
    order = do_lines(out)
    want = ["bigfed: POST", "nousowl: POST", "bigfed: bounce", "fedxps: POST", "fedxps: bounce", "fedxps: POST /rest/db/revert",
            "fedxps: PATCH /rest/config/folders/%s type sendreceive" % fid, "fedxps: PATCH /rest/config/folders/%s versioning none" % fid,
            "bigfed: PATCH /rest/config/folders/%s devices" % fid, "fedxps: PATCH /rest/config/folders/%s devices" % fid]
    C.check("join: the writes in mig-3's order", len(order) == len(want) and all(o.startswith(w) for o, w in zip(order, want)),
            order)
    C.note("join: %.1f s" % secs)


def case_join_outside(B):
    C.note("== 7. join stopping on a path outside .git, then --allow-outside")
    r = B.r
    fid = new_id()
    P, ma, mb, only_b, differ, head = join_trees(B, fid, outside="notes/only-on-fedxps.txt")
    trash = os.path.join(B.root, "trash-out-" + fid)
    rc, out, _ = B.tool(B.args(fid, "joinout", P, "--trash", trash, "--yes"), label="join, outside .git")
    C.check("outside: exit 1, the path named, the resume with --allow-outside printed",
            rc == 1 and "notes/only-on-fedxps.txt" in out and "--allow-outside" in out and "[STOP]" in out, rc)
    C.check("outside: every listed path printed, the .git ones too", all(p in listed(out) for p in only_b), listed(out))
    bf = r.folder_config("B", fid)
    C.check("outside: fedxps holds it receive-only, nothing reverted",
            bf["type"] == "receiveonly" and os.path.exists(os.path.join(P["B"], "notes", "only-on-fedxps.txt"))
            and r.status("B", fid)["receiveOnlyTotalItems"] > 0, (bf["type"], r.status("B", fid)["receiveOnlyTotalItems"]))
    C.check("outside: the trashcan empty", not os.path.exists(trash) or not os.listdir(trash))
    rc, out2, _ = B.tool(B.args(fid, "joinout", P, "--trash", trash, "--yes", "--allow-outside"), label="join, resumed")
    C.check("resumed: exit 0, done", rc == 0 and "] done: " in out2, rc)
    C.check("resumed: bigfed, the hub and fedxps verified, not re-created",
            not [l for l in do_lines(out2) if "POST /rest/config/folders" in l], do_lines(out2))
    C.check("resumed: the outside file in the trashcan, gone from fedxps's tree",
            os.path.exists(os.path.join(trash, "notes", "only-on-fedxps.txt"))
            and not os.path.exists(os.path.join(P["B"], "notes", "only-on-fedxps.txt")))
    ma2, mb2 = r.manifest("A", fid), r.manifest("B", fid)
    C.check("resumed: A and B equal by manifest", ma2 == mb2, r.manifest_diff(ma2, mb2))
    v = B.views_all(fid)
    C.check("resumed: every view 100 with nothing needed", rig.Rig.views_clear(v), v)


def strip_folders(B, n):
    """Remove every folder from instance n's configuration: the rebuild's
    workstation, holding no cluster password."""
    for f in B.r[n].api("GET", "config/folders"):
        B.r[n].api("DELETE", "config/folders/" + f["id"])
    return not own_passwords(B, n)


def own_passwords(B, n):
    """The distinct passwords in n's config.xml, held here, never printed."""
    import xml.etree.ElementTree as ET
    root = ET.parse(B.r[n].config_xml).getroot()
    return {d.findtext("encryptionPassword") for f in root.findall("folder") for d in f.findall("device")
            if (d.findtext("encryptionPassword") or "").strip()}


def pty_tool(B, args, answers, timeout=240):
    """The tool on a pseudo-terminal, as he runs it: each (pattern, reply)
    answered when its pattern appears. (rc, text)."""
    import pty
    import select
    C.note("$ syncthing-addfolder %s   (on a terminal)" % " ".join(shlex.quote(a) for a in args))
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(B.root)
        os.execve(TOOL, [TOOL] + args, B.env())
    buf, seen, t0 = b"", 0, time.time()
    answers = list(answers)
    while time.time() - t0 < timeout:
        r, _, _ = select.select([fd], [], [], 0.5)
        if r:
            try:
                chunk = os.read(fd, 4096)
            except OSError:
                break
            if not chunk:
                break
            buf += chunk
        if answers and re.search(answers[0][0], buf[seen:].decode("utf-8", "replace")):
            seen = len(buf)
            os.write(fd, answers.pop(0)[1].encode())
    _, status = os.waitpid(pid, 0)
    rc = os.waitstatus_to_exitcode(status)
    text = buf.decode("utf-8", "replace").replace("\r\n", "\n")
    for ln in text.splitlines():
        C.note("  " + ln)
    C.note("rc %d after %.1f s (on a terminal)" % (rc, time.time() - t0))
    B.outputs.append(text)
    return rc, text


def case_rebuild(B):
    C.note("== 8. the password on a rebuilt cluster: a reader holding none; then neither workstation")
    r = B.r
    # (a) fedxps rebuilt: it holds no encrypted folder, bigfed's password goes in the program text
    C.check("fedxps stripped of every folder: no password in its config.xml", strip_folders(B, "B"))
    fid = new_id()
    P = B.paths(fid)
    plain_tree(P["A"], "rebuild-a")
    # AF16: fedxps holding one password, not bigfed's (a paused folder at an absent path carries it)
    r["B"].api("POST", "config/folders", {"id": "pw-" + fid, "label": "pw-" + fid, "path": os.path.join(r["B"].data, "pw-" + fid),
                                          "type": "sendreceive", "paused": True,
                                          "devices": [{"deviceID": r["B"].device_id},
                                                      {"deviceID": r["H"].device_id, "encryptionPassword": "a-different-" + secrets.token_hex(8)}]})
    rc, out, _ = B.tool(B.args(fid, "rebuild-a", P, "--dry-run"), label="the two passwords differ")
    r["B"].api("DELETE", "config/folders/pw-" + fid)
    C.check("fedxps holding a password that is not bigfed's: exit 1, the mismatch named",
            rc == 1 and "[FAIL] fedxps: its cluster password differs from bigfed's" in out, rc)
    rc, out, _ = B.tool(B.args(fid, "rebuild-a", P, "--yes", "--hub-only"), label="reader without a password")
    C.check("reader without a password: exit 0, done, its note printed",
            rc == 0 and "] done: " in out and "reaches it inside the program text" in out, rc)
    C.check("reader without a password: fedxps now holds bigfed's one password",
            own_passwords(B, "B") == own_passwords(B, "A") and len(own_passwords(B, "A")) == 1)
    ma, mb = r.manifest("A", fid), r.manifest("B", fid)
    C.check("reader without a password: A and B equal by manifest", ma == mb, r.manifest_diff(ma, mb))
    # (b) the cluster rebuilt: neither workstation holds a password; asked once, on the terminal
    stripped = [strip_folders(B, n) for n in ("A", "B")]
    C.check("bigfed and fedxps stripped of every folder: no password in either config.xml", all(stripped), stripped)
    fid = new_id()
    P = B.paths(fid)
    plain_tree(P["A"], "rebuild-b")
    args = B.args(fid, "rebuild-b", P, "--hub", "nousowl", "--hub-only")
    rc, out = pty_tool(B, args, [(r"Ctrl-C to stop: ", "\n"), (r"password: ", "two words\n")])
    C.check("a password with whitespace refused, nothing created",
            rc == 1 and "holds whitespace" in out and all(B.folder(n, fid) is None for n in ("A", "B", "H")), rc)
    typed = "Rebuilt-" + secrets.token_hex(12)
    B.typed.append(typed)
    rc, out = pty_tool(B, args, [(r"Ctrl-C to stop: ", "\n"), (r"password: ", typed + "\n"),
                                 (r"confirm : ", typed + "\n")])
    C.check("asked once on the terminal: exit 0, done", rc == 0 and "] done: " in out
            and "accepted (%d characters)" % len(typed) in out, rc)
    C.check("the typed password is what bigfed and fedxps now hold, and nothing else",
            own_passwords(B, "A") == {typed} and own_passwords(B, "B") == {typed})
    ma, mb = r.manifest("A", fid), r.manifest("B", fid)
    C.check("asked once: A and B equal by manifest", ma == mb and len(ma) >= 5, r.manifest_diff(ma, mb))
    v = r.views(fid)
    C.check("asked once: every hub view 100 with nothing needed", rig.Rig.views_clear(v), v)


HOOK_HEAD = """#!/usr/bin/env python3
# a hook of case_addfolder's stub ssh: %s
import json, os, sys, time
op = sys.argv[1] if len(sys.argv) > 1 else ""
here = os.path.dirname(os.path.abspath(__file__))
def count(name):
    p = os.path.join(here, name + ".count")
    n = int(open(p).read()) + 1 if os.path.exists(p) else 1
    open(p, "w").write(str(n))
    return n
"""
FILTER_HEAD = """text = sys.stdin.read()
lines = text.splitlines()
try:
    d = json.loads(lines[-1])
except (ValueError, IndexError):
    sys.stdout.write(text)
    sys.exit(0)
"""
FILTER_TAIL = """
lines[-1] = json.dumps(d)
print("\\n".join(lines))
"""


def scenario_env(B, wait_scale):
    """A shortened wait for a run meant to stop on one: 0.4 makes each wait
    48 s, room for the hub's wait after a slow reconnect under load (0.15
    flaked there with three cages at once, 2026-10-26)."""
    return {"SYNCTHING_ADDFOLDER_WAIT_SCALE": str(wait_scale)}


def case_roles(B):
    C.note("== 9. the reader's gsync keys (H2): a writer, none, a readerRepo for the path, an unreadable config")
    r = B.r
    fid = new_id()
    P = B.paths(fid)
    plain_tree(P["A"], "roles")
    good = open(B.gitcfg["B"]).read()
    base = rig.GIT_IDENTITY + rig.READER_GUARD
    try:
        B.set_git("B", base + "[gsync]\n\trole = writer\n")
        rc, out, _ = B.tool(B.args(fid, "roles", P, "--dry-run"), label="reader reads role = writer")
        C.check("a reader reading role = writer: exit 1, two writers", rc == 1 and "gsync.role reads writer: two writers" in out, rc)
        B.set_git("B", base)
        rc, out, _ = B.tool(B.args(fid, "roles", P, "--dry-run"), label="reader with no gsync key")
        C.check("a reader with no gsync key: exit 1, the key's fix printed",
                rc == 1 and "no gsync.role, so nothing there marks it a reader" in out and "role = reader" in out, rc)
        B.set_git("B", base + "[gsync]\n\treaderRepo = some-other-repo\n")
        rc, out, _ = B.tool(B.args(fid, "roles", P, "--dry-run"), label="readerRepo naming another path")
        C.check("a reader whose readerRepo names another path: exit 1",
                rc == 1 and "readerRepo names some-other-repo alone" in out, rc)
        rel = os.path.relpath(P["B"], os.path.join(r["B"].home, "Desktop"))
        B.set_git("B", base + "[gsync]\n\treaderRepo = %s\n" % rel)
        rc, out, _ = B.tool(B.args(fid, "roles", P, "--dry-run"), label="readerRepo naming READER-PATH")
        C.check("a reader whose readerRepo names READER-PATH, no role: passes (dry run, exit 0)",
                rc == 0 and "no gsync.role, and readerRepo names %s" % P["B"] in out, rc)
        B.set_git("B", base + "[gsync\n\trole = reader\n")
        rc, out, _ = B.tool(B.args(fid, "roles", P, "--dry-run"), label="reader's git config unreadable")
        C.check("a reader whose git config git cannot read: exit 2, a WARN with git's exit",
                rc == 2 and re.search(r"\[WARN\] fedxps: git could not read its gsync keys \(exit 1[0-9][0-9]", out), rc)
    finally:
        B.set_git("B", good)
    bad = os.path.join(B.root, "gitconfig-A-bad")
    write(bad, "[gsync\n\trole = writer\n")
    rc, out, _ = B.tool(B.args(fid, "roles", P, "--dry-run"), env_extra={"GIT_CONFIG_GLOBAL": bad},
                        label="writer's git config unreadable")
    C.check("this machine's git config unreadable: exit 2, a WARN", rc == 2 and "[WARN] bigfed: git could not read gsync.role" in out, rc)
    B.untouched("roles", fid, P)


def case_neighbours(B):
    C.note("== 10. preflight refusals in their failing direction: label, overlap, phone-home, an empty writer, a hub path under a file")
    r = B.r
    # AF02: another folder here already carries the label (paused, at an absent path: nothing else to see)
    fid = new_id()
    P = B.paths(fid)
    plain_tree(P["A"], "lab")
    r["A"].api("POST", "config/folders", {"id": "dup-" + fid, "label": "duplabel", "path": os.path.join(r["A"].data, "dup-" + fid),
                                          "type": "sendreceive", "devices": [{"deviceID": r["A"].device_id}], "paused": True})
    rc, out, _ = B.tool(B.args(fid, "duplabel", P, "--dry-run"), label="label taken")
    C.check("another folder on bigfed carries the label: exit 1, the one refusal",
            rc == 1 and "[FAIL] bigfed: folder dup-%s already carries the label 'duplabel'" % fid in out and out.count("[FAIL]") == 1,
            [l for l in out.splitlines() if "[FAIL]" in l])
    r["A"].api("DELETE", "config/folders/dup-" + fid)
    # AF03: a folder configured inside the writer's path (paused at an absent path, so no marker shows it)
    inner = os.path.join(P["A"], "inner-" + fid)
    r["A"].api("POST", "config/folders", {"id": "in-" + fid, "label": "inner-" + fid, "path": inner, "type": "sendreceive",
                                          "devices": [{"deviceID": r["A"].device_id}], "paused": True})
    rc, out, _ = B.tool(B.args(fid, "overlap", P, "--dry-run"), label="a folder inside the path")
    C.check("a folder configured inside the writer's path: exit 1, the overlap the one refusal",
            rc == 1 and "contains or lies inside %s" % P["A"] in out and out.count("[FAIL]") == 1,
            [l for l in out.splitlines() if "[FAIL]" in l])
    r["A"].api("DELETE", "config/folders/in-" + fid)
    # AF14: phone-home open on one instance (crash reporting: the one of the four that reaches nothing unless it crashes)
    r["B"].api("PATCH", "config/options", {"crashReportingEnabled": True})
    try:
        rc, out, _ = B.tool(B.args(fid, "phone", P, "--dry-run"), label="crash reporting on")
    finally:
        r["B"].api("PATCH", "config/options", {"crashReportingEnabled": False})
    C.check("crash reporting on at fedxps: exit 1, phone-home named",
            rc == 1 and "[FAIL] fedxps: phone-home open: crashReportingEnabled" in out, rc)
    # AF15: a join whose writer's path is empty
    fid = new_id()
    P = B.paths(fid)
    os.makedirs(P["A"])
    plain_tree(P["B"], "emptyw")
    rc, out, _ = B.tool(B.args(fid, "emptyw", P, "--trash", os.path.join(B.root, "trash-" + fid), "--dry-run"),
                        label="join with an empty writer")
    C.check("a join with bigfed's path empty: exit 1, the whole-tree revert named",
            rc == 1 and "is empty while the reader's holds files" in out and out.count("[FAIL]") == 1,
            [l for l in out.splitlines() if "[FAIL]" in l])
    # (R2's low) a hub path under a regular file
    fid = new_id()
    blocker = os.path.join(r["H"].data, "a-file-" + fid)
    write(blocker, "not a directory\n")
    P = B.paths(fid, hub=os.path.join(blocker, fid))
    plain_tree(P["A"], "hubfile")
    rc, out, _ = B.tool(B.args(fid, "hubfile", P, "--yes"), label="hub path under a file")
    C.check("a hub path under a regular file: exit 1 before any write",
            rc == 1 and "which is not a directory" in out and not do_lines(out), rc)
    C.check("hub path under a file: no instance holds the folder", all(B.folder(n, fid) is None for n in ("A", "B", "H")))


def case_stub_bounce(B):
    C.note("== 11a. (stub) the reader's bounce reads as if the pause never dropped the connection")
    r = B.r
    fid = new_id()
    P = B.paths(fid)
    plain_tree(P["A"], "nodrop")
    B.hook("fedxps", filt="if op == 'bounce':\n    d['dropped_after'] = None\n")
    try:
        rc, out, _ = B.tool(B.args(fid, "nodrop", P, "--yes"), label="a bounce not seen (stub)")
    finally:
        B.unhook("fedxps")
    C.check("a bounce whose pause never drops the connection: exit 2, the bounce not seen, the run stopped there",
            rc == 2 and "fedxps: the bounce was not seen" in out and "] done: " not in out, rc)


def case_stub_gate7(B):
    C.note("== 11b. (stub) gate 7 read while the reader's view of the hub lacks the hub's sequence")
    r = B.r
    hub_id = r["H"].device_id
    fid = new_id()
    P, ma, mb, only_b, differ, head = join_trees(B, fid)
    trash = os.path.join(B.root, "trash-g7-" + fid)
    B.hook("fedxps", filt="if op == 'status' and %r in (d.get('views') or {}) and d['views'][%r]:\n"
                          "    d['views'][%r]['sequence'] = 0\n" % (hub_id, hub_id, hub_id))
    try:
        rc, out, _ = B.tool(B.args(fid, "gate7", P, "--trash", trash, "--yes"), env_extra=scenario_env(B, 0.4),
                            label="gate 7 before the hub's index (stub)")
    finally:
        B.unhook("fedxps")
    C.check("gate 7 with the hub's index not on fedxps: exit 1, gate 7 named, nothing listed",
            rc == 1 and "gate 7: the hub's index on fedxps" in out and "the hub's index has not reached fedxps" in out
            and "[READ] fedxps: GET /rest/db/localchanged" not in out, rc)
    kept = [p for p in only_b if os.path.exists(os.path.join(P["B"], p))]
    C.check("... and nothing reverted: fedxps's own .git files still in its tree, no trashcan made",
            kept == only_b and not os.path.exists(trash),
            (kept, only_b, os.path.exists(trash), r.status("B", fid).get("receiveOnlyTotalItems")))


def case_stub_count(B):
    C.note("== 11c. (stub) a localchanged listing one short of receiveOnlyTotalItems")
    r = B.r
    fid = new_id()
    P, ma, mb, only_b, differ, head = join_trees(B, fid)
    trash = os.path.join(B.root, "trash-lc-" + fid)
    B.hook("fedxps", filt="if op == 'localchanged' and d.get('items'):\n    d['items'] = d['items'][:-1]\n")
    try:
        rc, out, _ = B.tool(B.args(fid, "lcount", P, "--trash", trash, "--yes"), label="localchanged one short (stub)")
    finally:
        B.unhook("fedxps")
    C.check("localchanged one short of receiveOnlyTotalItems: exit 2, the counts named, no revert sent",
            rc == 2 and re.search(r"fedxps lists \d+ local changes but counts \d+", out)
            and "[ DO ] fedxps: POST /rest/db/revert" not in out, rc)
    kept = [p for p in only_b if os.path.exists(os.path.join(P["B"], p))]
    C.check("... and nothing reverted: fedxps's own .git files still in its tree, no trashcan made",
            kept == only_b and not os.path.exists(trash),
            (kept, only_b, os.path.exists(trash), r.status("B", fid).get("receiveOnlyTotalItems")))


def case_stub_gate9(B):
    C.note("== 11d. (stub hooks) after the revert, one file of fedxps's tree changed at the same size, one trashcan file gone")
    r = B.r
    fid = new_id()
    P, ma, mb, only_b, differ, head = join_trees(B, fid)
    trash = os.path.join(B.root, "trash-g9-" + fid)
    victim = os.path.join(P["B"], "plain-join-alpha.txt")
    B.hook("fedxps", pre=("if op == 'manifest' and count('m') == 1:\n"
                          "    b = open(%r, 'rb').read()\n"
                          "    open(%r, 'wb').write(bytes([b[0] ^ 1]) + b[1:])\n"
                          "if op == 'trash' and count('t') == 1:\n"
                          "    fs = sorted(os.path.join(dp, f) for dp, _, fns in os.walk(%r) for f in fns)\n"
                          "    os.remove(fs[0])\n") % (victim, victim, trash))
    try:
        rc, out, _ = B.tool(B.args(fid, "gate9", P, "--trash", trash, "--yes"), label="gate 9, a file changed and one gone (stub hook)")
    finally:
        B.unhook("fedxps")
    C.check("gate 9 after one file changed at the same size: exit 1, the manifests differ, that path named",
            rc == 1 and "[FAIL] gate 9: the manifests differ in 1 entries" in out and "plain-join-alpha.txt:" in out, rc)
    C.check("gate 9 with one listed file gone from the trashcan: the trashcan named as lacking it",
            "[FAIL] gate 9: the trashcan %s lacks 1 listed file(s)" % trash in out)
    C.check("gate 9 failing: no switch, fedxps still receive-only",
            "[ DO ] fedxps: PATCH /rest/config/folders/%s type sendreceive" % fid not in out
            and r.folder_config("B", fid)["type"] == "receiveonly", r.folder_config("B", fid)["type"])


def case_switch_edit(B):
    C.note("== 11e. bigfed written to during the switch's watch, the hub's link paused so only bigfed's sequence moves")
    r = B.r
    fid = new_id()
    P, ma, mb, only_b, differ, head = join_trees(B, fid)
    trash = os.path.join(B.root, "trash-sw-" + fid)

    def edit_on_bigfed():
        r.pause_device("A", "H")
        write(os.path.join(P["A"], "written-during-the-watch.txt"), "an edit on bigfed\n")
        r.scan("A", fid)
    try:
        rc, out, _ = B.tool(B.args(fid, "switchw", P, "--trash", trash, "--yes"), env_extra=scenario_env(B, 0.4),
                            act_on=(r"watching the sequences", edit_on_bigfed), label="an edit on bigfed in the watch")
    finally:
        r.resume_device("A", "H")
        r.wait_connected([("A", "H")])
    C.check("an edit on bigfed during the switch's watch: exit 1, bigfed's sequence named",
            rc == 1 and re.search(r"something was sent at the switch: nousowl (\d+) -> \1, bigfed (\d+) -> (?!\2)\d+", out), rc)


def case_stub_stale(B):
    C.note("== 11f. (stub) the hub's view of fedxps one sequence behind fedxps's own, every round; its status carrying an error")
    r = B.r
    r_id = r["B"].device_id
    fid = new_id()
    P = B.paths(fid)
    plain_tree(P["A"], "stale")
    B.hook("nousowl", filt="v = (d.get('views') or {}).get(%r)\nif op == 'status' and v and v.get('sequence'):\n"
                           "    v['sequence'] -= 1\n    d['status']['error'] = 'a stub error'\n" % r_id)
    try:
        rc, out, _ = B.tool(B.args(fid, "stale", P, "--yes"), env_extra=scenario_env(B, 0.4), label="a stale view (stub)")
    finally:
        B.unhook("nousowl")
    C.check("the hub's view of fedxps a sequence behind: exit 1, never converged, the view named",
            rc == 1 and "views not at 100 at the device's own sequence: nousowl->fedxps" in out and "] done: " not in out, rc)
    C.check("a wait line shows db/status's error", "error='a stub error'" in out)


def case_stub_once(B):
    C.note("== 11g. (stub) one good round and then never again: the first reading of fedxps after its bounce, "
           "12 s late so all three have settled, passes; every later one reads syncing")
    r = B.r
    fid = new_id()
    P = B.paths(fid)
    plain_tree(P["A"], "once")
    B.hook("fedxps", filt="if op == 'bounce':\n    time.sleep(12)\n"
                          "if op == 'status' and count('s') > 1:\n    d['status']['state'] = 'syncing'\n")
    try:
        rc, out, _ = B.tool(B.args(fid, "once", P, "--yes"), env_extra=scenario_env(B, 0.4), label="one good round (stub)")
    finally:
        B.unhook("fedxps")
    C.check("one good round followed by none: exit 1, the final wait never held", rc == 1
            and "all three converged, every view at 100 did not hold" in out and "] done: " not in out, rc)
    C.check("... and that first round was a good one (its reading shown as READ)",
            re.search(r"\[READ\] fedxps idle need=0", out) is not None)


def main(root):
    B = Bench(root)
    B.setup()
    t = time.time()
    case_no_password(B)
    seed = "seed-" + secrets.token_hex(3)
    B.r.share(seed)
    C.note("a seed folder shared through the hub: the cluster password now on both workstations (%.1f s)" % (time.time() - t))
    steps = [case_refusals, case_roles, case_neighbours, case_dry_run, case_fresh, case_half_made, case_join,
             case_join_outside, case_stub_bounce, case_stub_gate7, case_stub_count, case_stub_gate9, case_switch_edit,
             case_stub_stale, case_stub_once, case_rebuild]
    only = os.environ.get("ADDFOLDER_CASES")
    for fn in steps:
        if only and fn.__name__ not in only.split(","):
            continue
        t0 = time.time()
        try:
            fn(B)
        except Exception as e:            # one sub-case's crash fails it, not the rest
            C.check("%s ran to its end" % fn.__name__, False, "%s: %s" % (type(e).__name__, e))
        C.note("%s: %.1f s" % (fn.__name__, time.time() - t0))
    secrets_seen = [w for w in [rig.PASSWORD] + B.typed if any(w in o for o in B.outputs)]
    C.check("no password in any line the tool printed (%d runs)" % len(B.outputs), not secrets_seen,
            "%d of them appear" % len(secrets_seen))
    try:
        with open(os.path.join(B.stub, "ssh-argv.log")) as f:
            argv = f.read()
    except OSError:
        argv = ""
    C.check("no password and no API key in any ssh command line",
            argv and not any(w in argv for w in [rig.PASSWORD] + B.typed + [B.r[n].apikey for n in ("A", "B", "H")]))
    C.check("no ssh call went to an unknown host",
            all(l.split()[0] in ("nousowl", "nousowl-vpn", "fedxps", "fedxps-vpn") for l in B.ssh_log() if l.strip()))
    B.r.stop()
    C.check("the rig stopped, no process left", not B.r.pids(), B.r.pids())
    return C


if __name__ == "__main__":
    main(sys.argv[1]).exit()
