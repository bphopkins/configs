#!/usr/bin/env bash
# Regression suite for bash/.bashrc itself: the module loop that never sources a
# Syncthing conflict copy (org/machines/transport-2026-10/rules.md -> ws-4) and
# the arrival line that PS0 prints once when a loaded file changes under an open
# shell (ws-8). Written 2026-10-26 at the campaign's step 5a, on the battery's
# seeds scratch-2026-10-09/refute-config/stow/t.sh (S4) and sig/t2.py there.
#
# Hermetic in the way tests/shell-opts/run.sh is: every shell runs under
# `env -i` with HOME at a fixture and HISTFILE in the sandbox, against the real
# system layer (/etc/bashrc, /etc/profile.d), through both terminal
# integrations: the WezTerm-shaped shell, where /etc/profile.d/wezterm.sh
# installs bash-preexec and its DEBUG trap, and Ghostty's launch, whose
# integration appends its own hook to PS0. The fixture holds COPIES of this
# checkout's .bashrc, .bash_profile and every module, linked into its HOME as
# stow links the real ones, never links into the checkout: the suite touches,
# renames and adds files there. Shells read their commands from a file with
# `bash -i` and report on fd 3, as in shell-opts; the order on screen, and
# bash-preexec, which acts only when stdout is a terminal, are read through a
# pseudo-terminal (a python3 driver written into the sandbox).
#
# Caged: tests/cage.sh. Run after any edit to .bashrc (~9 s). Last line follows
# the tests/gsync convention: "passed: N  failed: M"; exit 0 iff nothing failed.
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$CFG_ROOT/tests/cage.sh"
cage bashrc "$@"

command -v python3 >/dev/null 2>&1 || { echo "bashrc tests: python3 missing -- not running" >&2; echo "passed: 0  failed: 1"; exit 2; }
SB="$(mktemp -d "${TMPDIR:-/tmp}/bashrc-tests.XXXXXX")"
trap 'rm -rf "$SB"' EXIT
H="$SB/home"
cd "$SB" || exit 2
pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }
field() { sed -n "s/^$1=//p" <<<"$2"; }
must() { "$@" || { echo "SETUP-FAIL: $*"; echo "passed: $pass  failed: $((fail + 1))"; exit 1; }; }

# A fresh fixture: copies of the package under $SB/cfg/bash, linked into the
# fixture HOME as stow links them (~/.bashrc, ~/.bash_profile and the whole
# ~/.bashrc.d are links), so a change reaches the shell through a link, as
# Syncthing's or git's does.
mkfix() {
  rm -rf "$H" "$SB/cfg"
  mkdir -p "$H" "$SB/cfg/bash/.bashrc.d"
  cp "$CFG_ROOT/bash/.bashrc" "$CFG_ROOT/bash/.bash_profile" "$SB/cfg/bash/"
  cp "$CFG_ROOT"/bash/.bashrc.d/*.sh "$SB/cfg/bash/.bashrc.d/"
  ln -s ../cfg/bash/.bashrc "$H/.bashrc"
  ln -s ../cfg/bash/.bash_profile "$H/.bash_profile"
  ln -s ../cfg/bash/.bashrc.d "$H/.bashrc.d"
  : >"$SB/hist"
}

BASE=/usr/local/bin:/usr/bin
GHOSTTY_BASH=/usr/share/ghostty/shell-integration/bash/ghostty.bash
COMMON=(HOME="$H" USER="$USER" LOGNAME="$USER" SHELL=/bin/bash PATH="$BASE" HISTFILE="$SB/hist")
WEZ=(env -i "${COMMON[@]}" TERM=xterm-256color /bin/bash -i)
GHO=(env -i "${COMMON[@]}" TERM=xterm-ghostty TERM_PROGRAM=ghostty GHOSTTY_BASH_UNEXPORT_HISTFILE=1 ENV="$GHOSTTY_BASH" GHOSTTY_BASH_INJECT=1 GHOSTTY_SHELL_FEATURES=path,ssh-env,ssh-terminfo,title GHOSTTY_RESOURCES_DIR=/usr/share/ghostty /bin/bash --posix -i)
# shell WEZ|GHO SCRIPT OUT REPORT [VAR=VALUE...]: the script on stdin, stdout and
# stderr together into OUT (the order they were written in), fd 3 into REPORT.
shell() {
  local -n argv="$1"
  local script="$2" out="$3" report="$4"
  shift 4
  local pre=("${argv[@]:0:2}") post=("${argv[@]:2}")
  "${pre[@]}" "$@" "${post[@]}" <"$script" 3>"$report" >"$out" 2>&1
}
ARR="bash modules changed since this shell loaded them: run reload"

# --- 0. the file ---------------------------------------------------------------
echo "== .bashrc =="
check "parses (bash -n)" bash -n "$CFG_ROOT/bash/.bashrc"
mkfix
for term in xterm-256color xterm-ghostty; do
  r="$(env -i "${COMMON[@]}" TERM="$term" /bin/bash --norc --noprofile -i -c 'source ~/.bashrc >"$1" 2>&1; printf "PS0N=%s\n" "$(grep -o _bashrc_arrivals <<<"$PS0" | wc -l)"; source ~/.bashrc >>"$1" 2>&1; printf "PS0N2=%s\n" "$(grep -o _bashrc_arrivals <<<"$PS0" | wc -l)"' _ "$SB/load.$term" 2>/dev/null)"
  check "TERM=$term: sourcing ~/.bashrc prints nothing"         [ ! -s "$SB/load.$term" ]
  check "TERM=$term: PS0 carries the check once"                [ "$(field PS0N "$r")" = 1 ]
  check "TERM=$term: and once after sourcing it again (reload)" [ "$(field PS0N2 "$r")" = 1 ]
done

# --- 1. ws-4: a module's conflict copy is never sourced, in any locale --------
echo "== a conflict copy of 50-git-sync.sh, in three locales =="
mkfix
COPY="50-git-sync.sync-conflict-20261009-120000-ABCDEFG.sh"
printf '%s\n' 'gpushall() { echo "the conflict copy'"'"'s gpushall"; }' 'CONFLICT_COPY_SOURCED=yes' >"$SB/cfg/bash/.bashrc.d/$COPY"
cat >"$SB/s1" <<'S'
{ cd ~/.bashrc.d && printf 'ORDER=%s\n' "$(printf '%s ' *.sh)"; cd ~
  printf 'ORIGINAL=%s\n' "$(declare -f gpushall | grep -c 'Committing and pushing')"
  printf 'SOURCED=%s\n' "${CONFLICT_COPY_SOURCED-no}"; } >&3
exit
S
for loc in en_US.UTF-8 C.UTF-8 C; do
  shell WEZ "$SB/s1" "$SB/o1" "$SB/r1" LANG="$loc" LC_ALL="$loc"
  r="$(<"$SB/r1")"
  order="$(field ORDER "$r")"
  check "$loc: the copy sorts after the original here (the case has teeth)" bash -c '[[ "$1" == *"50-git-sync.sh "*"$2"* ]]' _ "$order" "$COPY"
  check "$loc: gpushall is the original's"                  [ "$(field ORIGINAL "$r")" = 1 ]
  check "$loc: the copy's own lines never ran"              [ "$(field SOURCED "$r")" = no ]
done

# --- 2. ws-8: the arrival line, once per change, before the command's output ---
# The tokens the run printed, in order: the markers, the arrival line (ARR) and
# reload's confirmation. Each line of the script is one command line.
cat >"$SB/s2" <<'S'
echo "MARK-$((1))"
touch -d '2001-01-01 00:00' ~/.bashrc.d/70-task-list.sh
echo "MARK-$((2))"
echo "MARK-$((3))"
f=~/.bashrc.d/85-disk.sh; cp -p "$f" "$f.part"; touch -d '2001-01-01 00:00' "$f.part"; mv "$f.part" "$f"
echo "MARK-$((4))"
printf 'NEW_MODULE=1\n' > ~/.bashrc.d/95-new.sh
echo "MARK-$((5))"
printf 'X=1\n' > ~/.bashrc.d/50-git-sync.sync-conflict-20261026-101010-ABCDEFG.sh
echo "MARK-$((6))"
touch ~/.bashrc.d/30-prompt.sh; (exit 7)
echo "RC=$?"
touch ~/.bash_profile; echo a b lastword
echo "LAST=$_"
touch ~/.bashrc.d/10-env.sh
reload
echo "MARK-$((7))"
printf 'PS0N=%s\nNEW=%s\n' "$(grep -o _bashrc_arrivals <<<"$PS0" | wc -l)" "${NEW_MODULE-unset}" >&3
exit
S
tokens() { grep -oE "MARK-[0-9]+|RC=[0-9]+|LAST=[a-z]+|bashrc reloaded|$ARR" "$1" | sed "s/^$ARR\$/ARR/" | tr '\n' ' '; }
WANT="MARK-1 ARR MARK-2 MARK-3 ARR MARK-4 ARR MARK-5 MARK-6 ARR RC=7 ARR LAST=lastword ARR bashrc reloaded MARK-7 "
for sh in WEZ GHO; do
  [[ $sh == GHO && ! -r $GHOSTTY_BASH ]] && { echo "skip - $sh (no $GHOSTTY_BASH here)"; continue; }
  echo "== the arrival line, $sh =="
  mkfix
  shell "$sh" "$SB/s2" "$SB/o2" "$SB/r2"
  seq="$(tokens "$SB/o2")"
  r="$(<"$SB/r2")"
  check "$sh: the whole run reads as expected"              [ "$seq" = "$WANT" ]
  check "$sh: nothing before the first change"             bash -c '[[ "$1" == "MARK-1 ARR"* ]]' _ "$seq"
  check "$sh: an old mtime touched in place fires it, before the next command's output" contains "$seq" "MARK-1 ARR MARK-2 "
  check "$sh: and not again"                                contains "$seq" "MARK-2 MARK-3 "
  check "$sh: a rename into place with an old mtime fires it" contains "$seq" "MARK-3 ARR MARK-4 "
  check "$sh: a new module fires it"                        contains "$seq" "MARK-4 ARR MARK-5 "
  check "$sh: a conflict copy arriving does not"            contains "$seq" "MARK-5 MARK-6 "
  check "$sh: \$? survives the check"                       contains "$seq" "ARR RC=7 "
  check "$sh: \$_ survives the check"                       contains "$seq" "ARR LAST=lastword "
  check "$sh: ~/.bash_profile counts"                       contains "$seq" "RC=7 ARR LAST"
  check "$sh: reload: the line at its own command, then quiet" contains "$seq" "ARR bashrc reloaded MARK-7 "
  check "$sh: reload keeps one check in PS0"                [ "$(field PS0N "$r")" = 1 ]
  check "$sh: reload loaded the new module"                 [ "$(field NEW "$r")" = 1 ]
done

# --- 3. on a terminal: the order on screen, and the hooks still firing ---------
# The driver types a line, waits for its DONE marker, waits for the prompt to
# settle, types the next. OSC 133;C is the mark both integrations print when a
# command's output starts: bash-preexec's preexec under the WezTerm-shaped
# shell (its DEBUG trap), Ghostty's own PS0 hook under Ghostty.
cat >"$SB/pty.py" <<'PY'
import os, pty, select, sys, time
lines = open(sys.argv[1]).read().splitlines()
argv = sys.argv[3:]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(argv[0], argv)
buf = bytearray()
def pump(until, cap):
    end = time.time() + cap
    last = time.time()
    while time.time() < end:
        if until(last):
            return True
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                data = os.read(fd, 65536)
            except OSError:
                return until(last)
            if not data:
                return until(last)
            buf.extend(data)
            last = time.time()
    return until(last)
def quiet(t):
    return lambda last: time.time() - last >= t
pump(quiet(0.5), 10)
ok = 1
for i, line in enumerate(lines, 1):
    os.write(fd, line.encode() + b"\r")
    mark = ("DONE-%d\r\n" % i).encode()
    if not pump(lambda last: mark in buf, 10):
        ok = 0
        break
    pump(quiet(0.2), 3)
os.write(fd, b"exit\r")
pump(lambda last: False, 3)
try:
    os.kill(pid, 9)
except ProcessLookupError:
    pass
os.waitpid(pid, 0)
open(sys.argv[2], "wb").write(bytes(buf))
sys.exit(0 if ok else 1)
PY
cat >"$SB/s3" <<'S'
echo "MARK-$((1))"; echo "DONE-$((1))"
touch -d '2001-01-01 00:00' ~/.bashrc.d/70-task-list.sh; echo "DONE-$((2))"
echo "MARK-$((2))"; echo "DONE-$((3))"
echo "MARK-$((3))"; echo "DONE-$((4))"
S
# One line of facts about a transcript: where the arrival line sits against the
# third command line's echo, its 133;C and its output, and how many of each.
cat >"$SB/facts.py" <<'PY'
import sys
t = open(sys.argv[1], "rb").read()
arr = sys.argv[2].encode()
c = b"\x1b]133;C;\x07"
typed = t.find(b'echo "MARK-$((2))"')
out = t.find(b"MARK-2\r\n")
a = t.find(arr)
cmark = t.find(c, typed) if typed >= 0 else -1
print("ARRS=%d" % t.count(arr))
print("CMARKS=%d" % t.count(c))
print("ORDER=%s" % ("yes" if -1 < typed < a < cmark < out else "no %d %d %d %d" % (typed, a, cmark, out)))
PY
for sh in WEZ GHO; do
  [[ $sh == GHO && ! -r $GHOSTTY_BASH ]] && { echo "skip - $sh pty (no $GHOSTTY_BASH here)"; continue; }
  [[ $sh == WEZ && ! -r /etc/profile.d/wezterm.sh ]] && { echo "skip - $sh pty (no /etc/profile.d/wezterm.sh here)"; continue; }
  echo "== on a terminal, $sh =="
  declare -n a="$sh"
  # The baseline: the same .bashrc with the one line that installs the check
  # taken out, so the hooks' marks are counted as this system layer prints them.
  mkfix
  sed -i '/PS0+=/d' "$SB/cfg/bash/.bashrc"
  must bash -c "! grep -q 'PS0+=' '$H/.bashrc'"
  python3 -I "$SB/pty.py" "$SB/s3" "$SB/t3.base" "${a[@]}"
  base="$(python3 -I "$SB/facts.py" "$SB/t3.base" "$ARR")"
  mkfix
  python3 -I "$SB/pty.py" "$SB/s3" "$SB/t3" "${a[@]}"; prc=$?
  unset -n a
  r="$(python3 -I "$SB/facts.py" "$SB/t3" "$ARR")"
  check "$sh: every line ran (the driver saw each marker)"  [ "$prc" -eq 0 ]
  check "$sh: the line printed once"                        [ "$(field ARRS "$r")" = 1 ]
  check "$sh: after the typed command, before its 133;C and its output" [ "$(field ORDER "$r")" = yes ]
  check "$sh: as many 133;C marks as without the check ($(field CMARKS "$base")): the hooks fire as before" [ "$(field CMARKS "$r")" = "$(field CMARKS "$base")" ]
  check "$sh: the baseline saw marks at all (the comparison has teeth)" [ "$(field CMARKS "$base")" -ge 4 ]
done

# --- 4. the cost a command ----------------------------------------------------
echo "== the cost =="
mkfix
cat >"$SB/s4" <<'S'
n=300; s=$EPOCHREALTIME
for ((i = 0; i < n; i++)); do _bashrc_arrivals; done
e=$EPOCHREALTIME
printf 'US=%s\n' "$(( (${e/./} - ${s/./}) / n ))" >&3
exit
S
shell WEZ "$SB/s4" "$SB/o4" "$SB/r4"
us="$(field US "$(<"$SB/r4")")"
check "the check costs ${us:-?} us a command (bound: 5000; the battery's form read 1650)" [ "${us:-99999}" -le 5000 ]

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
