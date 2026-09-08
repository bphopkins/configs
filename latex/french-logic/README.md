# french-logic

`french-logic` is a semantic markup language for writing logic in LaTeX. A
document says *what* a symbol is — `\ought`, `\proves`, `\truthset{A}`,
`\CMr`, `\cmr` — and the package decides how it looks. It covers the modal and
deontic operators, the conditional connectives, consequence and satisfaction
relations, models and frames and their canonical constructions, the named
axioms, rules, and systems of the field, the I/O-logic and STIT vocabularies,
the underlined first-order metalanguage of neighbourhood semantics, and the
document structure a logic dissertation needs. Developed since 2021 under
Rohan French's supervision, hence the name. The homepage's phrase for the
ambition: "a useful semantic markup macro for students and logicians of a
certain kind."

This file is the map of the package: what it is for, how it is organised,
what its conventions are, and what is open. It is a living contract — edit it
in place; staleness is a bug. The member-by-member inventory is `AUDIT.md`,
generated. The stow-package charter is `../CLAUDE.md`. The API summary the
dissertation reads is in `dissertation/CLAUDE.md`. Written 2026-09-07 at the
start of the reorganisation; the *Status* line under each heading says how
far that heading is from the truth on the ground.

## Principles

Settled 2026-09-07, in Brandon's words where quoted.

1. **A language, not a toolkit.** Membership is decided by coherence with the
   language, not by use. "Nothing should be deleted unless a strong specific
   case can be made directly to me, which I accept." A member unused for years,
   or ever, is still vocabulary; the inventory's zero-use column is not a
   deletion list. What is being built is "a sprawling, but extremely coherent
   and well-tested semantic markup language."
2. **Coherent and well-tested.** Every member has a home (a unit), a form
   consistent with its family, and a rendering test. A broken member is a bug
   to fix; an inconsistent one is a form to normalise.
3. **Dependencies ride with the code.** Each unit loads what it needs, at its
   head, and nowhere else. This map records who needs what, so that the units
   can be separated without archaeology.
4. **One package, many units.** `french-logic` stays the sole user-facing
   package. It is a hub that loads unit files `french-logic-<unit>.sty`, each
   a small package with its own `\ProvidesPackage` and `\RequirePackage`
   lines. Users write `\usepackage{french-logic}`; a unit can also be loaded on
   its own, by a template or a colleague, without restructuring.
5. **A preamble by default, separable on demand.** The document furniture —
   fonts, encodings, babel, the convenience packages — is a unit the hub loads
   by default, so one `\usepackage` still replaces a hundred-line preamble.
   Options omit it, and the document-structure units, for host classes that
   own those things themselves (beamer, conference classes).
6. **Nothing changes output unnoticed.** Two nets. `tests/french-logic`
   renders every member on its own page and hashes it against a golden. A
   consumer harness (private; see *Tooling*) rebuilds the dissertation, its
   article wrappers, the decks, and the teaching and opuscula documents against
   any candidate package and compares them page by page.

## Architecture

*Status 2026-09-07: split done. `french-logic.sty` is the hub; the unit
files below hold the language; `french-logic-quarry.sty` is never loaded.
Every line of the single file moved verbatim into exactly one unit (checked
by multiset), and both nets were clean: no differences across the 27
consumers, no changed page among the 834 fixture pages. The dependency data
is measured — each external command was attributed by loading every package
alone and probing — and the reference data is the closure of the package's
own macro-to-macro uses. Each unit loads every package it needs and requires
the units it refers into, so that it works on its own; `tests/french-logic/units.sh`
proves it by loading each unit alone and typesetting all its members. Within
units the order is still the old file's, block by block; the per-unit
coherence passes reorder as they go.*

The layering has two levels. **Core** is ordered by the tower of languages
that the Neovim register taxonomy also uses (`nvim/docs/latex-register-taxonomy.md`):
symbols, then sets and functions, syntax, relations, modal structures,
semantics, and the metalanguage. **Subject units** sit above core and use it.
**Document units** sit beside, and the **preamble** unit beneath. Every
reference in the file points downward through this order; there are no cycles.
A pure tower split was rejected because it would separate correspondence
pairs — `\CMr` on the syntax side from `\cmr` on the semantics side — which
belong together.

| unit | file | holds | needs beyond the kernel | refers into |
|---|---|---|---|---|
| preamble | `french-logic-preamble.sty` | fontenc T1, inputenc utf8, lmodern, babel english; ragged2e, setspace, multicol, xcolor, soul, tabularx, mdframed, calc, trimclip, adjustbox, booktabs, bm, centernot; graphicx and `\graphicspath` | those | nothing |
| core | `french-logic-core.sty` | symbol fonts (`\Yright`, `\shortminus`, `\strictif`); sets, tuples, powerset; the `f` functions; languages and logics (`\lang`, `\logic`); relations (`\proves`, `\models`, `\trues`, sequent arrows); modal structures (`\M`, `\F`, `\nec`, `\poss`, canonical decorations); truth sets, proof sets, valuations; the underlined metalanguage; closures and the closure arrows | amsmath, amssymb, mathtools, stmaryrd, mathrsfs, xspace, soul (`\st` is a renewal of soul's), graphicx, trimclip, the txfonts `txsyc` glyph | nothing |
| applied | `french-logic-applied.sty` | temporal (`\hitherto`, `\henceforth`, `\was`, `\willbe`), epistemic (`\knows`, `\believes`, …), credence (`\cprob`, `\cred`) | nothing | nothing |
| deontic | `french-logic-deontic.sty` | `\ought`, `\may`, `\forbidden`, … ; dyadic operators `\cobs`, `\cperms`, `\cnecs`, `\cposs` and their solo forms; `\sphere`, `\cfact` | amssymb, graphicx | core (`\nec`, `\poss`) |
| modal | `french-logic-modal.sty` | axiom names (`\kax` …, parenthesised, converse), rule names, system names (`\K` … `\CEMC`), deontic systems (`\SDL`, `\KDought`) | xspace | deontic (`\ought`), core (`\poss`) |
| conditional | `french-logic-conditional.sty` | the CM/CC families with their lowercase frame conditions, CN, CP, CT, C-Dual, the order conditions `\Rup` … | xspace, core's `\strictif` | core |
| io | `french-logic-io.sty` | `\IO` and the IO systems, in/out/deriv, the rule names `\TOP` … `\CT` and their starred forms | amsmath (`\text` in `\IO`), xspace | core (`\fl@lbl`) |
| stit | `french-logic-stit.sty` | `\cstit`, `\dstit`, the structure names via `\versal` | microtype | nothing |
| proof | `french-logic-proof.sty` | the Set-Set … framework names, the subscripted `\proves` variants, the `//` consequence separator `\infer` | amssymb, microtype; amsthm is detected, never loaded here | core (`\proves`) |
| gentzen | `french-logic-gentzen.sty` | the `gentzen` proof-tree environment over ebproof, rule labels, the signed-formula `\af`/`\de` family | ebproof, relsize (loaded since D4) | nothing |
| diagrams | `french-logic-diagrams.sty` | the TikZ styles for possible-worlds diagrams (`modal`, `world`, `point`, the `reflexive` loops) | tikz, tikzsymbols | nothing |
| lists | `french-logic-lists.sty` | the list environments (with the beamer enumitem shim), `block`, `\by` | enumitem | nothing |
| structure | `french-logic-structure.sty` | hyperref, cleveref, footmisc; theorem styles and the eleven theorem environments, `proof`, `proofsketch`, the sketch and remark marks | amsthm, amssymb, cleveref, hyperref, footmisc; LaTeX 2026-06-01 or later | proof (`\qed`) |
| cite | `french-logic-cite.sty` | `\tcite`, `\pcite`, `\poscite`, the unbreakable name–label delimiter | biblatex (+ csquotes) | nothing |
| quarry | `french-logic-quarry.sty` | retired explorations, every entry commented out, each headed by the unit it came from: the conditional-obligation glyph trials, the B/4/5 axiom names, `\prob`, Ax/Th, page references, the question/answer environments from an old homework template, the `$`-form IO names | never loaded | nothing |

Hub: `french-logic.sty` keeps the options and loads the units in the order
above, with one exception: `proof` loads last, after `structure`, because its
house end-of-proof mark applies only when amsthm is visible, whether loaded by
`structure` or by the document itself before the package under `deon`. The
lists unit is not gated: the decks use `hilbertlist` under `deon`. Options
(settled 2026-09-07): one switch per unit through the kernel's keyval package
options, default on — `[structure=false,cite=false]` for a host class that
owns theorems, hyperlinks, and the bibliography driver, `[preamble=false]` for
one that owns fonts and layout — with two bundles, `deon` (structure and cite
off; the DEON template, beamer) and `slim` (`deon` plus preamble off). Keys
apply in the order given, an unknown option is an error, and loading under
beamer with `structure` still on raises a french-logic error that names the
fix, rather than letting hyperref's option clash speak. The history behind
`deon` (Brandon): it began as "everything that broke the DEON template",
offloaded into one block and switched off, and it happened to make beamer work
because beamer owns the same things; the per-unit switches are that idea made
general. The rendering suite compiles the fixture under both bundles.

## Conventions

*Status 2026-09-07: as practised, with the drift noted. The open items are
worked through unit by unit and struck here as they settle.*

- **Mode.** Names — systems, axiom schemata, frame conditions, rules, I/O
  rules — are `\ensuremath{…}\xspace`, so they work in text and in math with
  no manual spacing. Objects — structures, relations, operators, truth sets —
  are math-only. The mode table (`tests/french-logic/modes.tsv`) records the
  fact: 295 members work in both modes, 202 in math only, 14 in text only,
  4 only inside a proof tree (census of 2026-09-08). `\Lc` gained the wrapper
  its `\lang` siblings have on 2026-09-07; the table caught up with it on
  2026-09-08 (D15).
- **Face.** Bold upright for axiom schemata and systems, inside italic text
  too — Humberstone's convention, settled 2026-09-07; every name now carries
  `\ensuremath{\textup{\textbf{…}}}\xspace`. Roman for rules, frame
  conditions, and generic names. Rule β, settled 2026-09-07: names built from
  schema letters (K, KD45, CE, CM<sub>R</sub>, KD<sub>O</sub>) are bold roman;
  proper-name terms of art (SDL, CO for conditional obligation, vF for van
  Fraassen, I/O, and the IO systems built on that name) are roman — chosen
  over small capitals and sans serif on the board, sans serif because it
  already means syntactic objects and frame classes here. The IO systems left
  bold under this rule on 2026-09-07. The face system is then: bold roman
  schema-built names, roman proper names, sans syntactic objects and frame
  classes, fraktur structures, calligraphic logics, script languages.
- **Indices on structures.** The letter under a frame or function — the R of
  F<sub>R</sub>, the D of f<sub>D</sub> — is an italic math letter, unlike the
  upright label on a name, and the two never look alike. Settled 2026-09-07
  from the definitions: F<sub>R</sub> is ⟨W, R⟩, so R is the relation itself;
  the strict typographic rule (descriptive subscripts upright) would split the
  family at f<sub>D</sub> and f<sub>M</sub>, and the uniform italic is kept.
- **Parentheses.** Lowercase frame-condition names and the `…par` variants
  carry their own parentheses; write `\cmr`, never `(\cmr)`.
- **Names.** Uppercase family names are axioms, lowercase their frame
  conditions (`\CMr` / `\cmr`). Suffix grammar: `s` star, `d` dual, `a`
  additive, capital `S` a superscript *s*, `conj`/`disj`, `conjd`/`disjd`,
  `up`/`down` the fishhook superscript named by the family's order direction,
  `par` parenthesised, `c` converse, `solo` the bare glyph for mention rather
  than use. Single letters: fraktur `\A \C \F \M` are structures, bold `\B \D \E \K \T` are
  systems, `\Slog`, `\four`, `\five` the forced exceptions. `\mathsf{{O}}` keeps
  double braces as the placeholder for a future bold switch. Open: the `solo`
  rule differs between the conditional operators (drop the trailing *s*) and
  the metalanguage connectives (append).
- **The grammar of the names — settled 2026-09-08: strict, substituted, no
  aliases.** A name is the letters as printed, CamelCase, digits spelled out. Kind is carried by case and one suffix: an initial capital for a schema
  or a system (`\CMr`, `\K`), with `ax` added only where the same letters also
  name a system (`\Kax` beside `\K`); lowercase for a frame condition (`\cmr`,
  and so `\rup` for the order conditions); lowercase with `rule` for a rule.
  Decorations are suffixes: `s` star, `plus`, `par` parenthesised, `c`
  converse, `solo` for mention, `ought` for the deontic reading; numbers are
  spelled and count as printed (`\FRtwo`, `\FNone`); a suffix letter is the
  letter printed (`\topa`, `\MR`, `\langc`). Landed in two rounds on 2026-09-08, each proved on
  both nets (renamed fixture pages hash-identical to their old golden pages;
  every consumer page-identical): round one the eighteen outliers (`\rmposs`
  → `\rmpossrule` and kin, `\Ts` → `\TOPs`, `\FRo` → `\FRtwo` and the frame
  numbering as printed, `\topt` → `\topa`, `\bott` → `\bota`, `\MRel` → `\MR`,
  `\Lc` → `\langc`, now beside its siblings, `\SDLt` → `\SDLT`); round two
  the thirty-seven classical schemata with their initial capital (`\kax` →
  `\Kax`, `\maxi` → `\Max`, `\duax` → `\Dualax`, `\cduax` → `\CDualax`, the
  `par` and `c` forms alike) and the four order conditions lowercase (`\Rup`
  → `\rup`). The old names are gone; every rename with its live-use counts is
  on the type board, section 7, and the consumers were substituted in
  the same landing. Three opuscula documents that had defined `\Lc` or `\SDLt`
  themselves stopped clashing with the package; the DEON fork keeps its own
  frozen copy and was not touched. Tool consequences landed with it: the
  highlight patterns (`axfam` on capitals, `orderfam` lowercase, `rpossfam`
  absorbed by `rulefam`, `langfam` with `c`), the snippets, the register
  taxonomy's mention of `\langc`, and the syntax suite's fixture.
- **Small labels.** The small letter on a name — the R of CM<sub>R</sub>, the
  H of IO<sup>H</sup> — is set by one internal helper, `\fl@lbl`, in core:
  upright, at `\scriptscriptstyle`, so it scales with the mathematics around
  it, smaller in a footnote and larger in a heading. Settled 2026-09-07 by eye
  against the four fixed-size idioms the file had grown; the 121 labels were
  converted in one pass, pixel-identical in 12 pt running text, visibly better
  in headings. Hyperref bookmarks receive the bare letter. The symbol
  decorations on truth sets and classes (`\truthsetm`, `\proofsetl`,
  `\eclassl`) scale the same way since 2026-09-07, judged on the board.
- **Spacing.** `/` is on the `\xspace` exception list, so `\ccr/\ccl` sets
  correctly.
- **Provenance.** `\Yright` as the sequent separator (`\seq`, `\tseq`) is
  Humberstone's convention; its declaration stays in the package as the
  record even though stmaryrd supplies the glyph. Renewals that restate a
  kernel or amsthm definition (`\to`, `proof`) are membership pins, not
  redundancy.
- **Duplicates.** Fourteen groups of byte-identical definitions (measured
  2026-09-08) are deliberate vocabulary until decided otherwise — principle 1:
  eleven within one unit (`\then`, `\onlyif`, `\to`; `\gives`, `\asserts`,
  `\proves`; the four names for `\Rightarrow`; …) and three across the applied
  and deontic units, where different operators share a sans letter (`\was`,
  `\may`, `\permissible`; `\willbe`, `\forbidden`; `\henceforth`,
  `\gratuitous`).

## Tooling

- **Snippets.** `nvim/lua/snippets/sty-lua-snippets.py` generates the LuaSnip
  module from braced `\newcommand` forms, comments stripped, reading the hub
  and every unit it loads (`-i` repeated, hub first); the module carries one
  hash over all of them and regenerates on the next Neovim start. It cannot
  see `\DeclareMathSymbol`, `\NewDocumentCommand`, or `\DeclareCiteCommand`
  members, and it keys list-shaped snippets on the substring `list` in an
  environment's name.
- **Highlighting.** `nvim/lua/plugins/vimtex.lua` registers members into the
  register taxonomy by name shape (`C[CM][rl]\w*`, `[CKDTUPWN]ax\w*`, `\w*rule\w*`, `[rl]%(up|down)`, …); renames must keep to those shapes or update them. The
  coverage check is `sty-lua-snippets.py --coverage`.
- **Rendering suite.** `tests/french-logic/run.sh`; golden re-accepted after
  each landed change, last on 2026-09-08 when the mode table caught up with
  `\Lc` and the fixture gained its text page (836 pages); the split changed no
  page. `extras.tex` adds fixture pages for what has no
  member, today the diagram styles, after a scratch-directory mishap showed
  that nothing else would notice them breaking.
  `\qed` and `\qedsymbol` are members of the fixture since D7 wrote them with
  braces. `tests/french-logic/inventory.py` regenerates `AUDIT.md` from the
  unit files (its group headings are the units' own: a `%%%` line, or the
  first line of a run of `%` lines); `tests/french-logic/units.sh` is the standalone-load test.
- **Consumer harness.** `org/claude-config/repos/configs/french-logic-harness/`
  (private): `sync.sh` copies the dissertation, its wrappers, the decks, and
  the teaching and opuscula documents into a scratch tree, `run-suite.sh`
  builds them against a candidate package, `compare.py` diffs page by page.
- **The type board.** A private page of photographed samples for decisions
  taken by eye (labels, faces, decorations, the folds' code, the grammar
  draft); its link is in memory, and it is redeployed sitting by sitting.

## Consumers

Twenty-eight documents load the stowed package; seventeen more in opuscula
carry frozen copies of old versions and are untouched by edits here. The
dissertation and its seven article wrappers use 253 members. The three
teaching documents use twenty macro uses in total, all from core, and
otherwise use the package as a preamble. The `deon` option is passed by the
three beamer decks and the two LvFsystems documents; the two IO-logic decks
passed the `conflicts` option that `deon` replaced on 2025-11-15 until D9
was closed. Three opuscula documents fail against the current package because they
define macros the package has since acquired (`\IO`, `\lang`, `\suchthat`) or
use the retired `defn` environment; that is consumer drift, not a package
defect, and is on the ledger. A fourth, on-indices, built again on 2026-09-08
when `\SDLt` became `\SDLT` and its own definition no longer clashed; the two
others lost one error each the same way. The DEON fork
(`IO-logic/DEON/IO-DEON-fork/`) is a frozen tree with its own copy of the old
package; its `final/` copies name the stowed package only because no copy
sits beside them, and they were left as submitted.

## Open ledger

Defects are numbered D, form drift F; each carries a status. Fixed items stay
until the unit split closes, then move to `configs/DECISIONS.md`.

- **D1** orphan `\makeatother` at the end of the theorem block, and the
  citation-block comment that blamed `\ExplSyntaxOn` for it. *Fixed
  2026-09-07.*
- **D2** U+2019 in the `modal` TikZ style's arrow tip. *Fixed 2026-09-07;
  `stealth'` kept, plain `stealth` and arrows.meta `Stealth` verified as
  alternatives.*
- **D3** `\usepackage` for microtype inside the package. *Fixed 2026-09-07,
  in place: the load stays with the STIT code that needs it.*
- **D4** the signed-formula `\af`/`\de` family needs `relsize`, which nothing
  loaded; fourteen members failed in both modes. *Fixed 2026-09-07: relsize
  loaded beside ebproof, where the code lives.*
- **D5** `\DeclareSymbolFont{stmry}` re-declared stmaryrd's symbol font and
  dropped its bold version; `\Yright` re-declares stmaryrd's identical symbol.
  *Resolved 2026-09-07: the font line removed; the `\Yright` declaration
  kept by decision — the sequent arrow is Humberstone's convention and the
  line is its record; `\shortminus` kept, it backs `\unneced` and
  `\unpossed`.*
- **D6** `\IOfn` set bare `\tiny` in a superscript; seven warnings per
  dissertation build, and the label came out at script size. *Fixed
  2026-09-07: first `\text{\tiny\textsf{H}}`, the size the definition asked
  for, then, with the labels pass, `{\scriptscriptstyle\mathsf{H}}` — the
  scaling size, sans because the name is a frame class; the IO-logic chapter's
  23 sites match `\IOhn`'s label height.*
- **D7** `\renewcommand{\qed}` broke `\qedhere` in display math (51 errors
  against 0 for the amsthm original), failed to load under `deon` when
  amsthm came later, and left a ■ orphaned at the left margin on printed
  page 71. *Fixed 2026-09-07: the house placement rebuilt on amsthm's
  mechanism — math branch amsthm's, text branch flush right with no `\quad`
  and no break before the mark — applied only when amsthm is present;
  `proofsketch` takes its □ through a local `\qedsymbol`, so `\qedhere`
  works in sketches. Two dissertation pages changed, as intended.*
- **D8** aliascnt was obsolete on the 2026-06-01 kernel, whose `\newtheorem`
  uses `\newcounteralias`. *Fixed 2026-09-07: plain `\newtheorem{x}[theorem]`
  for the ten kinds, the `\crefname`s kept, and a `\PackageError` on any
  older format, since one would silently print "theorem" for every kind.
  fedxps carries a 2026 TeX Live tree. No page changed; the warning is gone
  from every consumer.*
- **D9** the IO-logic beamer decks passed the removed `conflicts` option, and
  under `deon` then hit the enumitem-under-beamer recursion the completeness
  deck had worked around in its own preamble. *Fixed 2026-09-07: the package
  carries the four-line `\setlist` shim, guarded on beamer, beside enumitem;
  the two decks now pass `deon`. Both build again (27 and 24 pages); the
  completeness deck's copy of the shim is now redundant.*
- **D10** `block` sat inside the amsthm guard though it needs nothing there.
  *Fixed 2026-09-07: defined after the guard, only when no class already
  provides a `block`, with a log note otherwise.*
- **D11** apparent no-ops. *Resolved 2026-09-07: the four `\!\,` kerns
  removed (exactly zero glue). The `proof` renewal, byte-identical to
  amsthm's, and `\renewcommand{\to}`, identical to the kernel's, are kept
  and commented as pins: they declare the two as members with a house form,
  and are why they appear in the inventory and the snippets.*
- **D12** `\ProvidesPackage` carried prose where a date belongs. *Fixed
  2026-09-07: `[2026/09/07 Semantic markup for logic]`; a version number
  comes with the hub-and-units release.*
- **D13** the `% !TEX root` line tied the shared package to one consumer by an
  absolute path. *Resolved 2026-09-07: relative (`../../../dissertation/…`),
  measured to resolve from the repo path and through the texmf symlink alike;
  a tilde path does not resolve. The line exists so that compiling or viewing
  from the package buffer acts on the dissertation; nothing else reads it.*
- **D14** the inventory generator took the last line of a multi-line comment
  as a group heading, so AUDIT.md showed prose fragments as headings, and a
  first group with no heading lost its table header row. *Fixed 2026-09-08: a
  heading is a `%%%` line, or the first line of a run of `%` lines, short and
  not a sentence; the conditional unit's family headings appear for the first
  time; the 543 member rows are unchanged.*
- **D15** the mode table was not re-censused after `\Lc` gained its wrapper,
  so the golden had no text page for it. *Fixed 2026-09-08: recensus (one row
  changed), golden re-accepted at 836 pages.*
- **F1** mode, face, and naming drift as listed under *Conventions*. *Mode, face, labels, decorations, and structure indices settled 2026-09-07;
  the naming grammar settled and landed 2026-09-08 (59 renames); the per-unit
  ordering passes remain.*
- **F2** four hand-copied eight-line bodies (`\cnecs`, `\cposs` and their solo
  forms) that were `\condop` with a different glyph and two kerns; two
  identical theorem styles; two near-identical reflexive loop styles. *Fixed
  2026-09-07: one builder `\fl@dyad` with each operator's six tuning numbers,
  one style body under three names, one loop with two defaults; proved
  identical on every net, the diagram included.*
- **F3** header hierarchy, blank-line runs, trailing whitespace, lines over
  100 characters. *Resolved 2026-09-07 by the split; the residue inside units
  goes with each unit's coherence pass.*

Decisions closed 2026-09-07: the option design (above); hyperref keeps its
defaults, a document that wants otherwise sets `\hypersetup` itself;
`geometry` stays with the documents, where every consumer already sets it.
The opuscula drift was recorded in that repo's inventory (finding 10) on
2026-09-07 and left as it is. Pending: the per-unit ordering passes; the dissertation charter's package
paragraph, which still describes aliascnt, the old `deon`, an absolute path,
and now the old names.

## History

Imported into `configs` on 2025-11-10 from the texmf tree, where it had grown
since 2021. 2025-11-15: the `deon` option replaced the `kvoptions`
`conflicts` mechanism and its `conflicts.def`. March–June 2026: cleveref,
the aliascnt idiom, the `\ensuremath`/`\xspace` form for names, the order
conditions and metalanguage quantifiers, `hilbertlist`'s right margin,
`axiomproof`, `\by`, `\textup` inside the family names, `\metalogic` and the
solo forms. 2026-09-05: the biblatex options and the citation forms.
2026-09-07: the audit, the harness, the map, the rendering suite, and the
first three fixes. 2026-09-08: the second chat verified all of it on fedxps
against the pre-split package (the differences were exactly the deliberate
list), and fixed the inventory headings and the mode table; the naming grammar,
decided strict, landed in two rounds the same day.
