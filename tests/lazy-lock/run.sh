#!/usr/bin/env bash
# Regression suite for lazy.nvim's lock on the reader (org/machines/
# transport-2026-10, rules.md fedxps-5; written 2026-10-26 at step 5a, from the
# battery's lazytest/t.sh and refute-config's lazy/t3.sh case t5).
#
# What it covers: nvim/lua/config/role.lua whole -- the role read from the two
# host files, checked against git's own reading of every fixture, and the
# lockfile it hands lazy -- and nvim/lua/config/lazy.lua's wiring of it, run
# with lazy's setup() stubbed so that no LazyVim spec loads. The lock's
# behaviour runs through the real lazy.nvim, copied in from this machine's
# ~/.local/share/nvim/lazy/lazy.nvim, against three local plugin repositories
# and a minimal init that wires role.lua as lazy.lua does: the reader
# receiving a lock with one plugin advanced and one added, an ordinary start
# and `Lazy! restore` leaving the shared lock byte-identical and the plugins
# at the arrived commits, the copy refreshed at every start, and the writer
# writing the shared lock as lazy always has.
#
# Hermetic: HOME and every XDG directory are a sandbox; nvim starts with -u
# naming the sandbox's init, or --clean, never the real configuration; git
# reads no global or system file and may use only file:// (no network). The
# host files are named for this machine's hostname as nvim reads it, the way
# tests/env/run.sh names its fixture: role.lua takes the hostname from the
# kernel through libuv and spawns no `uname`, so a stub could not reach it,
# and the role itself comes from the file's content -- the real fedxps.inc
# for the reader. Caged: tests/cage.sh. Run after any edit to role.lua or
# lazy.lua's setup, or after a lazy.nvim update (about 2 s on bigfed). Last line
# "passed: N  failed: M"; exit 0 iff nothing failed.
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$CFG_ROOT/tests/cage.sh"
cage lazy-lock "$@"

REAL_LAZY="$HOME/.local/share/nvim/lazy/lazy.nvim"
if [[ ! -f "$REAL_LAZY/lua/lazy/init.lua" ]] || ! command -v nvim >/dev/null 2>&1; then
  echo "lazy-lock tests: no nvim, or no lazy.nvim at $REAL_LAZY to copy -- not running" >&2
  echo "passed: 0  failed: 1"
  exit 2
fi
SHARED_REAL="$CFG_ROOT/nvim/lazy-lock.json"
real_sum0="$(sha256sum < "$SHARED_REAL")"

# --- the sandbox ------------------------------------------------------------
SB="$(mktemp -d "${TMPDIR:-/tmp}/lazy-lock-tests.XXXXXX")"
trap 'rm -rf "$SB"' EXIT
H="$SB/home"
while read -r v; do unset "$v"; done < <(compgen -e | grep -E '^(GIT_|NVIM|VIM|MYVIMRC)')
export HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share"
export XDG_STATE_HOME="$H/.local/state" XDG_CACHE_HOME="$H/.cache"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file GIT_TERMINAL_PROMPT=0
export GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid
C="$XDG_CONFIG_HOME/nvim"
HOSTS="$H/Desktop/configs/git/hosts"
STATE_LOCK="$XDG_STATE_HOME/nvim/lazy-lock.json"
SHARED="$C/lazy-lock.json"
mkdir -p "$C/lua/config" "$XDG_DATA_HOME/nvim/lazy" "$HOSTS" "$H/.config/git" "$SB/src"
ln -s "$CFG_ROOT/nvim/lua/config/role.lua" "$C/lua/config/role.lua"
cp -a "$REAL_LAZY" "$XDG_DATA_HOME/nvim/lazy/lazy.nvim"

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
info() { echo "info - $*"; }
must() { "$@" >/dev/null 2>&1 || { echo "SETUP-FAIL: $*"; echo "passed: $pass  failed: $((fail + 1))"; exit 1; }; }
# Every removal goes through sbrm, which removes nothing outside the sandbox,
# so a variable gone wrong cannot reach a real directory.
sbrm() {
  local p
  for p in "$@"; do
    case "$p" in
      "$SB"/?*) rm -rf -- "$p" ;;
      *)
        echo "SETUP-FAIL: refusing to remove '$p', outside the sandbox"
        echo "passed: $pass  failed: $((fail + 1))"
        exit 1
        ;;
    esac
  done
}

NVHOST="$(nvim --clean --headless -i NONE -c 'lua io.stdout:write(((vim.uv.os_gethostname() or ""):gsub("%..*$", ""):lower():gsub("%s", "")))' -c 'qa!' 2>/dev/null)"
if [[ -z "$NVHOST" ]]; then
  echo "SETUP-FAIL: nvim reports no hostname"
  echo "passed: 0  failed: 1"
  exit 1
fi
OWN="$HOSTS/$NVHOST.inc"
LINK="$H/.config/git/host.inc"

# --- 1. the role, against git's reading of the same files -------------------
# git's reading is 10-env.sh's: a file present but no readable regular file,
# or one git cannot parse, is a reader; else any gsync.role but writer, or any
# non-empty gsync.readerRepo.
echo "== the role, read without git, against git =="
role_lua() { nvim --clean --headless -i NONE --cmd "set rtp^=$C" -c 'lua io.stdout:write(require("config.role").reader() and "reader" or "writer")' -c 'qa!' 2>/dev/null; }
role_git() {
  local f out rc key val verdict=writer files=()
  files+=("$OWN")
  if [[ -L "$LINK" || -e "$LINK" ]]; then
    f="$(readlink -e -- "$LINK")" || { echo reader; return; }
    files+=("$f")
  fi
  for f in "${files[@]}"; do
    [[ -e "$f" || -L "$f" ]] || continue
    if [[ ! -f "$f" || ! -r "$f" ]]; then echo reader; return; fi
    out="$(git -C / config -f "$f" --includes --get-regexp '^gsync\.' 2>/dev/null)"
    rc=$?
    ((rc > 1)) && { echo reader; return; }
    while read -r key val; do
      case "$key" in
        gsync.role) [[ "$val" == writer ]] || verdict=reader ;;
        gsync.readerrepo) [[ -n "$val" ]] && verdict=reader ;;
      esac
    done <<<"$out"
  done
  echo "$verdict"
}
# fixture NAME EXPECTED CONTENT: the hostname's file holds CONTENT (printf %b);
# fixture_of NAME EXPECTED FILE: it is a copy of FILE. Two checks each: git's
# verdict is the expected one, and role.lua's is git's.
judge() {
  local name=$1 want=$2 lua gitv
  lua="$(role_lua)"
  gitv="$(role_git)"
  check "$name: git reads $want" [ "$gitv" = "$want" ]
  check "$name: role.lua agrees ($lua)" [ "$lua" = "$gitv" ]
}
fixture() { sbrm "$OWN"; printf '%b' "$3" > "$OWN"; judge "$1" "$2"; }
fixture_of() { sbrm "$OWN"; cp "$3" "$OWN"; judge "$1" "$2"; }
sbrm "$OWN" "$LINK"
check "no host file, no link: a writer" [ "$(role_lua)" = writer ]
fixture_of "the real fedxps.inc" reader "$CFG_ROOT/git/hosts/fedxps.inc"
fixture_of "the real bigfed.inc" writer "$CFG_ROOT/git/hosts/bigfed.inc"
fixture "role = writer" writer '[gsync]\n\trole = writer\n'
fixture "role = reader" reader '[gsync]\n\trole = reader\n'
fixture "a typo in the role" reader '[gsync]\n\trole = readr\n'
fixture "an empty role" reader '[gsync]\n\trole =\n'
fixture "a bare role (boolean)" reader '[gsync]\n\trole\n'
fixture "the pilot key" reader '[gsync]\n\treaderRepo = nousowl\n'
fixture "an empty readerRepo" writer '[gsync]\n\treaderRepo =\n'
fixture "keys and section in capitals" reader '[GSYNC]\n\tROLE = reader\n'
fixture "readerRepo in mixed case" reader '[gsync]\n\tReaderRepo = nousowl\n'
fixture "the role commented with #" writer '[gsync]\n\t#role = reader\n'
fixture "the role commented with ;" writer '[gsync]\n\t; role = reader\n'
fixture "an inline comment after writer" writer '[gsync]\n\trole = writer # the writer\n'
fixture "a quoted writer" writer '[gsync]\n\trole = "writer"\n'
fixture "a quoted value holding a #" reader '[gsync]\n\trole = "writer # no"\n'
fixture "writer, then reader" reader '[gsync]\n\trole = writer\n\trole = reader\n'
fixture "a subsection is another key" writer '[gsync "x"]\n\trole = reader\n'
fixture "a dotted section is another key" writer '[gsync.x]\n\trole = reader\n'
fixture "a role in another section" writer '[core]\n\trole = reader\n'
fixture "no gsync section" writer '[core]\n\tcheckStat = minimal\n'
fixture "a line git cannot parse" reader '[core]\n\tcheck_stat = minimal\n[gsync]\n\trole = writer\n'
fixture "a key before any section, which git reads in no section" writer 'role = reader\n'
fixture "a broken section header" reader '[gsync\n\trole = writer\n'
fixture "a header with spaces inside its brackets" reader '[ gsync ]\n\trole = writer\n'
fixture "a key on the header's line: writer" writer '[gsync] role = writer\n'
fixture "a key on the header's line: reader" reader '[gsync] role = reader\n'
printf '[gsync]\n\trole = reader\n' > "$HOSTS/inc-reader.inc"
fixture "a role through an [include]" reader '[include]\n\tpath = inc-reader.inc\n'
fixture "a missing include, skipped as git skips it" writer '[include]\n\tpath = absent.inc\n[gsync]\n\trole = writer\n'
fixture "an include through ~/" reader '[include]\n\tpath = ~/Desktop/configs/git/hosts/inc-reader.inc\n'
printf '[gsync]\n\trole = writer\n' > "$OWN"
chmod 000 "$OWN"
check "a host file this user cannot read: git's reading (10-env.sh) says reader" [ "$(role_git)" = reader ]
check "a host file this user cannot read: role.lua says reader" [ "$(role_lua)" = reader ]
chmod 644 "$OWN"
sbrm "$OWN"
mkdir "$OWN"
check "a directory where the host file goes: role.lua says reader" [ "$(role_lua)" = reader ]
rmdir "$OWN"
# the second source: the file ~/.config/git/host.inc points at
printf '[gsync]\n\trole = reader\n' > "$HOSTS/other.inc"
ln -s ../../Desktop/configs/git/hosts/other.inc "$LINK"
check "no hostname file, the link to a reader file: reader" [ "$(role_lua)" = reader ]
printf '[gsync]\n\trole = writer\n' > "$OWN"
check "the hostname's file a writer, the link a reader: reader (the stricter holds)" [ "$(role_lua)" = reader ]
ln -sfn ../../Desktop/configs/git/hosts/absent.inc "$LINK"
check "a dangling link: reader" [ "$(role_lua)" = reader ]
ln -sfn ../../Desktop/configs/git/hosts/$NVHOST.inc "$LINK"
check "the link to the hostname's own writer file: writer" [ "$(role_lua)" = writer ]
sbrm "$LINK" "$OWN" "$HOSTS/other.inc"

# --- 2. lazy.lua's wiring, with lazy's setup stubbed -----------------------
echo "== lazy.lua passes role.lua's lockfile =="
cat > "$SB/stub.lua" <<EOF
local captured
package.loaded["lazy"] = { setup = function(opts) captured = opts end }
dofile("$CFG_ROOT/nvim/lua/config/lazy.lua")
io.stdout:write(captured and tostring(captured.lockfile) or "setup-not-called")
EOF
wiring() { nvim --clean --headless -i NONE --cmd "set rtp^=$C" -c "luafile $SB/stub.lua" -c 'qa!' 2>/dev/null; }
printf '{ "pX": { "branch": "main", "commit": "0000000000000000000000000000000000000001" } }\n' > "$SHARED"
cp "$CFG_ROOT/git/hosts/fedxps.inc" "$OWN"
sbrm "$STATE_LOCK"
check "reader: lazy.lua hands setup() the copy under stdpath(\"state\")" [ "$(wiring)" = "$STATE_LOCK" ]
check "reader: the copy is the shared lock, byte for byte" cmp -s "$SHARED" "$STATE_LOCK"
cp "$CFG_ROOT/git/hosts/bigfed.inc" "$OWN"
sbrm "$STATE_LOCK"
check "writer: lazy.lua hands setup() no lockfile (lazy's default, the tracked lock)" [ "$(wiring)" = nil ]
check "writer: no copy is made" [ ! -e "$STATE_LOCK" ]

# --- 2b. no place for the copy (the reviewer's case, 2026-10-26) ------------
# The state directory's place taken by a file: vim.fn.mkdir raises E739. The
# copy falls back to stdpath("cache"), then to the session's temporary
# directory, each with a WARN; with neither, nil and a WARN that the shared
# lock may be written. lazy.lua's own pcall keeps a fault in role.lua from
# stopping lazy's setup.
echo "== no place for the reader's copy =="
cat > "$SB/probe.lua" <<EOF
local msgs = {}
vim.notify = function(m) msgs[#msgs + 1] = m end
if vim.env.PROBE_NO_TMP == "1" then
  vim.fn.tempname = function() return "$SB/blocker/x/y" end
end
local ok, p = pcall(function() return require("config.role").lazy_lockfile() end)
local same = "-"
if ok and p then
  local a, b = io.open(p, "rb"), io.open("$SHARED", "rb")
  same = (a and b and a:read("*a") == b:read("*a")) and "same" or "differs"
end
io.stdout:write((ok and tostring(p) or ("ERROR " .. tostring(p))) .. "\t" .. same .. "\t" .. table.concat(msgs, " | "))
EOF
probe() { nvim --clean --headless -i NONE --cmd "set rtp^=$C" -c "luafile $SB/probe.lua" -c 'qa!' 2>/dev/null; }
field() { cut -f"$1" <<<"$2"; }
has() { [[ "$1" == *"$2"* ]]; }
tmpdir_ok() { [[ "$1" == /*/lazy-lock.json && "$1" != "$C"/* && "$1" != "$XDG_STATE_HOME"/* && "$1" != "$XDG_CACHE_HOME"/* ]]; }
: > "$SB/blocker"
cp "$CFG_ROOT/git/hosts/fedxps.inc" "$OWN"
sbrm "$H/.local/state/nvim" "$H/.cache/nvim"
mkdir -p "$H/.local/state" "$H/.cache"
: > "$H/.local/state/nvim"
out="$(probe)"
check "state's place a file: the copy goes under stdpath(\"cache\")" [ "$(field 1 "$out")" = "$H/.cache/nvim/lazy-lock.json" ]
check "state's place a file: that copy is the shared lock" [ "$(field 2 "$out")" = same ]
check "state's place a file: a WARN names where the lock went" has "$(field 3 "$out")" 'kept under stdpath("cache")'
check "state's place a file: through lazy.lua, setup() gets the cache copy" [ "$(wiring)" = "$H/.cache/nvim/lazy-lock.json" ]
sbrm "$H/.local/state/nvim" "$H/.cache/nvim"
mkdir -p "$H/.local/state/nvim/lazy-lock.json"
out="$(probe)"
check "the copy's own place a directory: the copy goes under stdpath(\"cache\")" [ "$(field 1 "$out")" = "$H/.cache/nvim/lazy-lock.json" ]
check "the copy's own place a directory: a WARN names where the lock went" has "$(field 3 "$out")" 'kept under stdpath("cache")'
sbrm "$H/.local/state/nvim"
: > "$H/.local/state/nvim"
sbrm "$H/.cache/nvim"
: > "$H/.cache/nvim"
out="$(probe)"
check "state's and cache's places files: the copy goes to the session's temporary directory" tmpdir_ok "$(field 1 "$out")"
check "  and is the shared lock" [ "$(field 2 "$out")" = same ]
check "  with a WARN naming it" has "$(field 3 "$out")" "kept under the session's temporary directory"
out="$(PROBE_NO_TMP=1 probe)"
check "no place at all: nil, lazy's default" [ "$(field 1 "$out")" = nil ]
check "  with a WARN that lazy may write the shared lock this session" \
  has "$(field 3 "$out")" 'lazy may write the shared lazy-lock.json this session'
sbrm "$H/.cache/nvim" "$H/.local/state/nvim"
mv "$C/lua/config/role.lua" "$SB/role.lua.aside"
printf 'error("a fault planted by the suite")\n' > "$C/lua/config/role.lua"
check "a role.lua that raises: lazy.lua still calls setup(), with lazy's default" [ "$(wiring)" = nil ]
sbrm "$C/lua/config/role.lua"
mv "$SB/role.lua.aside" "$C/lua/config/role.lua"
sbrm "$SHARED"

# --- 3. the lock through the real lazy.nvim -------------------------------
mk() { # a plugin repository with commit v1
  must git init -q -b main "$SB/src/$1"
  mkdir -p "$SB/src/$1/lua/$1"
  echo "return 1" > "$SB/src/$1/lua/$1/init.lua"
  must git -C "$SB/src/$1" add -A
  must git -C "$SB/src/$1" commit -qm v1
}
mk pA
mk pB
mk pC
echo "return 2" > "$SB/src/pA/lua/pA/init.lua"
must git -C "$SB/src/pA" commit -qam v2
V1A="$(git -C "$SB/src/pA" rev-parse HEAD~1)"
V2A="$(git -C "$SB/src/pA" rev-parse HEAD)"
V1B="$(git -C "$SB/src/pB" rev-parse HEAD)"
V1C="$(git -C "$SB/src/pC" rev-parse HEAD)"
ROOT="$SB/plugins"
# The minimal init: role.lua wired as lazy.lua wires it, and a spec of local
# plugins in place of LazyVim's; WITH_PC=1 adds the plugin that arrives.
cat > "$C/init.lua" <<EOF
vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/lazy/lazy.nvim")
local lockfile = require("config.role").lazy_lockfile()
local spec = {
  { url = "file://$SB/src/pA", name = "pA" },
  { url = "file://$SB/src/pB", name = "pB" },
}
if vim.env.WITH_PC == "1" then
  spec[#spec + 1] = { url = "file://$SB/src/pC", name = "pC" }
end
require("lazy").setup(spec, {
  root = "$ROOT",
  lockfile = lockfile,
  checker = { enabled = false },
  change_detection = { enabled = false },
  rocks = { enabled = false },
  install = { colorscheme = {} },
  performance = { reset_packpath = false, rtp = { reset = false } },
})
EOF
nv() { WITH_PC=${WITH_PC:-0} timeout 60 nvim --headless -i NONE -u "$C/init.lua" "$@" +qa >/dev/null 2>&1; }
head_of() { git -C "$ROOT/$1" rev-parse HEAD 2>/dev/null || echo absent; }
writelock() { # writelock FILE NAME=COMMIT...
  local f=$1
  shift
  python3 -I -c 'import json, sys
d = {}
for a in sys.argv[2:]:
    n, c = a.split("=", 1)
    d[n] = {"branch": "main", "commit": c}
json.dump(d, open(sys.argv[1], "w"), indent=2)' "$f" "$@"
}
lockcommit() { python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], {}).get("commit", "-"))' "$1" "$2"; }
sum() { sha256sum < "$1"; }

echo "== the reader: a lock arrives with one plugin advanced and one added =="
cp "$CFG_ROOT/git/hosts/fedxps.inc" "$OWN"
sbrm "$ROOT" "$STATE_LOCK"
writelock "$SHARED" pA="$V1A" pB="$V1B"
s0="$(sum "$SHARED")"
WITH_PC=0 nv
check "before the arrival: pA at v1" [ "$(head_of pA)" = "$V1A" ]
check "before the arrival: pB at v1" [ "$(head_of pB)" = "$V1B" ]
check "the first start leaves the shared lock byte-identical" [ "$(sum "$SHARED")" = "$s0" ]
check "lazy wrote its own copy under stdpath(\"state\")" [ -f "$STATE_LOCK" ]
# bigfed advanced pA and added pC; its lock and its spec arrive
writelock "$SHARED" pA="$V2A" pB="$V1B" pC="$V1C"
s1="$(sum "$SHARED")"
WITH_PC=1 nv
check "an ordinary start leaves the arrived lock byte-identical" [ "$(sum "$SHARED")" = "$s1" ]
check "the ordinary start installs the added pC at its locked commit" [ "$(head_of pC)" = "$V1C" ]
info "after the ordinary start pA is at $([[ "$(head_of pA)" == "$V2A" ]] && echo v2 || echo v1) (a start installs, it does not restore)"
WITH_PC=1 nv "+Lazy! restore"
check "Lazy! restore leaves the arrived lock byte-identical" [ "$(sum "$SHARED")" = "$s1" ]
check "after the restore pA is at the arrived commit (v2)" [ "$(head_of pA)" = "$V2A" ]
check "after the restore pB is at the arrived commit" [ "$(head_of pB)" = "$V1B" ]
check "after the restore pC is at the arrived commit" [ "$(head_of pC)" = "$V1C" ]
check "the reader's copy records the arrived commits" [ "$(lockcommit "$STATE_LOCK" pA)" = "$V2A" ]
# The copy is made afresh at every start, whatever its age: a copy rewritten
# after the shared lock arrived (newer mtime, other content) is replaced.
writelock "$STATE_LOCK" pA="$V1A" pB="$V1B" pC="$V1C"
touch -d '+1 hour' "$STATE_LOCK"
WITH_PC=1 nv
check "a newer copy with other content is replaced from the shared lock at the next start" cmp -s "$SHARED" "$STATE_LOCK"
check "and the shared lock is still byte-identical" [ "$(sum "$SHARED")" = "$s1" ]

# nvim itself when the copy has no place under stdpath("state"). Where only
# the copy's own place is taken (a directory where the file goes), lazy sets
# up and installs against the cache copy. Where the state directory's place
# is a file, lazy.nvim keeps its own package cache, readme and state.json under
# stdpath("state") and raises its own E739 in setup(): nvim starts without
# plugins by lazy's doing, and the shared lock is still untouched.
echo "== the reader: no place for the copy, through nvim =="
sbrm "$ROOT" "$H/.local/state/nvim" "$H/.cache/nvim"
mkdir -p "$H/.local/state/nvim/lazy-lock.json"
writelock "$SHARED" pA="$V2A" pB="$V1B" pC="$V1C"
s4="$(sum "$SHARED")"
WITH_PC=1 nv
check "the copy's place a directory: lazy installs pA at its locked commit" [ "$(head_of pA)" = "$V2A" ]
check "the copy's place a directory: and pC" [ "$(head_of pC)" = "$V1C" ]
check "the copy's place a directory: the shared lock is byte-identical" [ "$(sum "$SHARED")" = "$s4" ]
check "the copy's place a directory: lazy's copy is under stdpath(\"cache\")" [ -f "$H/.cache/nvim/lazy-lock.json" ]
sbrm "$ROOT" "$H/.local/state/nvim" "$H/.cache/nvim"
: > "$H/.local/state/nvim"
WITH_PC=1 nv
check "the state's place a file: the shared lock is byte-identical" [ "$(sum "$SHARED")" = "$s4" ]
info "the state's place a file: pA $(head_of pA) (lazy's own E739 for its package cache stops its setup)"
sbrm "$H/.local/state/nvim" "$H/.cache/nvim"

echo "== the reader: Lazy! restore as the first start after an arrival =="
sbrm "$ROOT" "$STATE_LOCK"
writelock "$SHARED" pA="$V1A" pB="$V1B"
WITH_PC=0 nv
writelock "$SHARED" pA="$V2A" pB="$V1B" pC="$V1C"
s2="$(sum "$SHARED")"
WITH_PC=1 nv "+Lazy! restore"
check "a first-start restore leaves the arrived lock byte-identical" [ "$(sum "$SHARED")" = "$s2" ]
info "after a first-start restore pA is at $([[ "$(head_of pA)" == "$V2A" ]] && echo 'v2 (converged)' || echo 'v1: the start installed pC and lazy rewrote its copy from what was installed before the restore read it')"
WITH_PC=1 nv "+Lazy! restore"
check "a second restore converges: pA at the arrived commit" [ "$(head_of pA)" = "$V2A" ]
check "and pC at its arrived commit" [ "$(head_of pC)" = "$V1C" ]
check "and the shared lock is still byte-identical" [ "$(sum "$SHARED")" = "$s2" ]

echo "== the writer: the shared lock is the one written =="
cp "$CFG_ROOT/git/hosts/bigfed.inc" "$OWN"
sbrm "$ROOT" "$STATE_LOCK"
writelock "$SHARED" pA="$V1A" pB="$V1B"
WITH_PC=0 nv
writelock "$SHARED" pA="$V2A" pB="$V1B" pC="$V1C"
s3="$(sum "$SHARED")"
WITH_PC=1 nv "+Lazy! restore"
check "writer: lazy writes the shared lock (its sum moved)" [ "$(sum "$SHARED")" != "$s3" ]
check "writer: no copy under stdpath(\"state\")" [ ! -e "$STATE_LOCK" ]
check "writer: the shared lock records what is installed (pC)" [ "$(lockcommit "$SHARED" pC)" = "$V1C" ]

check "the checkout's own nvim/lazy-lock.json is untouched by the run" [ "$(sha256sum < "$SHARED_REAL")" = "$real_sum0" ]

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
