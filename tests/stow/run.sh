#!/usr/bin/env bash
# Regression suite for stow-all, stow-all-dry and unstow-all in
# bash/.bashrc.d/60-stow.sh (org/machines/transport-2026-10/rules.md -> ws-8;
# written 2026-10-26 at the campaign's step 5a, on the battery's stow arrivals,
# scratch-2026-10-09/refute-config/stow/t.sh and t2.sh there, S1 and S5).
#
# Sandboxed and caged (tests/cage.sh): a sandbox configs checkout of a few tiny
# packages named from the real STOW_ORDER, a fixture HOME as the target root,
# and a local bare remote. The module under test is a copy of this checkout's
# 60-stow.sh, placed where the real one lives, at the sandbox checkout's
# bash/.bashrc.d/60-stow.sh, with its one STOW_CFG_ROOT line rewritten by sed
# to the sandbox checkout; nothing else in it changes. The suite's own shell
# sources that copy once, as an open terminal's shell did before an arrival,
# and an arrival is the suite editing the sandbox checkout -- files, packages
# and the copy's arrays -- between two runs of that one shell's stow-all, with
# no re-source. Before every run the suite reads the copy on disk in a
# subshell and stops unless HOME, STOW_CFG_ROOT and every target lie in the
# sandbox. Git identity from the environment, no global config, no network.
#
# Run after any edit to 60-stow.sh (~3 s). Last line follows the tests/gsync
# convention: "passed: N  failed: M"; exit 0 iff nothing failed.
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$CFG_ROOT/tests/cage.sh"
cage stow "$@"

for t in stow git find realpath; do command -v "$t" >/dev/null 2>&1 || {
  echo "stow tests: $t missing -- not running" >&2; echo "passed: 0  failed: 1"; exit 2; }; done

SB="$(mktemp -d "${TMPDIR:-/tmp}/stow-tests.XXXXXX")"
trap 'rm -rf "$SB"' EXIT
pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }
must() { "$@" || { echo "SETUP-FAIL: $*"; echo "passed: $pass  failed: $((fail + 1))"; exit 1; }; }
# links_to PATH FILE: PATH resolves, through stow's links, to FILE in the checkout
links_to() { [[ "$(realpath -e -- "$1" 2>/dev/null)" == "$(realpath -e -- "$2")" ]]; }
gone() { [[ ! -e "$1" && ! -L "$1" ]]; }
dangling() { find "$HOME" -xtype l 2>/dev/null; }   # every link under HOME that resolves nowhere

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export HOME="$SB/home"
C="$SB/configs"           # the sandbox checkout
CP="$C/bash/.bashrc.d/60-stow.sh"
T="$HOME/.config"
mkdir -p "$HOME" "$C/bash/.bashrc.d"

# The copy: one line rewritten, and only that line.
sed "s|^STOW_CFG_ROOT=.*|STOW_CFG_ROOT=\"$C\"|" "$CFG_ROOT/bash/.bashrc.d/60-stow.sh" > "$CP"
must [ "$(diff "$CFG_ROOT/bash/.bashrc.d/60-stow.sh" "$CP" | grep -c '^[<>]')" -eq 2 ]
must grep -qx "STOW_CFG_ROOT=\"$C\"" "$CP"

# Packages, named from the real STOW_ORDER so the copy's arrays carry them.
mkdir -p "$C/tmux/plugins" "$C/mako" "$C/wofi" "$C/rofi/themes"
echo tmux > "$C/tmux/tmux.conf"; echo plug > "$C/tmux/plugins/p.conf"
echo mako > "$C/mako/config"
echo wofi > "$C/wofi/config"; echo css > "$C/wofi/style.css"
echo rofi > "$C/rofi/config.rasi"; echo theme > "$C/rofi/themes/t.rasi"
must git init -q -b main "$C"
must git -C "$C" add -A
must git -C "$C" commit -qm base
must git init -q --bare -b main "$SB/remote.git"
must git -C "$C" remote add origin "$SB/remote.git"
must git -C "$C" push -qu origin main
must git clone -q "$SB/remote.git" "$SB/peer"

# The guard: the copy as it is on disk names only sandbox paths, read in a
# subshell under this HOME. Run before every stow command below.
guard() {
  local bad
  bad="$(bash -c '
    set -u; source "$1" || { echo "the copy does not source"; exit 0; }
    [[ "$STOW_CFG_ROOT" == "$2"/* ]] || echo "STOW_CFG_ROOT=$STOW_CFG_ROOT"
    for p in "${!STOW_TARGETS[@]}"; do [[ "${STOW_TARGETS[$p]}" == "$2"/* ]] || echo "target $p=${STOW_TARGETS[$p]}"; done
  ' _ "$CP" "$SB" 2>&1)"
  [[ "$HOME" == "$SB"/* ]] || bad+=" HOME=$HOME"
  if [[ -n "$bad" ]]; then
    echo "SETUP-FAIL: the stow commands would reach outside the sandbox: $bad"
    echo "passed: $pass  failed: $((fail + 1))"
    exit 1
  fi
}

# --- 0. the shell loads the module, and the first stow --------------------------
echo "== the first stow =="
guard
source "$CP"
must [ "$STOW_CFG_ROOT" = "$C" ]
for p in "${!STOW_TARGETS[@]}"; do must test "${STOW_TARGETS[$p]#"$SB"/}" != "${STOW_TARGETS[$p]}"; done
loaded_order=" ${STOW_ORDER[*]} "
out="$(stow-all 2>&1)"; rc=$?
check "stow-all: exit 0"                                [ "$rc" -eq 0 ]
check "tmux.conf linked"                                links_to "$T/tmux/tmux.conf" "$C/tmux/tmux.conf"
check "tmux's plugins/ linked (a folded subdirectory)"   links_to "$T/tmux/plugins/p.conf" "$C/tmux/plugins/p.conf"
check "rofi's config.rasi linked"                       links_to "$T/rofi/config.rasi" "$C/rofi/config.rasi"
check "the bash package's .bashrc.d linked into HOME"     links_to "$HOME/.bashrc.d/60-stow.sh" "$CP"
check "no dangling link under HOME"                     [ -z "$(dangling)" ]

# --- 1. an arrival, and the same shell's stow-all, no re-source -----------------
echo "== an arrival: files, a subdirectory, a removal, a rename, packages in and out =="
must git -C "$SB/peer" commit -q --allow-empty -m "the other side ahead"
must git -C "$SB/peer" push -q
head0="$(git -C "$C" rev-parse HEAD)"
echo colors > "$C/wofi/colors.css"                                   # a new top-level file
mkdir -p "$C/wofi/themes"; echo dark > "$C/wofi/themes/dark.css"     # a new top-level subdirectory
rm "$C/wofi/style.css"                                               # a removal
mv "$C/mako/config" "$C/mako/config.main"                            # a rename
rm -r "$C/tmux/plugins"                                              # S5: a folded subdirectory removed
rm -r "$C/rofi"                                                      # S1: a package removed ...
sed -i '/^  \[rofi\]=/d; s/^\(STOW_ORDER=(.*\) rofi\(.*\)$/\1\2/' "$CP"  # ... and its lines, as the other machine left them
mkdir -p "$C/kitty"; echo kitty > "$C/kitty/kitty.conf"              # a package added ...
sed -i 's|^  \[wezterm\]="$HOME"$|&\n  [kitty]="$HOME/.config/kitty"|; s/^\(STOW_ORDER=(.*\))$/\1 kitty)/' "$CP"  # ... with its lines
must grep -q '^  \[kitty\]="$HOME/.config/kitty"$' "$CP"
must grep -q '^STOW_ORDER=(.* kitty)$' "$CP"
must bash -c "! grep -q 'rofi' '$CP'"
must bash -n "$CP"
guard
out="$(stow-all 2>&1)"; rc=$?
check "stow-all after the arrival: exit 0"              [ "$rc" -eq 0 ]
check "this shell was not re-sourced (its STOW_ORDER lacks kitty)" lacks "$loaded_order" " kitty "
check "this shell's STOW_ORDER still names rofi"         contains "$loaded_order" " rofi "
check "the new top-level file is linked"                links_to "$T/wofi/colors.css" "$C/wofi/colors.css"
check "the new top-level subdirectory is linked"        links_to "$T/wofi/themes/dark.css" "$C/wofi/themes/dark.css"
check "the removed file's link is gone"                 gone "$T/wofi/style.css"
check "the rename: the new name linked"                 links_to "$T/mako/config.main" "$C/mako/config.main"
check "the rename: the old name's link gone"            gone "$T/mako/config"
check "S5: the removed subdirectory's folded link gone"  gone "$T/tmux/plugins"
check "S5: the rest of tmux still linked"               links_to "$T/tmux/tmux.conf" "$C/tmux/tmux.conf"
check "S1: the removed package's links gone (1/2)"      gone "$T/rofi/config.rasi"
check "S1: the removed package's links gone (2/2)"      gone "$T/rofi/themes"
check "S1: named in the output"                         contains "$out" "package rofi is gone from the checkout"
check "the added package is stowed with no re-source"   links_to "$T/kitty/kitty.conf" "$C/kitty/kitty.conf"
check "no dangling link anywhere under HOME"            [ -z "$(dangling)" ]
check "the remote ahead stays un-pulled: HEAD unchanged" [ "$(git -C "$C" rev-parse HEAD)" = "$head0" ]
check "the remote is ahead indeed (the peer's commit is there)" [ "$(git -C "$SB/remote.git" rev-parse main)" != "$head0" ]
check "no git output in stow-all's"                     lacks "$out" "Already up to date"

# --- 2. the half-arrived removal: the file still names the package -------------
echo "== a package directory gone while 60-stow.sh still names it =="
mkdir -p "$C/swaylock"; echo lock > "$C/swaylock/config"
guard
out="$(stow-all 2>&1)"; rc=$?
must links_to "$T/swaylock/config" "$C/swaylock/config"
rm -r "$C/swaylock"
out="$(stow-all 2>&1)"; rc=$?
check "exit 0"                                          [ "$rc" -eq 0 ]
check "its link is gone"                                gone "$T/swaylock/config"
check "no dangling link under HOME"                     [ -z "$(dangling)" ]

# --- 3. the sweep removes nothing else ------------------------------------------
echo "== the removed package's sweep touches only its own dangling links =="
mkdir -p "$C/sway"; echo sway > "$C/sway/config"; echo keep > "$SB/elsewhere"
guard
out="$(stow-all 2>&1)"
mkdir -p "$T/sway/own"; echo mine > "$T/sway/own/file"              # his own file beside the links
ln -s "$SB/elsewhere" "$T/sway/other-link"                           # a link pointing elsewhere
ln -s "$SB/nowhere" "$T/sway/other-dangling"                         # a dangling link pointing elsewhere
rm -r "$C/sway"
out="$(stow-all 2>&1)"; rc=$?
check "exit 0"                                          [ "$rc" -eq 0 ]
check "the package's own link is gone"                  gone "$T/sway/config"
check "his own file stays"                              [ "$(cat "$T/sway/own/file")" = mine ]
check "a link pointing elsewhere stays"                 [ -L "$T/sway/other-link" ]
check "a dangling link pointing elsewhere stays"        [ -L "$T/sway/other-dangling" ]
rm -rf "$T/sway"

# --- 3b. a shell opened after the removal: its arrays never named the package --
echo "== a package gone from the checkout and from 60-stow.sh, swept by a shell opened after =="
mkdir -p "$C/mako/sub"; echo m > "$C/mako/sub/deep.conf"
guard
out="$(stow-all 2>&1)"
must links_to "$T/mako/sub/deep.conf" "$C/mako/sub/deep.conf"
rm -r "$C/mako"
sed -i '/^  \[mako\]=/d; s/^\(STOW_ORDER=(.*\) mako\(.*\)$/\1\2/' "$CP"
must bash -c "! grep -q '^  \\[mako\\]=' '$CP'"
guard
out="$(bash -c 'source "$1" && stow-all' _ "$CP" 2>&1)"; rc=$?
check "a fresh shell's stow-all: exit 0"                [ "$rc" -eq 0 ]
check "the fresh shell's arrays never named mako"        bash -c '! (source "$1"; [[ " ${STOW_ORDER[*]} ${!STOW_TARGETS[*]} " == *" mako "* ]])' _ "$CP"
check "mako's links are gone (config.main)"             gone "$T/mako/config.main"
check "mako's links are gone (sub, a folded directory)" gone "$T/mako/sub"
check "named in the output"                             contains "$out" "package mako is gone from the checkout"
check "no dangling link under HOME"                     [ -z "$(dangling)" ]
# a hand-made link into a package still there, dangling (the shape of
# ~/.config/git/host.inc with its host file missing): stow's business, not the sweep's
mkdir -p "$T/hand"; ln -s "../../../configs/tmux/hosts/missing.inc" "$T/hand/host.inc"
must [ -L "$T/hand/host.inc" ]
out="$(stow-all 2>&1)"; rc=$?
check "a dangling link into a package still there is left" [ -L "$T/hand/host.inc" ]
ln -s "../../../configs/GONE.md" "$T/hand/top.md"
out="$(stow-all 2>&1)"; rc=$?
check "a dangling link to a file at the checkout's top is left (no package)" [ -L "$T/hand/top.md" ]
rm -rf "$T/hand"

# --- 3c. a target out of every other target's reach: the loaded arrays name it --
echo "== a removed package whose target only the running shell's arrays name =="
mkdir -p "$C/deep"; echo d > "$C/deep/deep.conf"
sed -i 's|^  \[wezterm\]="$HOME"$|&\n  [deep]="$HOME/.local/share/deep"|; s/^\(STOW_ORDER=(.*\))$/\1 deep)/' "$CP"
must grep -q '^STOW_ORDER=(.* deep)$' "$CP"
guard
out="$(bash -c '
  source "$1" && stow-all >/dev/null 2>&1 || exit 9
  [ -L "$HOME/.local/share/deep/deep.conf" ] || exit 8
  rm -r "$2/deep"
  sed -i "/^  \[deep\]=/d; s/ deep)\$/)/" "$1"
  stow-all' _ "$CP" "$C" 2>&1)"; rc=$?
check "exit 0 (the shell stowed it, then the arrival removed it)" [ "$rc" -eq 0 ]
check "its link, four levels below HOME, is gone"       gone "$HOME/.local/share/deep/deep.conf"
check "no dangling link under HOME"                     [ -z "$(dangling)" ]
# ~/Desktop is never swept: no stow target, and a synced tree after the cutover
mkdir -p "$HOME/Desktop"; ln -s ../../configs/gonepkg/x "$HOME/Desktop/stale"
out="$(stow-all 2>&1)"; rc=$?
check "a dangling link into the checkout under ~/Desktop is left" [ -L "$HOME/Desktop/stale" ]
rm -rf "$HOME/Desktop"

# --- 4. a conflict stops stow-all as before ------------------------------------
echo "== a stow conflict =="
echo extra > "$C/wofi/extra"; echo "his own" > "$T/wofi/extra"
guard
out="$(stow-all 2>&1)"; rc=$?
check "a real file where a link would go: exit nonzero" [ "$rc" -ne 0 ]
check "stow names the conflict"                         contains "$out" "extra"
check "his file is untouched"                           [ "$(cat "$T/wofi/extra")" = "his own" ]
check "and is no link"                                  [ ! -L "$T/wofi/extra" ]
rm "$T/wofi/extra" "$C/wofi/extra"

# --- 5. a copy that does not parse stows nothing -------------------------------
echo "== 60-stow.sh broken on disk =="
cp "$CP" "$SB/copy.good"
echo new > "$C/wofi/late.css"
printf 'if then\n' >> "$CP"
out="$(stow-all 2>&1)"; rc=$?
check "exit nonzero"                                    [ "$rc" -ne 0 ]
check "the line names the file"                         contains "$out" "$CP is missing or does not parse"
check "nothing stowed (the new file is not linked)"     gone "$T/wofi/late.css"
rm "$CP"
out="$(stow-all 2>&1)"; rc=$?
check "60-stow.sh missing: exit nonzero"                [ "$rc" -ne 0 ]
check "60-stow.sh missing: nothing stowed"              gone "$T/wofi/late.css"
cp "$SB/copy.good" "$CP"; rm "$C/wofi/late.css"

# --- 6. the dry run and unstow-all re-read the arrays too ----------------------
echo "== stow-all-dry and unstow-all =="
mkdir -p "$C/alacritty"; echo ala > "$C/alacritty/alacritty.toml"
sed -i 's|^  \[wezterm\]="$HOME"$|&\n  [foot]="$HOME/.config/foot"|; s/^\(STOW_ORDER=(.*\))$/\1 foot)/' "$CP"
must grep -q '^STOW_ORDER=(.* foot)$' "$CP"
mkdir -p "$C/foot"; echo foot > "$C/foot/foot.ini"
guard
out="$(stow-all-dry 2>&1)"; rc=$?
check "dry run: exit 0"                                 [ "$rc" -eq 0 ]
check "dry run: the package added by the arrival is listed" contains "$out" "== foot -> $T/foot =="
check "dry run: nothing linked"                         gone "$T/foot/foot.ini"
check "dry run: nothing linked for a package already listed" gone "$T/alacritty/alacritty.toml"
mkdir -p "$C/rofi"; echo stray > "$C/rofi/stray"                      # nothing names rofi now
out="$(stow-all 2>&1)"; rc=$?
must links_to "$T/foot/foot.ini" "$C/foot/foot.ini"
check "a package the file no longer names is not stowed, though this shell's arrays name it" gone "$T/rofi/stray"
rm -r "$C/rofi"
out="$(unstow-all 2>&1)"; rc=$?
check "unstow-all: exit 0"                              [ "$rc" -eq 0 ]
check "unstow-all: a package only the file names is unlinked (kitty)" gone "$T/kitty/kitty.conf"
check "unstow-all: and foot"                            gone "$T/foot/foot.ini"
check "unstow-all: no link into the checkout is left"   [ -z "$(find "$HOME" -type l -lname "*configs/*" 2>/dev/null)" ]
check "unstow-all: HEAD still unchanged"                [ "$(git -C "$C" rev-parse HEAD)" = "$head0" ]

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
