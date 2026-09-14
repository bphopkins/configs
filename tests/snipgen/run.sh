#!/usr/bin/env bash
# tests/snipgen/run.sh -- regression suite for nvim/lua/snippets/snipgen.py, the cwl
# and .sty front ends of the LaTeX completion layer.  Hermetic on the word lists and
# the .sty package in fixture/ (about a second); the amsmath spot checks run only
# where the TeXstudio clone exists and print "skip" otherwise.  Read README.md
# before changing a check.
#
#   ./run.sh            run every check; exit 0 = ALL PASS, 1 = something failed
#   ./run.sh --update   regenerate golden/ from the current generator, then run
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gen="$(cd "$here/../../nvim/lua/snippets" && pwd)/snipgen.py"
fx="$here/fixture"; golden="$here/golden"
clone="${SNIPGEN_CLONE:-$HOME/Desktop/texstudio}"
tmproot="${TMPDIR:-/tmp}"
tmp="$(mktemp -d "$tmproot/snipgen.XXXXXX")" || exit 2
cleanup() { if [[ -n "$tmp" && -d "$tmp" && "$tmp" == "$tmproot"/snipgen.* ]]; then rm -rf "$tmp"; fi; }
trap cleanup EXIT
pass=0; fail=0
ok()   { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf 'FAIL %s\n' "$1"; if [ -n "${2:-}" ]; then printf '%s\n' "$2" | head -n 20 | sed 's/^/     /'; fi; fail=$((fail+1)); }
skip() { printf 'skip %s\n' "$1"; }

fixture() { python3 "$gen" --cwl "$fx/fixture.cwl" --core "$fx/core" --option fixture:enabled "$@"; }

if [ "${1:-}" = --update ]; then
  fixture --out-dir "$golden" 2> "$golden/fixture.warnings"
  python3 "$gen" --cwl "$fx/core/latex-dev.cwl" --core "$fx/core" --out-dir "$golden" 2>/dev/null
  python3 "$gen" --sty "$fx/sty/fixhub.sty" --out-dir "$golden/sty" 2>/dev/null
  echo "golden updated: $(ls "$golden" "$golden/sty" | tr '\n' ' ')"
fi

# 1. every rule of PLAN.md section 2, once: the fixture converts to the golden byte for byte
name="fixture.cwl converts to golden/fixture.lua"
mkdir -p "$tmp/a"
if fixture --out-dir "$tmp/a" 2> "$tmp/a.warn"; then
  if d="$(diff "$golden/fixture.lua" "$tmp/a/fixture.lua")"; then ok "$name"; else bad "$name" "$d"; fi
else bad "$name" "generator exited $?"; fi

# 2. the warnings are exactly the recorded ones, in file order
name="warnings are exactly the recorded ones"
if d="$(diff "$golden/fixture.warnings" "$tmp/a.warn")"; then ok "$name"; else bad "$name" "$d"; fi

# 3. --check is green against the golden, twice (idempotence)
name="--check green twice against the golden"
if fixture --check --out-dir "$golden" >/dev/null 2>&1 && fixture --check --out-dir "$golden" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi

# 4. --check exits 1 on a changed copy and writes nothing
name="--check exits 1 on drift and writes nothing"
mkdir -p "$tmp/m"; cp "$golden/fixture.lua" "$tmp/m/fixture.lua"; printf '\n' >> "$tmp/m/fixture.lua"
before="$(sha256sum "$tmp/m/fixture.lua")"
fixture --check --out-dir "$tmp/m" >/dev/null 2>&1; rc=$?
if [ "$rc" = 1 ] && [ "$before" = "$(sha256sum "$tmp/m/fixture.lua")" ]; then ok "$name"; else bad "$name" "exit $rc"; fi

# 5. core order: latex-dev is deduplicated against tex and latex-document
name="core file: latex-dev drops the row tex already carries"
mkdir -p "$tmp/c"
if python3 "$gen" --cwl "$fx/core/latex-dev.cwl" --core "$fx/core" --out-dir "$tmp/c" 2>/dev/null; then
  if d="$(diff "$golden/latex-dev.lua" "$tmp/c/latex-dev.lua")"; then ok "$name"; else bad "$name" "$d"; fi
else bad "$name" "generator exited $?"; fi

# 6. the golden loads as Lua under stub modules and has the shape the loader relies on
name="golden loads with stub LuaSnip and has the expected shape"
if out="$(nvim --clean -l "$here/verify.lua" "$golden/fixture.lua" fixture 2>&1)"; then ok "$name"; else bad "$name" "$out"; fi

# 7. spot checks on the clone: the stage-1 acceptance rows of PLAN.md section 3
if [ -f "$clone/completion/amsmath.cwl" ]; then
  mkdir -p "$tmp/s"
  if python3 "$gen" --cwl "$clone/completion/amsmath.cwl" --core "$clone/completion" --clone "$clone" --out-dir "$tmp/s" 2>/dev/null; then
    a="$tmp/s/amsmath.lua"
    g() { grep -qF -- "$1" "$a"; }
    name='amsmath: \binom has named placeholders and is math-wrapped'
    if g 'trig = "\\binom", dscr = "{above}{below}" }, h.mathwrap({ t("\\binom{"), i(1, "above"), t("}{"), i(2, "below"), t("}") })'; then ok "$name"; else bad "$name"; fi
    name='amsmath: \cfrac gives two rows'
    n=$(grep -cF 'trig = "\\cfrac"' "$a"); if [ "$n" = 2 ]; then ok "$name"; else bad "$name" "$n rows"; fi
    name='amsmath: \dotsb is math-wrapped'
    if g 'trig = "\\dotsb", dscr = "" }, h.mathwrap({ t("\\dotsb") })'; then ok "$name"; else bad "$name"; fi
    name='amsmath: align is an environment template and not a list'
    if g 'trig = "\\align", dscr = "\\begin{align}" }, { t({ "\\begin{align}", "\t" }), i(1), t({ "", "\\end{align}" }) }' && ! grep -qE '^  lists = \{.*"align"' "$a"; then ok "$name"; else bad "$name"; fi
    name='amsmath: \Hat (hidden) is absent'
    if ! g 'trig = "\\Hat"'; then ok "$name"; else bad "$name"; fi
    name='amsmath: \AmSfont carries the unusual mark and the sink priority'
    if g 'trig = "\\AmSfont", dscr = "∗", priority = 900 }'; then ok "$name"; else bad "$name"; fi
    name='amsmath: the includes header carries its three #include lines'
    if g '  includes = { "amstext", "amsbsy", "amsopn" },'; then ok "$name"; else bad "$name"; fi
    name='amsmath: the header names the clone commit'
    if grep -qE '^-- source: TeXstudio completion/amsmath.cwl at commit [0-9a-f]{40} \([0-9-]{10}\)$' "$a"; then ok "$name"; else bad "$name" "$(sed -n 2p "$a")"; fi
  else bad "amsmath: generator run" "exit $?"; fi
else
  skip "amsmath spot checks (no clone at $clone)"
fi

# 8. the .sty front end: the fixture hub and its sibling unit convert to golden/sty/ byte for
#    byte, from the one hub argument, with nothing on stderr
name="sty: fixhub.sty and its unit convert to golden/sty/ from the hub alone"
mkdir -p "$tmp/y"
if python3 "$gen" --sty "$fx/sty/fixhub.sty" --out-dir "$tmp/y" >/dev/null 2> "$tmp/y.warn"; then
  if d="$(diff -r "$golden/sty" "$tmp/y")" && [ ! -s "$tmp/y.warn" ]; then ok "$name"; else bad "$name" "$d$(cat "$tmp/y.warn")"; fi
else bad "$name" "generator exited $?"; fi

# 9. the stamp is the source file's own sha256, so the startup check can compare per file
name="sty: the sty-sha256 stamp is the source file's own sha256"
want="$(sha256sum "$fx/sty/fixhub-unit.sty" | cut -d' ' -f1)"
have="$(sed -n 's/^-- sty-sha256: \([0-9a-f]*\)$/\1/p' "$golden/sty/fixhub-unit.lua")"
if [ -n "$have" ] && [ "$want" = "$have" ]; then ok "$name"; else bad "$name" "want $want have $have"; fi

# 10. --sty --check is green against the golden, twice
name="sty: --check green twice against the golden"
if python3 "$gen" --sty "$fx/sty/fixhub.sty" --check --out-dir "$golden/sty" >/dev/null 2>&1 && python3 "$gen" --sty "$fx/sty/fixhub.sty" --check --out-dir "$golden/sty" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi

# 11. --sty --check exits 1 on a changed copy and on a file whose source is gone, and writes nothing;
#     a file without a "-- source: ... in this repository" header (a cwl file, a hand file) is never extra
name="sty: --check exits 1 on drift and on a sourceless file, writes nothing"
mkdir -p "$tmp/z"; cp "$golden/sty/"*.lua "$tmp/z/"; printf '\n' >> "$tmp/z/fixhub-unit.lua"
printf -- '-- Generated by snipgen 1 from gone.sty; do not edit, regenerate.\n-- source: tests/snipgen/fixture/sty/gone.sty in this repository\n' > "$tmp/z/gone.lua"
cp "$golden/latex-dev.lua" "$tmp/z/latex-dev.lua"
before="$(cat "$tmp/z/"*.lua | sha256sum)"
out="$(python3 "$gen" --sty "$fx/sty/fixhub.sty" --check --out-dir "$tmp/z" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && [ "$before" = "$(cat "$tmp/z/"*.lua | sha256sum)" ] && printf '%s' "$out" | grep -q '2 files would be generated, 1 stale, 0 missing, 1 extra'; then ok "$name"; else bad "$name" "exit $rc: $out"; fi

# 12. a write run restores the drifted file, removes the sourceless one and leaves the cwl file alone
name="sty: a write run restores the drifted file and removes only the sourceless one"
if python3 "$gen" --sty "$fx/sty/fixhub.sty" --out-dir "$tmp/z" >/dev/null 2>&1 && [ ! -e "$tmp/z/gone.lua" ] && [ -e "$tmp/z/latex-dev.lua" ] && rm "$tmp/z/latex-dev.lua" && diff -r "$golden/sty" "$tmp/z" >/dev/null; then ok "$name"; else bad "$name"; fi

# 13. the unit golden loads under the stub modules and has the shape the .sty rules promise
name="sty: unit golden loads with stub LuaSnip and has the expected shape"
if out="$(nvim --clean -l "$here/verify.lua" "$golden/sty/fixhub-unit.lua" sty 2>&1)"; then ok "$name"; else bad "$name" "$out"; fi

# 14. the hub golden: includes in source order, deduplicated, the tikz libraries mapped
name="sty: hub golden loads, includes in source order"
if out="$(nvim --clean -l "$here/verify.lua" "$golden/sty/fixhub.lua" styhub 2>&1)"; then ok "$name"; else bad "$name" "$out"; fi

# 15. --coverage over the fixture package against the real vimtex.lua: the fixture's commands
#     are unregistered, so exit 1 naming them; a \DeclareMathSymbol name stays outside the set
name="sty: --coverage lists the fixture's unregistered commands and exits 1"
out="$(python3 "$gen" --sty "$fx/sty/fixhub.sty" --coverage 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s\n' "$out" | grep -qx '\\plain' && printf '%s\n' "$out" | grep -qx '\\shared' && ! printf '%s\n' "$out" | grep -qx '\\sym'; then ok "$name"; else bad "$name" "exit $rc: $out"; fi

echo
if [ "$fail" = 0 ]; then echo "ALL PASS ($pass checks)"; exit 0; fi
echo "FAILED: $fail of $((pass + fail)) checks"; exit 1
