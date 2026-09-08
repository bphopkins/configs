Prompt — the opening brief for the next french-logic chat. Dated record, written
2026-09-07 at the close of the first chat. The next chat writes its successor at
its own close and leaves this one in place; do not rewrite it.

# Read this whole file before touching anything

You are opening a fresh chat on the `french-logic` package, probably from
`configs/latex/`. The global rules, the per-repo charters, and the memories
load on their own; this brief adds what is specific to this project: what the
package is and what it is for, how the work is done with Brandon, what the
first chat built and decided, how to verify that all of it is sound before you
build on it, and what comes next. The order matters. First absorb, as a
non-interventionist. Then verify. Only then press forward.

## 1. What french-logic is

A semantic markup language for writing logic in LaTeX: a document says *what*
a symbol is — `\ought`, `\proves`, `\truthset{A}`, `\CMr`, `\cmr` — and the
package decides how it looks. It covers modal and deontic operators,
conditional connectives, consequence and satisfaction relations, models and
frames and their canonical constructions, the named axioms, rules and systems
of the field, I/O logic and STIT, the underlined first-order metalanguage of
neighbourhood semantics, and the document structure a logic dissertation
needs. Its largest speaker is the dissertation in `~/Desktop/dissertation/`;
it is not the owner. Brandon's homepage calls it "a useful semantic markup
macro for students and logicians of a certain kind", and the ambition is an
ecosystem. The map is `README.md` beside this file; read it first.

The governing principles are in that map, in his words. The ones you must not
drift from: membership is decided by coherence with the language, not by use,
and **nothing is deleted unless a strong specific case is made to him and he
accepts it**; every member has a home, a form consistent with its family, and
a rendering test; dependencies ride with the code; one user-facing package,
many unit files; a preamble by default, separable on demand; nothing changes
output unnoticed. Humberstone's conventions are the reference point when a
typographic question has a scholarly answer.

## 2. How the work is done with Brandon

This is the part the first chat had to learn as it went. Read it as
instructions, not description.

- **One decision at a time, in order of obviousness, then importance.**
  Obvious fixes he will plainly assent to come first; then the important
  ones. Batch several *independent* decisions into one question round only
  when each is small and self-contained.
- **Every ask carries five things:** what the issue is; why it is an issue;
  why it should be fixed; how you propose to fix it; and the plausible
  reasons *not* to. The point is that he can decide correctly and
  intelligently, not that he follows you. When he answers "you have not given
  me enough information to be able to intelligently address this", he means
  it literally: show the code, show the render, show the measurement, and
  ask again.
- **Vision before tweaks.** Any uncertainty about his intentions, hopes or
  designs is raised *before* the next tweak, however small the tweak. He
  said these two things go hand in hand. He will often supply the history
  behind a mechanism when asked (the `deon` option began as "everything that
  broke the DEON template"); that history usually contains the design.
- **Act immediately after his answer.** Build the candidate, prove it on both
  nets, land it, update the map, report. Do not accumulate approved work.
- **He decides typography by eye.** Photographed pdfLaTeX samples, one
  question per section, the same names in every cell, the four contexts
  (12 pt running text, footnote size, nested positions, a heading), and a
  line at the bottom saying how to answer, one letter per question. That is
  the type board (its URL is in memory); redeploy it, do not make a new page.
  He answers in prose, and reads the samples carefully: his readings of the
  label idioms were exactly right cell by cell.
- **Show the measurement, do not summarise it.** He noticed when a
  justification had been summarised rather than shown (the root line) and
  asked for it. A number is stated once cross-checked; "this depends on X,
  which I could not verify" beats a clean verdict on an assumption.
- **When he corrects you, check his usage before answering.** He was right
  that the index letters on frames are italic: the definitions show
  F<sub>R</sub> is ⟨W, R⟩, so R is the relation itself. Concede with the
  evidence, and record the rule his practice was already following.
- **When he asks "what do you think?", give a real opinion with its reason.**
  When he says "I don't know" or "I am open to hearing ideas", he wants
  candidates rendered side by side and a recommendation with its cost.
- **Nothing is deleted.** Not commented-out relics either: those went to
  `french-logic-quarry.sty`, never loaded. Renewals that restate a kernel or
  amsthm definition (`\to`, `proof`) are membership pins, not redundancy.
  `\Yright`'s declaration stays as the record of Humberstone's sequent-arrow
  convention even though stmaryrd supplies the glyph.
- **Nothing breaks the dissertation.** Every change goes through both nets
  before it lands (section 6). Breakage that surfaces a decision is welcome;
  silent breakage is not. He commits himself, through `gpushall`; never
  commit, never nag about committing.
- **Keep the last rounds of a long session short.** When he says to wrap up,
  close cleanly: land what is approved, record what is not, leave the trees
  for his sync, write the next brief.

## 3. What exists now

Package, in `configs/latex/french-logic/`, stowed as one directory into
`~/texmf/tex/latex/french-logic/` (folded link: new files appear without a
restow):

- `french-logic.sty` — the hub: dated `\ProvidesPackage`, keyval options (one
  switch per unit, default on; bundles `deon` = structure and cite off, `slim`
  = deon plus preamble off; unknown options are errors; loading under beamer
  with `structure` on raises an explanatory error), then one `\RequirePackage`
  per unit in the map's layered order, `proof` last because its house
  end-of-proof mark checks for amsthm when it loads.
- fourteen units `french-logic-<unit>.sty`: preamble, core, applied, deontic,
  modal, conditional, io, stit, gentzen, diagrams, lists, structure, cite,
  proof. Each has its own dated identification line, loads the packages it
  needs, and requires the units it refers into, so that each loads on its
  own. Inside units the blocks still sit in the old single file's order.
- `french-logic-quarry.sty` — retired explorations, all commented out, never
  loaded, each headed by the unit it came from.
- `README.md` — the map: principles, architecture with measured dependencies,
  conventions as practised with what is settled and what is open, tooling,
  consumers, the ledger (D1–D13 all closed; F1 partly, F2 closed, F3 by the
  split), history. A living contract: edit in place.
- `AUDIT.md` — the inventory, generated by `tests/french-logic/inventory.py`;
  never hand-edited.

Tests, public, in `configs/tests/french-logic/`: `run.sh` renders every
member on its own page in every mode it survives, plus the extras pages
(today: the diagram styles), compiles the fixture under both bundles, and
compares page hashes with `golden/`; `units.sh` loads each unit alone and
typesets its members; `mode-census.py` rebuilds `modes.tsv`; `inventory.py`
regenerates AUDIT.md. Read its README.

Harness, private, in `org/claude-config/repos/configs/french-logic-harness/`:
`sync.sh` copies the consumers into a scratch tree, `run-suite.sh` builds them
against a candidate package, `compare.py` diffs page by page with side-by-side
images; `usage.tsv` is the consumer census the inventory reads. Read its
README. Twenty-seven targets; the archived DEON final and four opuscula
documents are baseline-broken by decision (opuscula's AUDIT.md, finding 10).

Editor tooling: `nvim/lua/snippets/sty-lua-snippets.py` reads the hub and
every unit it loads (`-i` repeated, hub first) under one hash;
`nvim/lua/plugins/snippets.lua` derives the same list from the hub and
regenerates on Neovim start; `--coverage` cross-checks the highlight
registrations in `nvim/lua/plugins/vimtex.lua`, which key on name shapes;
`nvim/docs/latex-register-taxonomy.md` is his conceptual geography of the
notation and worth reading in full.

Settled on 2026-09-07, all by his decision and all recorded in the map:
mode policy; faces (rule β: schema-built names bold roman after Humberstone,
proper-name terms of art roman, sans reserved for syntactic objects and frame
classes); small labels scale with the mathematics (`\fl@lbl`, idiom A); index
letters on structures italic; symbol decorations scale; the three folds
(`\fl@dyad`, `\fl@thmstyle`, the loop); the option design; hyperref defaults
kept; geometry stays with the documents; the four opuscula documents left as
they are.

Deliberate visible changes to the dissertation since the last commit before
2026-09-07, and nothing else: the end-of-proof mark no longer orphaned at the
left margin (printed page 71) with hair-width shifts elsewhere, and `\qedhere`
working in displays and sketches; `\IOfn`'s H at the size its definition asked
for; the IO systems roman under rule β (17 pages); labels larger in headings
and smaller in footnotes, `\COc` and `\COvf` smaller at 12 pt; the ℒ and 𝔐
decorations on proof sets, classes and truth sets at the scaling size (24
pages); the plain modal axiom names bold upright inside italics (hair widths
on 7 pages). Page counts unchanged everywhere. Warnings gone from every build:
aliascnt's obsolescence, the seven `\tiny invalid in math mode`. The two
IO-logic decks build again after their option line changed.

## 4. Phase one: absorb, as a non-interventionist

Read, in this order, and edit nothing: `README.md`; `AUDIT.md`; the hub; each
unit in the hub's order; the quarry; `tests/french-logic/README.md` and its
scripts; the harness README; the snippet generator and loader; the
`vimtex.lua` registration block and the register taxonomy; `dissertation/
CLAUDE.md`'s package section (it still describes the pre-split package: see
section 7); `dissertation/dissertation.tex` and one article wrapper. Then the
consumers' use of the package, with the census in `usage.tsv`.

Hold these questions while reading, and write your answers down before
proposing anything: Does the layering in the map match the files? Is every
claim in the map true of the files today? Which conventions are settled and
which merely recorded? Where is the residue of the old single file's order
inside a unit misleading? What is in the quarry, and why? What do the two
nets cover, and what would they miss?

## 5. Phase two: verify that the first chat's work is sound

Do all of this before any change, and report the results as measurements.

1. `tests/french-logic/run.sh` — expect 835 pages, 0 changed, both bundles
   ok. `tests/french-logic/units.sh` — expect all fourteen units ok. The
   snippet generator's `--check` and `--coverage` — expect up to date and
   exit 0.
2. In the harness: `sync.sh`, then a full `baseline` run — expect the 27
   targets in the state the harness README describes, all page counts as in
   section 3 of this file.
3. The soundness check proper: build a second baseline against the package
   *as it was before 2026-09-07*. Take the last commit dated before that day
   (`git log --format='%h %ad' --date=short -- latex/french-logic/` in
   `configs`), put `git show <hash>:latex/french-logic/french-logic.sty` alone
   in a scratch directory, run the harness against that directory as the
   candidate, and compare with the current baseline. The differences must be
   exactly the deliberate list in section 3, the two warnings, and the two
   decks; anything else is a regression to raise before all else.
4. Read every unit once more for anything that reads wrong, and check the
   map's ledger entries against the files they describe.

"Improvement" is measured, not asserted: fewer warnings, the decks building,
every unit loading alone, the seventeen-version drift of vendored copies no
longer able to affect the live package, and the map answering "where does X
live and why" without archaeology. If any of that is not so, say so first.

## 6. The two nets, and how a change lands

For any change: build a candidate directory holding the complete package
(all files, edited copies included); `run.sh --sty DIR` and `units.sh --sty
DIR`; `run-suite.sh <label> DIR <targets>` then `compare.py baseline <label>`,
the fast list for small changes, the full list when structure, options or
load order move. Look at the changed pages, not only the counts. Land by
copying into `configs/latex/french-logic/`; regenerate the snippets;
`run.sh --update` if members changed by decision; `inventory.py` for AUDIT;
refresh the harness baseline for the affected targets; record the decision in
the map with its date.

## 7. Phase three: press forward

In this order, one decision at a time, unless your reading in phase one
changes the order for a reason you state:

1. **The grammar of names.** A proposal is recorded in the map (Conventions,
   "A grammar for the names") and on the type board's third sitting, with
   every rename and its live-use counts. He deferred it as too much for one
   evening. Present it again with the five parts of an ask; the choice is
   strict, lenient, or record-only.
2. **Per-unit ordering passes.** Within each unit, reorder by the tower
   (core: symbols, sets, syntax, relations, structures, functions, semantics,
   metalanguage), rewrite the block comments in one voice, and remove the
   residue of the old headers. Output-identical by construction; prove it
   anyway. One unit per round, core first.
3. **The dissertation charter's package section** still describes aliascnt,
   the old `deon` semantics, and an absolute path. It is his document in
   another repo: propose the replacement text and ask.
4. **Candidates the first chat noticed and did not raise**, each needing its
   own ask: `\SDLt` sets its T with `\textsuperscript` inside math where
   `\SDLplus` uses `^+`; `\mcslog` ends in a forced `\ ` space; the `solo`
   rule differs between the conditional operators and the metalanguage
   connectives; `\emptytruthset`'s `\!\cdot\!`; the `\unneced` kern chain; the
   preamble unit's furniture loads that no consumer uses (multicol, tabularx,
   xcolor, ragged2e, bm, centernot, calc, tikzsymbols — vocabulary of a kind,
   under principle 1, but the unit's stated purpose could be revisited);
   `\graphicspath` naming an `images/` directory no consumer has; `slim`
   compiled by the suite but used by no document; the version number promised
   for the hub-and-units release; `dissertation-template/philogic.sty`, which
   could one day be derived from the units rather than maintained apart.
5. **Whatever your own reading turns up.** Bring it as findings first,
   objective fixes separated from trade-offs, then ask.

## 8. Pitfalls the first chat hit, so you do not

- TeX searches the current directory before the texmf tree. A stale copy of
  the package left in a build directory silently shadowed the real one and
  produced a false alarm. Never leave a `french-logic*.sty` in a directory
  you compile in; point candidates through `TEXINPUTS` only.
- `grep -c` exits 1 when it counts zero. A `|| echo` on it turns every clean
  result into a failure.
- Text-extraction line counts are not reflow evidence: `pdftotext` emits old
  text-box labels as separate lines. Reflow is judged by page counts, pixel
  diffs, and looking at the pages.
- A partial harness run against a full baseline compares only the targets it
  built; say which.
- After a member's mode behaviour changes, `run.sh --recensus`; after a
  landed visible change, `run.sh --update`; after any landing, refresh the
  affected baselines, or the next comparison measures two changes at once.
- Names containing `@` are internal: the generator, the fixture and the
  inventory skip them by design.
- `\RequirePackage` is idempotent, so a unit's own requirements never
  reorder what the hub already loaded; the one order that matters is `proof`
  after `structure`.
- The rendering suite cannot see what has no member. The extras file exists
  for that; extend it when you add such a thing.

## 9. At the close of your chat

Land what is approved, record what is not, regenerate the derived files,
refresh the baselines, update the map's ledger and the tracker (`configs/
TODO.md`, item 13), leave every tree uncommitted for his sync, and write your
own successor to this brief beside it, dated, without rewriting this one.
