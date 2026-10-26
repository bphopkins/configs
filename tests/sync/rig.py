#!/usr/bin/env python3
"""tests/sync/rig.py -- real Syncthing instances on loopback, for tests/sync.

The transport campaign's rules (org/machines/transport-2026-10/rules.md, "How
to read it" -> Tests) name one durable suite for every case that needs
Syncthing itself: three instances on loopback -- A plays bigfed, the writer;
B plays fedxps, the reader; H plays nousowl, the receive-encrypted hub -- with
phone-home off before the first start and no real device ID anywhere. This is
that rig. It adapts the battery's (scratch-2026-10-09/refute-claude-cases/
st/rig.py and its siblings, 2026-10-09) in four ways:

  - ports are free ones found at run time (bind, read, release), never fixed,
    so two suites, or two rigs in one suite, can run at once;
  - instances are plain child processes of the case, inside the suite's cage
    (tests/cage.sh), each in its own process group, stopped by the rig at exit
    and on SIGTERM/SIGINT/SIGHUP, and by the suite's trap after that; the
    battery gave each instance a systemd scope of its own;
  - each instance's home is a sandbox HOME holding config.xml at
    $HOME/.local/state/syncthing/config.xml, the path bin/sync-check reads, so
    a case can run the real gauge against an instance (gauge_env);
  - folders are made only through POST /rest/config/folders, and carry no
    maxConflicts unless a case asks, so the POST's own defaults are what a
    case reads (rule ws-7).

The lock-down, written into config.xml after `syncthing generate` and before
the first start, as the battery's generate() did: GUI and listen address on
127.0.0.1 only; global and local announce, relays, NAT and crash reporting
off; usage reporting refused (urAccepted -1); automatic upgrades off
(autoUpgradeIntervalH 0, STNOUPGRADE=1, --no-upgrade); no browser; no global
announce server; STUN off; the generated device renamed and every folder
removed (STNODEFAULTFOLDER=1 keeps the default folder from coming back).
Rig.sockets() lists every listening socket the rig's processes hold, and the
smoke case asserts each is on 127.0.0.1.

Secrets: each instance gets a fresh random API key per run, held in this
process and in its sandbox config.xml, sent as a header and never printed.
The encryption password is a fixed throwaway string (PASSWORD); it guards
only rig data, and folder_config() strips it before a case sees the folder.
Device IDs are generated per run and die with the sandbox; a case prints the
seven-character short forms at most.

Library use, from a case beside this file:

    import rig
    r = rig.Rig(root)                 # root: an empty directory in the sandbox
    r.trio()                          # A, B, H generated, started, paired via H
    fid = r.share('demo')             # H receiveencrypted, A and B sendreceive
    ...                               # write into r.path('A', fid), wait_idle, read
    r.stop()                          # also at exit and on a signal

It is a library only; the rig is exercised, caged, by `tests/sync/run.sh
smoke` (case_smoke.py).

Reads follow Syncthing's REST JSON (2.1.x, measured on 2.1.6): db/status,
db/completion, db/file (version vectors as "SHORTID:counter" strings),
db/browse, db/localchanged, db/need, db/remoteneed, events/disk,
folder/errors, config/folders/<id>. Nothing here reads /rest/config whole.
"""

import atexit
import hashlib
import json
import os
import secrets
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

SYNCTHING = os.environ.get("RIG_SYNCTHING", "syncthing")
# A throwaway password: it encrypts nothing but rig data. Never a real one.
PASSWORD = "tests-sync-rig-password-not-a-secret"
# The hub's versioning, as mig-3 gate 5 sets it on nousowl: staggered, a year.
STAGGERED = {"type": "staggered", "params": {"maxAge": "31536000", "cleanInterval": "3600"},
             "cleanupIntervalS": 3600, "fsPath": "", "fsType": "basic"}
# The reader guard of rules.md fedxps-1, as configs/git/hosts/fedxps.inc carries it.
READER_GUARD = ("[core]\n\tcheckStat = minimal\n\ttrustctime = false\n"
                "[diff]\n\tautoRefreshIndex = false\n"
                "[gc]\n\tauto = 0\n"
                "[maintenance]\n\tauto = false\n")
GIT_IDENTITY = ("[user]\n\tname = Rig\n\temail = rig@example.invalid\n"
                "[init]\n\tdefaultBranch = main\n"
                "[advice]\n\tdetachedHead = false\n"
                "[maintenance]\n\tautoDetach = false\n")
REST_TIMEOUT = 30
NO_ANNOUNCE = "https://127.0.0.1:9/"     # the discard port: nothing listens


class RigError(RuntimeError):
    """Something the rig could not bring about: an instance that did not come
    up, a connection that did not form, a wait that ran out."""


def free_ports(n):
    """n distinct free TCP ports on 127.0.0.1: bind all n at once, read, release.
    A port can be taken between the release and Syncthing's bind; an instance
    that then fails to come up says so (Node.start)."""
    socks = []
    try:
        for _ in range(n):
            s = socket.socket()
            s.bind(("127.0.0.1", 0))
            socks.append(s)
        return [s.getsockname()[1] for s in socks]
    finally:
        for s in socks:
            s.close()


def sha256_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def _cbytes(s):
    # LC_ALL=C order: by the path's bytes
    return s.encode("utf-8", "surrogateescape")


class Node:
    """One Syncthing instance: its sandbox HOME, its Syncthing home under it,
    its data directory, its two ports, its key and device ID."""

    def __init__(self, rig, name, device_name=None, env=None):
        self.rig = rig
        self.name = name
        self.device_name = device_name or name
        self.dir = os.path.join(rig.root, name)
        self.home = os.path.join(self.dir, "home")                    # the sandbox HOME
        self.st_home = os.path.join(self.home, ".local", "state", "syncthing")
        self.config_xml = os.path.join(self.st_home, "config.xml")
        self.data = os.path.join(self.dir, "data")                    # folders live here
        self.log = os.path.join(self.dir, "syncthing.log")
        self.env = dict(env or {})
        self.gui, self.listen = free_ports(2)
        self.apikey = secrets.token_hex(16)
        self.device_id = None
        self.before_start = None      # locked_down() as generate() left it
        self.proc = None

    @property
    def short_id(self):
        """The form version vectors and conflict-copy names carry: the device
        ID's first seven characters."""
        return self.device_id[:7]

    def clean_env(self):
        """The environment Syncthing runs in: no ST* or XDG_* variable of the
        caller's, HOME and the XDG directories inside the sandbox."""
        env = {k: v for k, v in os.environ.items() if not k.startswith(("ST", "XDG_"))}
        env.update(HOME=self.home,
                   XDG_CONFIG_HOME=os.path.join(self.home, ".config"),
                   XDG_STATE_HOME=os.path.join(self.home, ".local", "state"),
                   XDG_DATA_HOME=os.path.join(self.home, ".local", "share"),
                   XDG_CACHE_HOME=os.path.join(self.home, ".cache"),
                   STNOUPGRADE="1", STNODEFAULTFOLDER="1")
        env.update(self.env)
        return env

    # --- generate and lock down ---------------------------------------------------
    def generate(self):
        """Keys and config, then the lock-down, before any start."""
        os.makedirs(self.st_home, mode=0o700, exist_ok=True)
        os.makedirs(self.data, exist_ok=True)
        subprocess.run([SYNCTHING, "generate", "--home=" + self.st_home, "--no-port-probing"],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       env=self.clean_env())
        self.device_id = subprocess.run([SYNCTHING, "device-id", "--home=" + self.st_home],
                                        check=True, capture_output=True, text=True,
                                        env=self.clean_env()).stdout.strip()
        tree = ET.parse(self.config_xml)
        root = tree.getroot()
        for fo in root.findall("folder"):
            root.remove(fo)
        for dv in root.findall("device"):
            if dv.get("id") != self.device_id:
                root.remove(dv)
            else:
                dv.set("name", self.device_name)     # generate names it after the host
        gui = root.find("gui")
        gui.set("enabled", "true")
        gui.set("tls", "false")
        gui.find("address").text = "127.0.0.1:%d" % self.gui
        k = gui.find("apikey")
        if k is None:
            k = ET.SubElement(gui, "apikey")
        k.text = self.apikey
        opts = root.find("options")
        for la in opts.findall("listenAddress"):
            opts.remove(la)
        la = ET.Element("listenAddress")
        la.text = "tcp://127.0.0.1:%d" % self.listen
        opts.insert(0, la)
        # No announce server: Syncthing refills an empty list with "default" at
        # its first start (measured, 2.1.6), so the list holds one loopback
        # address nothing answers -- announce is off, and were it ever on it
        # would reach nothing.
        for gs in opts.findall("globalAnnounceServer"):
            opts.remove(gs)
        gs = ET.Element("globalAnnounceServer")
        gs.text = NO_ANNOUNCE
        opts.insert(1, gs)
        for kname, v in {
                "globalAnnounceEnabled": "false", "localAnnounceEnabled": "false",
                "relaysEnabled": "false", "natEnabled": "false", "crashReportingEnabled": "false",
                "urAccepted": "-1", "urSeen": "3", "autoUpgradeIntervalH": "0", "startBrowser": "false",
                "announceLANAddresses": "false", "stunKeepaliveStartS": "0", "stunKeepaliveMinS": "0"}.items():
            e = opts.find(kname)
            if e is None:
                e = ET.SubElement(opts, kname)
            e.text = v
        dfl = root.find("defaults")
        if dfl is not None and dfl.find("folder") is not None:
            dfl.find("folder").set("path", self.data)   # never a path under the real ~
        tree.write(self.config_xml)
        os.chmod(self.config_xml, 0o600)
        self.before_start = self.locked_down()
        return self.device_id

    def locked_down(self):
        """The lock-down as config.xml holds it: a dict of the settings that
        matter, nothing secret. Read from the file, so it holds before the
        first start as after."""
        root = ET.parse(self.config_xml).getroot()
        opts = root.find("options")
        out = {k: opts.findtext(k) for k in (
            "globalAnnounceEnabled", "localAnnounceEnabled", "relaysEnabled", "natEnabled",
            "crashReportingEnabled", "urAccepted", "autoUpgradeIntervalH", "startBrowser",
            "announceLANAddresses", "stunKeepaliveStartS")}
        out["listen"] = [e.text for e in opts.findall("listenAddress")]
        out["globalAnnounceServer"] = [e.text for e in opts.findall("globalAnnounceServer")]
        out["gui"] = root.find("gui").findtext("address")
        out["folders"] = [f.get("id") for f in root.findall("folder")]
        return out

    # --- run ---------------------------------------------------------------------
    def start(self, timeout=30):
        if self.proc and self.proc.poll() is None:
            return
        cmd = [SYNCTHING, "serve", "--home=" + self.st_home, "--no-browser", "--no-restart", "--no-upgrade"]
        with open(self.log, "ab") as lf:
            self.proc = subprocess.Popen(cmd, stdout=lf, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                                         env=self.clean_env(), cwd=self.dir, start_new_session=True)
        t0 = time.time()
        while time.time() - t0 < timeout:
            if self.proc.poll() is not None:
                raise RigError("%s exited with %s before its API answered; see %s"
                               % (self.name, self.proc.returncode, self.log))
            try:
                self.api("GET", "system/ping", timeout=2)
                return
            except (OSError, urllib.error.URLError):
                time.sleep(0.1)
        raise RigError("%s did not answer on 127.0.0.1:%d within %ds; see %s"
                       % (self.name, self.gui, timeout, self.log))

    def stop(self, timeout=10):
        """SIGTERM to the instance's process group (Syncthing 2.x runs a monitor
        and a child even under --no-restart), SIGKILL after `timeout`, then
        anything still running from this home by pid."""
        if self.proc is not None:
            try:
                os.killpg(self.proc.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                self.proc.wait(timeout)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(self.proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                self.proc.wait(5)
            self.proc = None
        t0 = time.time()
        while True:
            left = pids_matching("--home=" + self.st_home)
            if not left:
                return
            if time.time() - t0 > timeout:
                for p in left:
                    try:
                        os.kill(p, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                return
            time.sleep(0.1)

    def running(self):
        return self.proc is not None and self.proc.poll() is None

    def api(self, method, path, body=None, timeout=REST_TIMEOUT, raw=False):
        url = "http://127.0.0.1:%d/rest/%s" % (self.gui, path)
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method,
                                     headers={"X-API-Key": self.apikey, "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            b = r.read()
        if raw:
            return b
        if not b:
            return None
        try:
            return json.loads(b)
        except ValueError:
            return b.decode("utf-8", "replace")


def pids_matching(needle):
    """Pids whose command line contains `needle` and runs syncthing, read from
    /proc (never pgrep -f, whose pattern would match the caller's shell)."""
    out = []
    me = os.getpid()
    for d in os.listdir("/proc"):
        if not d.isdigit() or int(d) == me:
            continue
        try:
            with open("/proc/%s/cmdline" % d, "rb") as f:
                args = f.read().split(b"\0")
        except OSError:
            continue
        if args and os.path.basename(args[0].decode(errors="replace")) == "syncthing" and \
                any(needle.encode() in a for a in args):
            out.append(int(d))
    return out


class Rig:
    """A set of instances under one root. Nodes are named by the caller; the
    conventional three are A (writer), B (reader) and H (hub)."""

    def __init__(self, root, password=PASSWORD):
        self.root = os.path.realpath(root)
        os.makedirs(self.root, exist_ok=True)
        self.password = password
        self.nodes = {}
        self.hubs = set()
        atexit.register(self.stop)
        for sig in (signal.SIGTERM, signal.SIGHUP):
            try:
                signal.signal(sig, _exit_on_signal)
            except ValueError:          # not the main thread
                pass

    # --- instances -----------------------------------------------------------------
    def add(self, name, device_name=None, env=None, hub=False):
        """Generate (and lock down) an instance; it is not started."""
        n = Node(self, name, device_name, env)
        n.generate()
        self.nodes[name] = n
        if hub:
            self.hubs.add(name)
        return n

    def __getitem__(self, name):
        return self.nodes[name]

    def start(self, *names):
        for name in names or tuple(self.nodes):
            self.nodes[name].start()

    def stop(self, *names):
        """Stop the named instances, or every one."""
        for name in names or tuple(self.nodes):
            self.nodes[name].stop()

    def restart(self, name, env=None):
        n = self.nodes[name]
        n.stop()
        if env is not None:
            n.env = dict(env)
        n.start()

    def pids(self):
        """Every live syncthing process of this rig, by its root in the command line."""
        return pids_matching(self.root + os.sep)

    def sockets(self):
        """(pid, proto, local address) for every listening socket a rig process holds."""
        pids = set(self.pids())
        r = subprocess.run(["ss", "-tulnpH"], capture_output=True, text=True).stdout.splitlines()
        out = []
        for line in r:
            f = line.split()
            for p in pids:
                if "pid=%d," % p in line:
                    out.append((p, f[0], f[4]))
        return out

    def trio(self, hub_env=None, direct=False, names=None, connect_timeout=60):
        """A, B and H generated, started and paired: A<->H and B<->H, the hub
        untrusted on each workstation's side; A<->B too when `direct` (ws-16's
        direct link). `names` maps A/B/H to device names (e.g. bigfed, fedxps,
        nousowl for a case that runs the gauge). `hub_env` is extra
        environment for H alone (STDBMAINTENANCEINTERVAL, ...)."""
        names = names or {}
        self.add("A", names.get("A"))
        self.add("B", names.get("B"))
        self.add("H", names.get("H"), env=hub_env, hub=True)
        self.start("A", "B", "H")
        self.connect_hub("A", "H")
        self.connect_hub("B", "H")
        pairs = [("A", "H"), ("B", "H")]
        if direct:
            self.pair("A", "B")
            self.pair("B", "A")
            pairs.append(("A", "B"))
        self.wait_connected(pairs, timeout=connect_timeout)
        return self

    # --- devices -------------------------------------------------------------------
    def pair(self, n, peer, untrusted=False):
        """Add `peer` to `n`'s config at its loopback address (one direction)."""
        p = self.nodes[peer]
        self.nodes[n].api("POST", "config/devices", {
            "deviceID": p.device_id, "name": p.device_name,
            "addresses": ["tcp://127.0.0.1:%d" % p.listen],
            "compression": "metadata", "introducer": False, "paused": False,
            "untrusted": untrusted, "autoAcceptFolders": False})

    def connect_hub(self, ws, hub):
        """A workstation and the hub, both directions; the hub untrusted on the
        workstation's side, as on bigfed and fedxps."""
        self.pair(ws, hub, untrusted=True)
        self.pair(hub, ws)

    def connected(self, n, peer):
        c = self.nodes[n].api("GET", "system/connections")["connections"].get(self.nodes[peer].device_id, {})
        return bool(c.get("connected"))

    def wait_connected(self, pairs, timeout=60):
        t0 = time.time()
        while time.time() - t0 < timeout:
            if all(self.connected(a, b) and self.connected(b, a) for a, b in pairs):
                return time.time() - t0
            time.sleep(0.2)
        raise RigError("not connected after %ds: %s" % (timeout, [(a, b, self.connected(a, b)) for a, b in pairs]))

    def pause_device(self, n, peer):
        self.nodes[n].api("POST", "system/pause?device=" + self.nodes[peer].device_id)

    def resume_device(self, n, peer):
        self.nodes[n].api("POST", "system/resume?device=" + self.nodes[peer].device_id)

    def bounce(self, pairs, wait=True):
        """Pause and resume each (node, peer): what makes an encrypted folder
        shared after both sides are connected start to flow (the battery's
        topo.bounce)."""
        for a, b in pairs:
            self.pause_device(a, b)
        time.sleep(1)
        for a, b in pairs:
            self.resume_device(a, b)
        if wait:
            self.wait_connected(pairs)

    # --- folders -------------------------------------------------------------------
    def path(self, n, fid, *parts):
        """Absolute path of `parts` in node n's copy of folder fid."""
        return os.path.join(self.nodes[n].data, fid, *parts)

    def add_folder(self, n, fid, peers, ftype="sendreceive", enc_to=(), versioning=None,
                   delay=2, rescan=3600, path=None, label=None, **extra):
        """POST /rest/config/folders on node n: the folder shared with `peers`,
        those in `enc_to` given the rig password (a workstation sharing with
        the hub). Fields not named are the POST's defaults; maxConflicts is
        among them unless passed in `extra` (rule ws-7)."""
        p = path or self.path(n, fid)
        os.makedirs(p, exist_ok=True)
        devs = [{"deviceID": self.nodes[n].device_id}]
        for q in peers:
            d = {"deviceID": self.nodes[q].device_id}
            if q in enc_to:
                d["encryptionPassword"] = self.password
            devs.append(d)
        body = {"id": fid, "label": label or fid, "path": p, "type": ftype, "devices": devs,
                "fsWatcherEnabled": True, "fsWatcherDelayS": delay, "rescanIntervalS": rescan}
        if versioning:
            body["versioning"] = versioning
        body.update(extra)
        self.nodes[n].api("POST", "config/folders", body)
        return p

    def share(self, fid, hub="H", workstations=("A", "B"), types=None, direct=False,
              hub_versioning=STAGGERED, delay=2, bounce=True, settle=True, **extra):
        """Folder fid on the hub (receiveencrypted, staggered versioning, in a
        new empty directory: hub-3) and on each workstation (`types` maps a
        workstation to its type, default sendreceive), shared through the hub
        with the password, and directly between workstations when `direct`.
        Then the bounce, and a wait for the folder to read idle everywhere."""
        types = types or {}
        hp = self.path(hub, fid)
        if os.path.exists(hp):
            raise RigError("hub path %s exists; a new hub folder gets a new, empty directory (hub-3)" % hp)
        self.add_folder(hub, fid, list(workstations), ftype="receiveencrypted",
                        versioning=hub_versioning, delay=delay, **extra)
        pairs = []
        for w in workstations:
            peers = [hub] + ([x for x in workstations if x != w] if direct else [])
            self.add_folder(w, fid, peers, ftype=types.get(w, "sendreceive"), enc_to=(hub,), delay=delay, **extra)
            pairs.append((w, hub))
        if direct:
            pairs += [(a, b) for i, a in enumerate(workstations) for b in workstations[i + 1:]]
        if bounce:
            self.bounce(pairs)
        if settle:
            self.wait_idle(list(workstations) + [hub], fid, settle=1, timeout=60)
        return fid

    def folder_config(self, n, fid):
        """GET config/folders/<id>, the password field of every device removed
        before the caller sees it."""
        f = self.nodes[n].api("GET", "config/folders/" + urllib.parse.quote(fid, safe=""))
        for d in f.get("devices", []):
            d.pop("encryptionPassword", None)
        return f

    def patch_folder(self, n, fid, **fields):
        self.nodes[n].api("PATCH", "config/folders/" + urllib.parse.quote(fid, safe=""), fields)

    # --- reads ---------------------------------------------------------------------
    def _q(self, fid, **kw):
        q = {"folder": fid}
        q.update({k: v for k, v in kw.items() if v is not None})
        return urllib.parse.urlencode(q)

    def status(self, n, fid):
        return self.nodes[n].api("GET", "db/status?" + self._q(fid))

    def completion(self, n, fid, peer):
        return self.nodes[n].api("GET", "db/completion?" + self._q(fid, device=self.nodes[peer].device_id))

    def dbfile(self, n, fid, name):
        """db/file: {'global':..., 'local':..., 'availability':..., 'mtime':...};
        None when the database has no such file."""
        try:
            return self.nodes[n].api("GET", "db/file?" + self._q(fid, file=name))
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            raise

    def vector(self, n, fid, name, which="global"):
        """The version vector of `name` in n's database, as Syncthing returns it:
        a list of "SHORTID:counter" strings. None when there is no such file."""
        d = self.dbfile(n, fid, name)
        if d is None:
            return None
        return list((d.get(which) or {}).get("version") or [])

    def vector_devices(self, n, fid, name, which="global"):
        """The short IDs that carry a counter in `name`'s version vector."""
        v = self.vector(n, fid, name, which)
        return None if v is None else sorted(c.split(":", 1)[0] for c in v)

    def browse(self, n, fid, prefix=None, levels=None):
        return self.nodes[n].api("GET", "db/browse?" + self._q(fid, prefix=prefix, levels=levels))

    def localchanged(self, n, fid, page=1, perpage=100000):
        return self.nodes[n].api("GET", "db/localchanged?" + self._q(fid, page=page, perpage=perpage))

    def need(self, n, fid, page=1, perpage=100000):
        return self.nodes[n].api("GET", "db/need?" + self._q(fid, page=page, perpage=perpage))

    def remoteneed(self, n, fid, peer, page=1, perpage=100000):
        return self.nodes[n].api("GET", "db/remoteneed?" + self._q(
            fid, device=self.nodes[peer].device_id, page=page, perpage=perpage))

    def remoteneed_names(self, n, fid, peer):
        """The names n's view lists as needed by `peer` (files and directories)."""
        r = self.remoteneed(n, fid, peer) or {}
        return sorted(f["name"] for f in (r.get("files") or []))

    def folder_errors(self, n, fid):
        return (self.nodes[n].api("GET", "folder/errors?" + self._q(fid)) or {}).get("errors") or []

    def events(self, n, since=0, types=None, timeout=0, limit=None):
        q = {"since": since, "timeout": timeout}
        if types:
            q["events"] = ",".join(types)
        if limit:
            q["limit"] = limit
        return self.nodes[n].api("GET", "events?" + urllib.parse.urlencode(q), timeout=timeout + REST_TIMEOUT) or []

    def disk_events(self, n, since=0, timeout=0):
        """events/disk: LocalChangeDetected and RemoteChangeDetected, the last
        1,000 since the daemon started."""
        q = urllib.parse.urlencode({"since": since, "timeout": timeout})
        return self.nodes[n].api("GET", "events/disk?" + q, timeout=timeout + REST_TIMEOUT) or []

    def last_disk_event(self, n):
        ev = self.disk_events(n)
        return ev[-1]["id"] if ev else 0

    def local_changes(self, n, fid, since=0, under=None):
        """(time, action, type, path) of every LocalChangeDetected in fid since
        event `since`, under the directory `under` if given."""
        out = []
        for e in self.disk_events(n, since):
            d = e.get("data") or {}
            if e.get("type") != "LocalChangeDetected" or d.get("folder") != fid:
                continue
            p = d.get("path", "")
            if under is None or p == under or p.startswith(under.rstrip("/") + "/"):
                out.append((e.get("time"), d.get("action"), d.get("type"), p))
        return out

    # --- acts ----------------------------------------------------------------------
    def scan(self, n, fid, sub=None):
        """POST /rest/db/scan, which returns once the scan has finished."""
        self.nodes[n].api("POST", "db/scan?" + self._q(fid, sub=sub), timeout=120)

    def revert(self, n, fid):
        """POST /rest/db/revert: a receive-only folder's local changes undone."""
        self.nodes[n].api("POST", "db/revert?" + self._q(fid))

    # --- waits ---------------------------------------------------------------------
    def wait_idle(self, nodes, fid, settle=3.0, timeout=120, scan=True, raise_on_timeout=True):
        """Wait until every node in `nodes` reads fid idle with nothing needed
        (needTotalItems 0) and its counts and sequence unchanged for `settle`
        seconds, with no Syncthing temporary file in any copy. Hubs are not
        scanned; the others are first, so a change seconds old is counted.
        Returns the seconds waited; on timeout raises RigError naming each
        node's state (or returns None with raise_on_timeout=False)."""
        if scan:
            for n in nodes:
                if n not in self.hubs:
                    self.scan(n, fid)
        t0 = time.time()
        last = since = None
        st = {}
        while time.time() - t0 < timeout:
            try:
                st = {n: self.status(n, fid) for n in nodes}
            except (OSError, urllib.error.URLError):
                since = None
                time.sleep(0.3)
                continue
            key = tuple((st[n].get("sequence"), st[n].get("localFiles"), st[n].get("localDeleted"),
                         st[n].get("localDirectories"), st[n].get("globalFiles"), st[n].get("globalDeleted"),
                         st[n].get("globalDirectories")) for n in nodes)
            ok = all(st[n].get("state") == "idle" and not st[n].get("needTotalItems") for n in nodes) \
                and not self.tempfiles(nodes, fid)
            if ok and key == last:
                if since is None:
                    since = time.time()
                if time.time() - since >= settle:
                    return round(time.time() - t0, 2)
            else:
                since = time.time() if ok else None
            last = key
            time.sleep(0.25)
        msg = "fid %s not idle after %ss: %s" % (fid, timeout, {
            n: (s.get("state"), s.get("needTotalItems"), s.get("pullErrors")) for n, s in st.items()})
        if raise_on_timeout:
            raise RigError(msg)
        return None

    def tempfiles(self, nodes, fid):
        out = []
        for n in nodes:
            base = self.path(n, fid)
            for dp, dns, fns in os.walk(base):
                out += [os.path.join(dp, f) for f in fns if f.startswith(".syncthing.") and f.endswith(".tmp")]
        return out

    def views(self, fid, hub="H", workstations=("A", "B")):
        """Each workstation's view of the hub and the hub's view of each:
        {'A->H': {completion, needItems, needDeletes, remoteState}, 'H->A': ...}."""
        out = {}
        for w in workstations:
            for a, b in ((w, hub), (hub, w)):
                c = self.completion(a, fid, b)
                out["%s->%s" % (a, b)] = {k: c.get(k) for k in ("completion", "needItems", "needDeletes", "remoteState")}
        return out

    @staticmethod
    def views_clear(views):
        """True when every view reads 100 with nothing needed and a valid remote."""
        return all(v["completion"] == 100 and not v["needItems"] and not v["needDeletes"]
                   and v["remoteState"] == "valid" for v in views.values())

    # --- trees ---------------------------------------------------------------------
    def manifest(self, n, fid, sub=""):
        """{path: sha256} for every file of node n's copy of fid (under `sub`),
        'dir' for each directory and 'link:TARGET' for each symlink, in
        LC_ALL=C order, the marker directory .stfolder/ left out."""
        base = self.path(n, fid)
        top = os.path.join(base, sub) if sub else base
        out = {}
        for dp, dns, fns in os.walk(top):
            rel = os.path.relpath(dp, base)
            if rel == ".":
                dns[:] = [d for d in dns if d != ".stfolder"]
            for d in dns:
                p = os.path.join(dp, d)
                r = os.path.normpath(os.path.join(rel, d))
                out[r] = "link:" + os.readlink(p) if os.path.islink(p) else "dir"
            for f in fns:
                p = os.path.join(dp, f)
                r = os.path.normpath(os.path.join(rel, f))
                out[r] = "link:" + os.readlink(p) if os.path.islink(p) else sha256_file(p)
        return dict(sorted(out.items(), key=lambda kv: _cbytes(kv[0])))

    @staticmethod
    def manifest_diff(m1, m2, limit=20):
        """The paths where two manifests differ, as 'path: a | b' strings."""
        keys = sorted(set(m1) | set(m2), key=_cbytes)
        out = ["%s: %s | %s" % (k, (m1.get(k) or "-")[:12], (m2.get(k) or "-")[:12])
               for k in keys if m1.get(k) != m2.get(k)]
        return out[:limit] + (["... %d more" % (len(out) - limit)] if len(out) > limit else [])

    def files(self, n, fid, sub=""):
        """Relative paths of the regular files in n's copy, .stfolder/ left out."""
        return [k for k, v in self.manifest(n, fid, sub).items() if v != "dir" and not v.startswith("link:")]

    def conflict_copies(self, n, fid):
        return [k for k in self.manifest(n, fid) if ".sync-conflict-" in os.path.basename(k)]

    # --- the gauge -------------------------------------------------------------------
    def gauge_env(self, n, base=None):
        """Environment for running bin/sync-check as node n: its sandbox HOME
        (config.xml where the gauge looks) and SYNC_CHECK_CONFIG naming it."""
        env = dict(base if base is not None else os.environ)
        for k in [k for k in env if k.startswith("XDG_")]:
            del env[k]
        env.update(HOME=self.nodes[n].home, SYNC_CHECK_CONFIG=self.nodes[n].config_xml)
        return env


def _exit_on_signal(signum, frame):
    # SystemExit runs the atexit handlers, which stop every rig
    raise SystemExit(128 + signum)


# --- git, in a rig folder ------------------------------------------------------------
def write_gitconfig(path, extra=""):
    """A global git config for a case: an identity, maintenance in the
    foreground, Syncthing's marker directory excluded (as the private global
    exclude does on both machines; without it `git add -A` at a folder's root
    tracks .stfolder/, whose marker file differs per device and never
    syncs), plus `extra` (READER_GUARD for the reader)."""
    with open(path + ".exclude", "w") as f:
        f.write(".stfolder/\n")
    with open(path, "w") as f:
        f.write(GIT_IDENTITY + "[core]\n\texcludesFile = %s\n" % (path + ".exclude") + extra)
    return path


def git_env(gitconfig, optional_locks=None, home=None):
    """The caller's environment without any GIT_* variable, git reading only
    `gitconfig` (no system file), a pager and editor that do nothing, and
    GIT_OPTIONAL_LOCKS set when given (the reader's 0)."""
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    env.update(GIT_CONFIG_GLOBAL=gitconfig, GIT_CONFIG_NOSYSTEM="1", GIT_PAGER="cat", GIT_EDITOR="true",
               GIT_TERMINAL_PROMPT="0")
    if home:
        env["HOME"] = home
    if optional_locks is not None:
        env["GIT_OPTIONAL_LOCKS"] = str(optional_locks)
    return env


def git(cwd, args, env, check=False):
    """Run git with `args` (a list, or a string for the shell) in `cwd`."""
    shell = isinstance(args, str)
    cmd = args if shell else ["git"] + list(args)
    r = subprocess.run(cmd, cwd=cwd, env=env, shell=shell, capture_output=True, text=True)
    if check and r.returncode:
        raise RigError("git %s in %s: rc %d: %s" % (args, cwd, r.returncode, r.stderr.strip()[:300]))
    return r


def seed_repo(path, env):
    """A small repository at `path` with some history: three commits, a tag,
    a second branch; README.md, LICENSE and src/ in its tree."""
    def w(name, text):
        os.makedirs(os.path.dirname(os.path.join(path, name)) or path, exist_ok=True)
        with open(os.path.join(path, name), "a") as f:
            f.write(text)
    os.makedirs(path, exist_ok=True)
    git(path, ["init", "-q", "-b", "main"], env, check=True)
    w("README.md", "# rig repository\n")
    w("LICENSE", "no licence: test data\n")
    w("src/one.txt", "one\n")
    git(path, ["add", "-A"], env, check=True)
    git(path, ["commit", "-qm", "first"], env, check=True)
    w("src/two.txt", "two\n")
    git(path, ["add", "-A"], env, check=True)
    git(path, ["commit", "-qm", "second"], env, check=True)
    git(path, ["tag", "v-rig"], env, check=True)
    git(path, ["branch", "side"], env, check=True)
    w("README.md", "more\n")
    git(path, ["commit", "-qam", "third"], env, check=True)


# --- the case output convention (tests/gsync) ------------------------------------------
class Checks:
    """`ok   - ` / `FAIL - ` lines, detail lines indented five spaces, and
    `# ` lines for readings; the suite counts the first two."""

    def __init__(self):
        self.passed = self.failed = 0

    def check(self, desc, cond, detail=None):
        if cond:
            print("ok   - " + desc, flush=True)
            self.passed += 1
        else:
            print("FAIL - " + desc, flush=True)
            self.failed += 1
            if detail is not None:
                for line in str(detail).splitlines() or [""]:
                    print("     " + line, flush=True)
        return bool(cond)

    @staticmethod
    def note(text):
        for line in str(text).splitlines() or [""]:
            print("# " + line, flush=True)

    def exit(self):
        sys.exit(1 if self.failed else 0)


def stamp():
    """Wall-clock time to the millisecond, for a record of steps."""
    t = time.time()
    return time.strftime("%H:%M:%S", time.localtime(t)) + ".%03d" % int((t % 1) * 1000)


if __name__ == "__main__":
    print(__doc__)
    sys.exit(2)
