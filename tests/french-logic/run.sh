#!/usr/bin/env bash
# tests/french-logic/run.sh — render every member of french-logic, one tiny page each,
# and compare the rendering with the golden.  Run after any edit to the package.
#
#   ./run.sh                 compare the stowed package against golden/
#   ./run.sh --sty DIR       let DIR's french-logic*.sty shadow the stowed package
#   ./run.sh --update        accept the current rendering as the new golden
#   ./run.sh --recensus      rebuild modes.tsv first (every member compiled alone; ~3 min)
#   ./run.sh --dpi N         render resolution (default 200)
#
# Exit 0 when nothing changed, 1 when members render differently (side-by-side
# images in build/diff/), 2 when the fixture itself failed to compile.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build="$here/build"; golden="$here/golden"
sty_dir=""; update=0; recensus=0; dpi=200
while [ $# -gt 0 ]; do
  case "$1" in
    --sty) sty_dir="$(cd "$2" && pwd)"; shift 2;;
    --update) update=1; shift;;
    --recensus) recensus=1; shift;;
    --dpi) dpi="$2"; shift 2;;
    *) echo "unknown argument: $1" >&2; exit 2;;
  esac
done
if [ -n "$sty_dir" ]; then export TEXINPUTS="$sty_dir:"; fi
# The package files under test: the hub plus every unit it loads.
hub="$(kpsewhich french-logic.sty)" || { echo "french-logic.sty not found" >&2; exit 2; }
sty_args=(--sty "$hub")
for u in $(grep -o '\\RequirePackage{french-logic-[a-z-]*}' "$hub" | sed 's/.*{\(.*\)}/\1/'); do
  f="$(kpsewhich "$u.sty")" && sty_args+=(--sty "$f")
done
printf 'package files:'; for a in "${sty_args[@]}"; do [ "$a" != --sty ] && printf ' %s' "$a"; done; echo
rm -rf "$build"; mkdir -p "$build/new" "$build/diff"
if [ "$recensus" = 1 ]; then
  python3 "$here/mode-census.py" "${sty_args[@]}" --out "$here/modes.tsv" || exit 2
fi
python3 "$here/gen-fixture.py" "${sty_args[@]}" --modes "$here/modes.tsv" --out "$build" || exit 2
( cd "$build" && SOURCE_DATE_EPOCH=0 FORCE_SOURCE_DATE=1 pdflatex -interaction=nonstopmode -halt-on-error fixture.tex >/dev/null 2>&1 )
if [ ! -f "$build/fixture.pdf" ] || grep -q '^!' "$build/fixture.log"; then
  echo "FIXTURE FAILED TO COMPILE:"; grep -A3 '^!' "$build/fixture.log" | head -20; exit 2
fi
pdftoppm -r "$dpi" -png "$build/fixture.pdf" "$build/new/page" >/dev/null 2>&1
# pages.sha256: page, member, mode, sha of the rendered page
python3 - "$build" <<'PY'
import sys, os, hashlib, csv, glob
b = sys.argv[1]
pngs = sorted(glob.glob(os.path.join(b, 'new', 'page-*.png')))
rows = list(csv.DictReader(open(os.path.join(b, 'pages.tsv')), delimiter='\t'))
assert len(pngs) == len(rows), (len(pngs), len(rows))
with open(os.path.join(b, 'pages.sha256'), 'w') as f:
    for r, p in zip(rows, pngs):
        f.write(f"{r['page']}\t{r['member']}\t{r['mode']}\t{hashlib.sha256(open(p,'rb').read()).hexdigest()}\n")
PY
if [ "$update" = 1 ]; then
  mkdir -p "$golden"; cp "$build/fixture.pdf" "$golden/fixture.pdf"; cp "$build/pages.sha256" "$golden/pages.sha256"
  cp "$build/skipped.tsv" "$golden/skipped.tsv"
  echo "golden updated: $(wc -l < "$golden/pages.sha256") pages, $(du -h "$golden/fixture.pdf" | cut -f1) pdf"; exit 0
fi
# Option bundles: the fixture restricted to the units each bundle keeps must compile.
bundles_ok=1
for bundle in deon slim; do
  case "$bundle" in deon) drop="structure cite";; slim) drop="preamble structure cite";; esac
  bargs=(); for a in "${sty_args[@]}"; do case "$a" in --sty) continue;; esac; keep=1; for d in $drop; do case "$a" in *french-logic-$d.sty) keep=0;; esac; done; [ "$keep" = 1 ] && bargs+=(--sty "$a"); done
  bd="$build/bundle-$bundle"; mkdir -p "$bd"
  python3 "$here/gen-fixture.py" "${bargs[@]}" --modes "$here/modes.tsv" --out "$bd" --options "$bundle" --skip qed,qedsymbol >/dev/null
  ( cd "$bd" && pdflatex -interaction=nonstopmode -halt-on-error fixture.tex >/dev/null 2>&1 )
  n=$(grep -a -c '^!' "$bd/fixture.log" 2>/dev/null); n=${n:-1}
  if [ "$n" = 0 ]; then echo "bundle [$bundle]: ok ($(sed -n '2,$p' "$bd/pages.tsv" | wc -l) pages)"; else bundles_ok=0; echo "bundle [$bundle]: FAILED: $(grep -a -m1 -A1 '^!' "$bd/fixture.log" | tr '\n' ' ' | cut -c1-110)"; fi
done
[ -f "$golden/pages.sha256" ] || { echo "no golden yet; run with --update" >&2; exit 2; }
python3 - "$build" "$golden" "$dpi" <<'PY'
import sys, os, csv, subprocess, glob
b, g, dpi = sys.argv[1], sys.argv[2], sys.argv[3]
def load(p):
    d = {}
    for line in open(p):
        page, member, mode, sha = line.rstrip('\n').split('\t')
        d[(member, mode)] = (int(page), sha)
    return d
new, old = load(os.path.join(b, 'pages.sha256')), load(os.path.join(g, 'pages.sha256'))
added = sorted(k for k in new if k not in old); removed = sorted(k for k in old if k not in new)
changed = sorted(k for k in new if k in old and new[k][1] != old[k][1])
for k in added: print(f'+ new member/mode: {k[0]} ({k[1]})')
for k in removed: print(f'- member/mode gone: {k[0]} ({k[1]})')
newpngs = sorted(glob.glob(os.path.join(b, 'new', 'page-*.png')))
for k in changed:
    pn, po = new[k][0], old[k][0]
    out = os.path.join(b, 'diff', f'{k[0].strip(chr(92)).replace(":", "_")}-{k[1]}')
    subprocess.run(['pdftoppm', '-r', dpi, '-png', '-f', str(po), '-l', str(po), '-singlefile', os.path.join(g, 'fixture.pdf'), out + '-golden'], capture_output=True)
    subprocess.run(['magick', out + '-golden.png', newpngs[pn - 1], '-bordercolor', 'gray50', '-border', '4', '+append', out + '.png'], capture_output=True)
    print(f'~ changed: {k[0]} ({k[1]})  -> build/diff/{os.path.basename(out)}.png  (golden | new)')
n = len(added) + len(removed) + len(changed)
print(f'{len(new)} pages rendered; {len(changed)} changed, {len(added)} added, {len(removed)} removed')
sys.exit(1 if n else 0)
PY
rc=$?; [ "$bundles_ok" = 1 ] || rc=1; exit $rc
