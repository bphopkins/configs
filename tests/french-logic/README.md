# tests/french-logic

Rendering regression suite for the `french-logic` package
(`latex/french-logic/`). Every member of the language — each command in text
mode and in math mode, each environment — is typeset on its own tiny page,
rendered to a bitmap, and hashed. The golden is the accepted rendering; a run
reports every member whose rendering changed since it was accepted, with a
side-by-side image for each. Written 2026-09-07, when the package audit and
the unit split began; the map the suite serves is
`latex/french-logic/README.md`.

```bash
./run.sh                 # stowed package against golden/ — run after any edit
./run.sh --sty DIR       # a candidate copy in DIR shadows the stowed package
./run.sh --update        # accept the current rendering as the new golden
./run.sh --recensus      # rebuild modes.tsv first (~3 minutes)
./units.sh [--sty DIR]   # every unit loaded alone must typeset its own members
```

`run.sh` also compiles the fixture under the `deon` and `slim` option bundles,
restricted to the units each keeps, so a bundle that stops working fails the
run even though no member's rendering changed.

Exit 0 means nothing changed; 1 lists changed, added, and removed members and
leaves `build/diff/<member>-<mode>.png` (golden on the left, new on the right);
2 means the fixture itself did not compile, which is the loudest possible
regression.

- `gen-fixture.py` — builds `build/fixture.tex` and `build/pages.tsv` from the
  package files (the hub plus every unit it loads), one page per member and
  mode. A member the mode table marks as failing in a mode is skipped in that
  mode and listed in `build/skipped.tsv`, so the fixture always compiles.
- `mode-census.py` — compiles every member alone, twice, and writes
  `modes.tsv`: which modes each member survives, with the first error line.
  Slow, so it is data, not a step: rerun it with `--recensus` when a member's
  mode behaviour is meant to change, and review the diff of `modes.tsv` as
  part of the change.
- `modes.tsv` — the mode table. It is also documentation: `M` members are the
  object-level notation that must sit inside math, `TM` members are the
  `\ensuremath`-wrapped names, and a member failing in both modes is a bug.
- `extras.tex` — fixture pages for things that are not members, one per
  `%% page:` block (today: the possible-worlds diagram styles, which have no
  members and no consumer, so nothing else would notice them breaking).
- `units.sh` — loads each unit file on its own and typesets every member it
  defines, with nothing else loaded. This is the test of "dependencies ride
  with the code": a unit that leans on a package or a member another unit
  provides fails here even though the hub, which loads everything, would hide
  it. Run it after touching any unit's `\RequirePackage` lines.
- `inventory.py` — regenerates `latex/french-logic/AUDIT.md` from the unit
  files, the mode table, and (optionally) the private harness's usage census.
- `golden/` — `fixture.pdf` (byte-reproducible: no dates, no trailer id) and
  `pages.sha256` (page, member, mode, hash at 200 dpi). Reviewing a golden
  update in git shows exactly which members changed.
- `build/` — throwaway; ignored by git.

The page hashes depend on poppler's rasteriser, so a golden accepted on one
machine can differ on another after a poppler upgrade. If every page changes
at once with no package edit, that is the rasteriser, not the package: rerun
with `--update` after eyeballing a few diffs.

This suite tests the package in isolation. The consumers — the dissertation and
its article wrappers, the beamer decks, the teaching and opuscula documents —
are exercised by a separate harness that copies them into a scratch directory
and compares full builds page by page; it lives outside this public repo
because its target list names private trees.
