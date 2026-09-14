# LaTeX completion campaign: TeXstudio's model in Neovim — PLAN

Closed 2026-09-13 (build chat 5, fedxps). The record is `configs/DECISIONS.md`,
the section "nvim/LaTeX: completion rebuilt on TeXstudio's model — 2026-09-13"
(the verdicts of section 1, the numbers of section 3, TODO items 8 and 15
closed, items 16 to 21 opened); the operative rules are `nvim/CLAUDE.md`,
sections Completion, The cold-cache stall and Snippets. This file is a dated
record from here on: annotate, never rewrite. Still pending at the close, the
bigfed half of section 0's criterion 1 and the bigfed numbers of section 3,
carried by `next-chat-2026-09-13e.md` and to be annotated into section 3 when
they land.

Live campaign plan, opened 2026-09-12 on fedxps, revised 2026-09-13 after
the spikes (section 9) and again the same day as build chats 1, 2 and 3
landed stages 1, 2 and 3 (section 3). Edit in place while the campaign runs; when it
closes, annotate the head with the date and the pointer to its DECISIONS
entry and leave it as a record. The evidence is `comparison-2026-09-12.md`
beside this file (its section 6 holds the spikes) and Brandon's
`texstudio-summary.md` beside this file (copied 2026-09-13 from `~/Desktop/texstudio-summary.md`); this plan cites them rather than restating
them. The read-only clone is `~/Desktop/texstudio` (fedxps only, pulled
`--ff-only` by hand).

## 0. Aim, and what "done" means

Rebuild the LaTeX completion layer of `configs/nvim` on TeXstudio's model:
snippet libraries generated per package from TeXstudio's cwl corpus and
loaded per document from VimTeX's package table; the argument half of the
model (citation keys, labels, environment names, packages, files) in the same
menu; TeXstudio's context behaviours (math wrapping, environment
restriction, environment templates); and a record trail that lets a later
session take every decision as settled.

Done means all of:

1. `tests/snipgen`, `tests/nvim-latency` and `tests/nvim-syntax` green on
   both machines.
2. On `completeness.tex`, `:SnippetsReport` lists the core three, the
   french-logic units and the dissertation's packages, and the behaviours of
   section 1 are seen live.
3. The measurements of stage 4 are written into this file.
4. The record trail of section 7 is landed (his documents edited only with
   his approval) and this plan is annotated closed.

The campaign runs over several chats. Each opens from the current
`next-chat*.md` brief beside this file and closes by writing its successor;
section 10 is the log. Anything that surfaces and is not needed for 1 to 4
goes to `TODO.md` as its own item (section 6), not into this campaign, and
a chat that finds a gap in this plan stops and plans rather than improvises.

## 1. Decisions taken — do not re-litigate

Each was put as a batched question with stakes and answered, or measured in
a spike (section 9). Comparison-record section numbers in brackets.

- **Source: the cwl corpus, in its entirety.** Only `#S` (hidden) and `#B`
  (colour-name) rows are dropped, the two TeXstudio's own completer hides. The LaTeX Workshop file was a lossy copy of a tenth of the data
  (2.4); going to the source adds about 450 missing math commands (2.5) and
  named placeholders, and removes 13 wrong arities and 21 artefacts by
  construction.
- **One file per package, loaded per buffer from `b:vimtex.packages` and the
  document class.** Each generated file carries an `includes` header (the
  cwl's `#include` lines); the loader follows headers transitively, so a
  definition appears once however many packages carry it (3).
- **The hub implies its units and their requires.** The french-logic files,
  generated from the `.sty`, carry the hub's `\RequirePackage` closure as
  includes, TeXstudio's own answer for a package without a list (2.2,
  autogeneration). Needed whenever there is no fresh `.fls` (2.1). As built
  2026-09-13: the hub file names its 14 units, each unit its own requires,
  and the loader's transitive walk is the closure, as for every cwl file.
- **Unusual rows (`#*`) are generated, with a small tie-breaking sink and the
  flag kept in the data.** His usage of unusual-marked commands is half a
  percent of stock tokens, all preamble plumbing (2.6); the prior is sound,
  nothing is hidden, no toggle. The sink is a constant subtracted from the
  provider's own offset (10 today), never a replacement of it (spike: a
  replaced offset of −50 buried the row below unrelated matches).
- **One row per distinct signature.** The label is the plain command; the
  inline description column carries the compact shape
  (`[position]{width}{text}`); the window that opens on highlight shows the
  full expansion with named placeholders. Unusual rows end their description
  with a dim `∗`. Spike: the column is drawn by blink's default layout once
  `use_label_description` is on; LazyVim leaves the layout alone.
- **Context behaviours, TeXstudio's.** A math-only row (`m`) expanded
  outside math is wrapped in `$…$` at expansion time (spike: function nodes
  asking `vimtex#syntax#in_mathzone()` give `$\alpha$` in prose and `\alpha`
  inside `$…`; the on-highlight window shows the wrapped form; and a sweep of
  the 73 math-only commands he uses, sampled three times per file over all
  41 dissertation files, found 1,023 uses in math and none in prose, so no
  exception list is needed). A row
  restricted to an environment (`/env`) is hidden outside it; measured
  nearly moot for his packages (six typical rows, all hyperref form fields;
  `\item` and tikz's `\draw` carry no restriction), kept because it is
  cheap.
- **VimTeX's argument completers join the menu through blink's built-in
  `omni` provider**, enabled inside a `\command{…` context and nowhere else;
  VimTeX's own completer patterns decide which braces yield rows. The
  snippets provider closes inside braces. This fixes the measured
  `\begin{` breakage (2.7) and closes TODO item 15.
- **`\begin{` gives TeXstudio's environment template.** VimTeX's bare
  environment names arrive through the omni provider and a transform turns
  each into a snippet-format edit, `name}` plus a body line plus
  `\end{name}`, extended over an auto-paired `}` (spike: accepting
  `enumerate` at `\begin{enum` wrote the three lines exactly); since
  2026-09-13 the loaded files' environment names join VimTeX's there, which
  depend on a fresh `.fls` (the stage-3 smalls below). List-like
  environments get `\item` in the body, known from the generated data and
  french-logic's list environments. This is what TeXstudio does: in its
  environment mode the row is truncated to `\begin{name}` and `expandCode`
  adds content and `\end`. Two alternatives were tried and are declined: a
  `regTrig` environment snippet (blink inserted the pattern text) and a
  pre-expand callback editing the buffer (blink fixes the clear region
  before LuaSnip's callback runs).
- **Document-local commands complete with arity.** The loader reads the
  whole main file and registers its definitions under a per-document
  pseudo-filetype, re-read whenever the file's mtime changes (decided
  2026-09-13, the stage-3 smalls below; the first draft said the preamble,
  refreshed on compile success, and the preamble holds three of the
  dissertation's six). TeXstudio's "user commands"; the `.sty` rules ported
  to Lua in `helpers.lua`. Small; dropped if it grows.
- **Dedupe in two places.** At generation, a package row identical to a row
  of the always-loaded core three is dropped (74 of the closure's 117
  cross-file duplicates; VimTeX's converter does the same). At request time
  the snippets transform drops a repeated (label, description), keyed by a
  string memoised per snippet id, which also lets a hand file shadow a
  generated row. Not at registration: a row's home would then depend on
  which document loaded first.
- **Triggers are plain `\name`.** The trailing `~` was a mistake (memory
  `nvim-snippet-trigger-tilde-was-a-mistake`). Spike: tilde-less triggers
  expand correctly whether typed in full or in part.
- **Option blocks (`#ifOption`) are skipped by default.** They matter for
  babel, biblatex and fontenc only (2.5), and his biblatex options select
  zero lines; the generator's options table may enable named options per package.
- **Excluded from generation:** expl3-commands (expl syntax only) and any
  file with neither a row nor an `#include` line outside option blocks (104
  files on 2026-09-13, fontenc among them). A file with only includes is
  generated, so the loader can follow them; inputenc keeps four rows.
- **`pkg/` is committed to the public repo, with attribution and a licence
  note.** His decision of 2026-09-13, continuing the design of the LaTeX
  Workshop file: every generated file names its cwl source and the clone's
  commit, and `pkg/NOTICE` states that the data derives from TeXstudio's
  completion word lists (GPL-3). He commits; nothing here commits. Because
  the files travel by the normal sync, bigfed needs no clone; regeneration
  and `--check` run where the clone exists.
- **Every cwl is converted; there is no package list.** His call of
  2026-09-13, against an earlier draft that selected about 200 packages from
  the `.fls` files of this machine. One Lua file per cwl file (4,524 on
  2026-09-12, minus the exclusions and the files that yield no rows), and
  the loader picks from them whatever a document names, which is exactly
  how TeXstudio works (it compiles all 4,524 into its binary). Nothing is
  traced on any machine, so the years of old documents on bigfed need no
  step of their own. The objection had been repo weight and regeneration
  noise, and the measurements do not support it: the corpus is 24 MB of
  cwl, an estimated 35 to 45 MB of Lua before git's compression, against a
  4.35 MiB pack today; a regeneration changes what upstream changed (about
  11% of files a year); `gpushall` prompts only for a file over 25 MB or
  matching a secret glob, so the first push lists the new files once and
  asks nothing (the largest source, biblatex, is 276 KB of cwl). Option
  blocks are enabled, if ever, through a small options table in the
  generator.
- **Hand libraries survive as hand files:** the 32 bib entry templates and an
  empty local file for his own snippets. `latex-workshop.lua` retires.
- **Deferred (section 6):** key-value completion inside `[…]`; named
  placeholders for french-logic's own commands; ranking from his corpus
  frequency; the five stray highlight colours (a bench matter, 1.4); `\end{`
  completion (VimTeX's `]]` closes environments, and the template above
  already writes `\end`).

- **Stage-1 smalls, decided 2026-09-13 (build chat 1), each asked with its
  measurement.** An environment row's description is TeXstudio's own list
  row, `\begin{alignat}[alignment]{ncols}`; the `\end` is in the
  on-highlight window (blink's description column defaults to 30 characters,
  a stage-3 knob, section 8). `\begin{itemize}` and `\begin{itemize}\item`
  are one row per signature, with `\item` in the body when any row of that
  environment, in the file or in the always-loaded lists, carries it
  (measured: TeXstudio chops the `\item`, merges the pair by hash, then
  hard-codes `\item` for itemize, enumerate and description only). `(x,y)`
  is one placeholder per bracket group, TeXstudio's rule. In a row with
  explicit markers the bare groups attached to the row's own command are
  filled too, so `[scale=%<1%>]{file}` gives two stops where TeXstudio
  gives one; groups after that chain (an inner `\begin{axis}` in a
  multi-line template) stay literal, and marker-free rows get TeXstudio's
  rule exactly. Starred forms are separate rows. `#keyvals` blocks are a
  fifth field of the same generated file, raw lines keyed by the block's
  target text. `pkg/NOTICE` as drafted, plus `pkg/COPYING` (the GPL-3 text
  from the clone), and every generated header carries the cwl's own leading
  comment block, which credits its authors. `tests/snipgen` as its README
  lays it out. From the reading, applied as objective: `B` (colour) rows are
  dropped like `S`, as TeXstudio's completer drops them; `cwlAliases.dat`
  needs no emission (401 entries, six not derivable by name, none his). He
  gave the itemize, marker-row and keyvals answers tentatively ("I think");
  the rows are in `pkg/latex-document.lua`, `pkg/graphicx.lua` and any
  file's `keyvals` field, and reversing any of them is a generator change
  plus a regeneration.

- **Stage-2 smalls, decided 2026-09-13 (build chat 2), four asked with their
  measurements, the rest applied as objective.** The `.sty` files live in a
  sibling directory `lua/snippets/sty/`, not `pkg/`: `--all` deletes any
  `pkg/*.lua` without a cwl source and `pkg/NOTICE` claims GPL-3 over every
  file in that directory, and both stay exactly true; the stage-3 loader
  looks in both directories. An optional argument gives **two rows per
  signature**, the bare one and the bracket one (`\tcite{}` and
  `\tcite[]{}`; `\begin{proofsketch}` and `\begin{proofsketch}[Proof
  sketch]`, the text default as placeholder text; `\begin{proof}` and
  `\begin{proof}[]`, a macro default being no placeholder text): his usage
  is 93 bare `\tcite` against 40 with a locator, 8 against 0 for `\pcite`,
  42 and 15 bare proof and proofsketch against none with a bracket, and no
  `\tcite[]` in the 41 files, so the old single row with its bracket always
  inserted was being hand-corrected; TeXstudio's own `.sty` parser emits
  both forms too. **No deduplication against the core three** for `.sty`
  rows: four coincide (`\emptyset`, `\iff`, `\models`, `\to`, each core twin
  `#m`), the request-time transform drops them, and `--sty` reading nothing
  but `.sty` files is what lets the startup check regenerate byte-identical
  files on bigfed without the clone; reading the keys from the generated core
  files was the alternative, declined for a reader of our own output over
  four rows. **`\DeclareMathSymbol` is read** (`\Yright`, `\shortminus`,
  `\strictif`, all in the AUDIT inventory, `\strictif` registered and used
  four times), math-wrapped by construction, as is `\DeclareMathOperator`:
  540 names. `\poscite` (a `\DeclareCiteCommand`, arity biblatex's) is
  deferred (section 6). Applied as objective, each with its measurement in
  `next-chat-2026-09-13b.md`'s predecessor round: each file's `includes` are
  its own `\RequirePackage` names, the hub's its 14 units, the closure being
  the loader's transitive walk as for every cwl (36 real packages, 34 with a
  generated file, fontenc and lmodern keyvals-only); `\usetikzlibrary{x}` is
  the include `tikzlibraryx`, TeXstudio's mapping in `latexdocument.cpp`; a
  list environment is one whose begin code opens itemize, enumerate,
  description (TeXstudio's three, `codesnippet.cpp`) or a list already
  known, exact on all 24 environments where the old name heuristic missed
  axiomproof and an `\item`-in-body rule flagged block, proof and
  proofsketch, which write their own; descriptions are the bare shape
  (`{}{}`, `[]{}`) and rows keep definition order; one `-- sty-sha256:` per
  file over its own bytes, mirroring `cwl-sha256`, so the blob stamp's order
  coupling with `snippets.lua` goes; `--coverage` moved verbatim with its
  old name set (`\DeclareMathSymbol` names outside it, so `\Yright` and
  `\shortminus` are not reported); `--sty` takes one argument, the hub, and
  generates every required package whose `.sty` sits beside it, recursively
  (the quarry unit, never required, is excluded by construction); units
  deduplicate against earlier files in hub order, so `\qedsymbol`, defined
  in structure and again in proof, appears once; the old startup check and
  `french-logic.lua` stay live until stage 3 retires both.

- **Stage-3 smalls, decided 2026-09-13 (build chat 3), two asked with their
  measurements, the rest applied as objective.** **At `\begin{` the template
  transform offers the union of VimTeX's environment names and the loaded
  files'.** VimTeX's env completer knows an environment from its own 202 data
  files, the project's own `\newenvironment` lines, and a scan of each `.sty`
  the package table names, and that table is the `.fls` when one exists,
  otherwise the preamble: measured headless, the fixture (no `.fls`) got 65
  names and none of french-logic's 25, the root (`.fls` of 2026-08-09) 179
  and none of the 25, the completeness chapter (whose main is the article
  wrapper, `.fls` of 2026-09-12 naming the 14 units) 171 and all 25; `align`
  was absent on the fixture. The fixture's closure over the generated files
  is 100 files, 293 environment rows, 212 names, of which VimTeX's data knows
  125. blink applies a provider's transform to an empty response too, so the
  omni transform appends every name of the buffer's files (and its document)
  that VimTeX did not return, each rewritten into the same bare template.
  Declined: VimTeX's names only (the plan's letter; french-logic environments
  would appear only after a fresh compile), and a custom blink source for
  `\begin{` (cleaner separation, twice the code). **Document-local commands
  come from the whole main file, re-read when its mtime changes** (one stat
  per request, 0.06 ms per re-read on the root's 142 lines): the plan said the
  preamble, which holds three of the dissertation's six own commands; the
  other three (`\appheading`, `\appsubheading`, `\comptablebody`) sit after
  `\begin{document}` inside the appendix conditional. No chapter file defines
  any. Declined: the whole project through VimTeX's parser memoised on the
  project mtime (11.6 ms re-parse inside the first request after any save on
  the root, 3.7 ms on a chapter), the same refreshed on compile success (the
  plan's letter widened; a definition appears only after the next successful
  compile), and preamble only. Applied as objective: a command name typed
  inside another command's braces (`\textbf{\al`) is a snippets context and
  not an omni one, or VimTeX's bare-name command rows return (pinned); the
  filetype order is `tex`, `hand-local`, `doc-<id>`, the core three, the
  class, the closure in walk order, so a hand row shadows a generated one and
  the core row wins over its four `sty/` twins; files load by path with
  `dofile`, never `require` (names carry dots); the article class has no list
  in TeXstudio's own alias table (`cwlAliases.dat`: `article:` →
  latex-document, tex), so the report says "no list for this class" rather
  than "missing"; both transforms are idempotent because blink re-applies a
  provider's transform when it resolves an item, so the sink is assigned from
  the provider's offset, never decremented, and the template rewrite is
  guarded; the interim sink is 5 (unusual rows at 5, above path's 0; stage 4
  sets it); rows appended inside `\begin{` carry the fields blink stamps on a
  provider's own rows before the transform (`source_id`, `source_name`,
  `cursor_column`, `score_offset`, `kind`), without which the accept path
  errors inside blink (found on the harness); the 32 bib entry templates
  moved to `hand/bibtex.lua` without their `~`, `hand/local.lua` starts
  empty; the startup check compares the 15 per-file stamps and regenerates
  with `snipgen.py --sty`; the description column's width is left at blink's
  30 until a live look with the menu in front of him (section 8).

- **Stage-4 smalls, decided 2026-09-13 (build chat 4).** Applied as
  objective, with its measurement: blink's luasnip preset answered
  `snippets.active()` with `is_hidden_snippet()`, LuaSnip's `expandable()`
  (every registered trigger of the buffer's snippet filetypes matched against
  the line), on every `InsertCharPre` and `TextChangedI`, where the answer is
  discarded (`completion.trigger.show_in_snippet` is true); with the ~105
  pseudo-filetypes it cost 3.5 ms per prose keystroke at the end of the
  fixture's longest line (23 to 19 ms) and made the closure load fall on the
  first insert-mode keystroke of a session, whatever it was.
  `completions.lua` now answers `active()` from LuaSnip's session alone and
  keeps the expandable check for `<Tab>`/`<S-Tab>` (a filter with a
  direction); every reachable behaviour is unchanged, the four `<Tab>`
  corners measured identical in fresh instances, and two pins hold it (prose
  keystrokes never reach the loader's `ft_func`; a fully typed trigger with
  the menu closed still expands on `<Tab>`), the mutation with the override
  removed failing exactly the first. The live look of the same day: `\name`,
  `\cite{`, `\begin{` and a math-only row in prose all as intended, the
  math awareness the surprise, the width preview skipped, nothing reported
  wrong. The sink, the pre-warm and the description width were his round
  of the same day, asked with the measurements: **the sink stays at 5**
  (frecency never lifts a snippet row, blink's sort text already lists a
  typical row before its unusual twin, 5 moved no row in any probe and 10
  buried one); **the closure is pre-warmed in idle time** after `User
  VimtexEventInitPost`, one file per 10 ms tick (100 files in 2.5 s on the
  harness, 104 in 3.6 s headless on the chapter), the request path unchanged
  as the fallback, so the first request finds `ft_func` at 0 ms and the menu
  27 to 38 ms after the keystroke, blink's own first build, or about 100 ms
  of registration left when typing starts within the first second; **the
  description column is 45 cells** (2.3% of the chapter's rows still cut,
  from 9.9%). Declined in the round: sink 0 (un-decides the small sink for
  no observed gain), sink 10 (buries), a synchronous pre-warm at init, and
  the widths 30, 40 and 60. Four pins were added in stage 4 (the two of the
  `active` fix, the pre-warm's, the width's), the suite at 71, the
  pre-warm's mutation-verified.

## 2. The target shape

Under `nvim/lua/snippets/` unless said otherwise.

| path | role |
|---|---|
| `snipgen.py` | the one generator, replacing `sty-lua-snippets.py`: `--all` (the clone's whole `completion/`), `--cwl` (named files, for spot checks), `--sty` (one argument, the hub; every required package whose `.sty` sits beside it follows, recursively; stage 2), `--check`, `--coverage` (with `--sty`, moved verbatim; stage 2), `--out-dir` or `-o`, `--core DIR` (the always-loaded lists to deduplicate against), `--option PKG:OPT` (enable an `#ifOption` block for a run); an options table for `#ifOption` blocks, empty by default |
| `pkg/<name>.lua` | generated, never hand-edited, committed; header names the cwl source, its sha256, the clone's commit and date, the generator version and the cwl's own leading comment block; `return { package=…, includes={…}, lists={…}, snippets={…}, keyvals={…} }`, the snippets built through a small `S` wrapper that stores the raw classification as `cls` |
| `sty/<name>.lua` | generated by `--sty` from a `.sty` of this repository (french-logic: the hub and its 14 units, 2026-09-13), never hand-edited, committed; the header names the source path relative to the repo, the `\ProvidesPackage` description and the file's own sha256, with no licence line: this is his own package's data and `pkg/NOTICE` does not cover it; the same `return {…}` shape, so the loader reads both directories alike |
| `pkg/NOTICE`, `pkg/COPYING` | attribution and licence note for the derived data (approved 2026-09-13) and the GPL-3 text copied from the clone |
| `hand/bibtex.lua`, `hand/local.lua` | hand-kept; `local` is his, initially empty |
| `helpers.lua` | `mathwrap(nodes)`, `in_env({…})` with a per-request memo (keyed on buffer, changedtick and cursor), `docsnippets(lines, lists)` for the document's own definitions, the `.sty` rules ported to Lua (stage 3) |
| `loader.lua` | registration on demand by `dofile` path, `ft_func`, the document parse on mtime change, `envs(bufnr)` for the `\begin{` transform, `:SnippetsReport`, `:SnippetsReload`; looks up `pkg/<name>.lua`, then `sty/<name>.lua` (stage 3); the idle pre-warm after `User VimtexEventInitPost`, `M.prewarm_buffer`, one file per tick (stage 4) |
| `lua/plugins/snippets.lua` | thin since stage 3: the startup sha check for the french-logic files (per file against the `sty-sha256` stamps in `sty/`; no blob, no order to agree on), `opts.ft_func = loader.ft_func`, `loader.setup()` |
| `lua/plugins/completions.lua` | the two gates (the omni one excluding a nested command name), the `omni` provider in the TeX source lists, `use_label_description`, the two `transform_items` (sink and dedupe; label dedupe and the `\begin{` template over the union) (stage 3); the `snippets.active` override and the 45-cell description column (stage 4) |
| `tests/snipgen/` | the generator's suite: fixture cwl (stage 1, 14 checks) and `.sty` (stage 2, 8 more), hand-written golden Lua, `--check` idempotence, a shape check under stub modules, the amsmath spot checks, a recorded mutation |

**Generation rules, cwl line to snippet** (as built in stage 1; the suite
pins each). Skip `S` (hidden) and `B` (colour name) rows, as TeXstudio's
completer drops both; skip `\end{…}` rows. `#keyvals` blocks go verbatim
into the file's `keyvals` field (raw lines keyed by the block's target
text) for the deferred tier; `#ifOption` blocks are skipped unless the
generator's options table or `--option PKG:OPT` enables the option;
`#include:` to the header, self and repeats dropped; `#repl`, comment
lines and unknown `#word:` directives are tolerated, the last with one
warning per word and file; unknown classification letters warn once per
letter and file and are kept in `cls`. Every `%suffix` is stripped first;
then `%<x%>` is a placeholder `x` (`%:` flags stripped), `%|` the final
cursor, `%\` a newline. Bracket groups of all four kinds become one
placeholder each, named by their content, except an empty group and a
group already holding a marker; in a row with explicit markers only the
groups attached to the row's own command are filled (its leading chain of
groups separated by whitespace), so `[scale=%<1%>]{file}` gives two stops
and an inner `\begin{axis}` in a multi-line template stays literal;
marker-free rows get TeXstudio's rule exactly. A `\begin{env}` row becomes
`\begin{env}` plus its arguments, a body line (`\t${n}`, or `\t\item ${n}`
when any row of that environment, in the file or in the always-loaded
lists, ends in `\item`), and `\end{env}`; the environment name is never a
placeholder; a row with `%\` is emitted as the multi-line snippet written,
with no body or `\end` added; the file's `lists` table names its
environments whose body is `\item`. TeXstudio's generic template row
becomes trigger `\begin` with the name mirrored by a `rep` node. The
trigger is `\name` (`\env` for an environment; starred forms keep the
star); a name runs over letters, digits, `@`, `:` and `_`, except an
underscore that opens a brace group, which is a subscript
(`\sum_{min}^{max}` is `\sum`). `dscr` is TeXstudio's list row minus the
leading name (the whole first line for an environment), plus ` ∗` when
`#*`; `priority` 900 when `#*`; `m` wraps the nodes in `h.mathwrap`; a
leading `/env1,env2` sets `show_condition = h.in_env{…}`; the raw
classification text is kept on the snippet as `cls`. Identical (trigger,
dscr) pairs are deduplicated within a file, first wins except that a
typical row replaces its unusual twin wherever it comes, and against the
core three (tex, latex-document, latex-dev, in that order, each against
the previous) for every other file. A bare-backslash row, a row without a
leading backslash and an unparsable `\begin` row are skipped with a
warning; CRLF files are read as TeXstudio reads them; a file with neither
rows nor includes is not generated.

**Generation rules, `.sty` definition to snippet** (as built in stage 2; the
suite pins each). The braced forms `\newcommand`, `\renewcommand`,
`\providecommand`, `\DeclareMathOperator`, `\DeclareMathSymbol`,
`\newenvironment`, `\renewenvironment` and `\newtheorem` are read after `%`
comments are stripped; a name with `@` is skipped; the first definition of a
name gives its place and the last its shape; `\DeclareMathOperator` and
`\DeclareMathSymbol` define a name only where the `\newcommand` family has
not. A command is `\name` plus one bare `{}` placeholder per mandatory
argument; a definition with an optional argument gives two rows, the bare one
first and then the one with the bracket, whose placeholder text is the default
when it is text and empty when the default is empty or starts with a
backslash; an empty default `[2][]` is still an optional argument. An
environment is `\begin{name}` plus its bracket and `{}` groups, a body line
(`\t${n}`, or `\t\item ${n}` when its begin code opens itemize, enumerate,
description or an environment already known as a list in this package or an
earlier file, to a fixpoint) and `\end{name}`; a `\newtheorem` is a bare
environment; the file's `lists` table names its list environments. The
trigger is `\name`; the description is the bare shape after the name (`[]{}`,
`[Proof sketch]`), the whole first line for an environment; rows keep source
order. Math rows (the two `\Declare…` forms) are wrapped by `h.mathwrap` with
`cls` `m`; no other row carries a classification, a priority or a condition.
Every `\RequirePackage` and `\RequirePackageWithOptions` name is an include,
in source order, once, the bracket allowed to span lines and the braces a
comma list; `\usetikzlibrary{x}`, `\usepgfplotslibrary{x}` and
`\tcbuselibrary{x}` are the includes `tikzlibraryx`, `pgfplotslibraryx`,
`tcolorboxlibraryx`. A required package whose `.sty` sits beside the input is
generated too, recursively, in require order; files deduplicate their
(trigger, description) pairs against every file before them in that order
and never against the core three. The header names the source relative to
the repository, the `\ProvidesPackage` description and the file's own sha256;
a file in the output directory whose header names a source that no longer
exists is removed (reported by `--check`); any other file there is left alone.

**Coverage.** Every file in the clone's `completion/` (4,524 on
2026-09-12), one Lua file each, minus expl3-commands and minus any file
with neither a row nor an include outside option blocks (104 on
2026-09-13, fontenc among them; 4,419 files generated). The loader treats
an `includes` entry with no generated file as missing, silently, and
`:SnippetsReport` names it. Packages with no cwl at all (his own classes
mod-cv, eptcs, deon16; old files on bigfed) get nothing until the deferred
autogeneration item (section 6).

**Loader behaviour.** The filetype function is the loader. For a TeX-like
buffer it reads `vim.b.vimtex.packages` (0.09 ms, measured; no cache
needed) and the document class, adds the core three, closes over the
`includes` headers, registers on demand any package whose `pkg/` or `sty/` file is not
yet registered (`ls.add_snippets("pkg-<name>", …, { key = "pkg-<name>" })`),
and returns `{"tex", "hand-local", "doc-<id>"}` followed by the package
pseudo-filetypes, the core three first, then the class, then the closure in
walk order (as built 2026-09-13: the hand file and the document precede the
generated files, so their rows win the request-time dedupe). The closure is
memoised per buffer on the sorted package table plus the class and rebuilt
when that key changes; the document's own definitions are re-read from the
whole main file whenever its mtime changes, one stat per request, and
registered under `doc-<id>` (VimTeX's state id). Bib buffers get `{"bib",
"hand-bibtex"}`; everything else LuaSnip's default. Because registration
happens on the request path, no VimTeX event hook is needed for correctness:
a package table refreshed by a compile is seen at the next request. Since
stage 4 (2026-09-13) the closure is registered in idle time after `User
VimtexEventInitPost`, one file per 10 ms tick (`M.prewarm_buffer`; 100 files
in 2.5 s on the harness, 104 in 3.6 s headless on the chapter), the request
path registering what is left if typing starts first; measured before the
pre-warm, the first request paid 660 to 750 ms, nearly all of it LuaSnip's
snippet construction (61 to 68 µs a row; parsing 100 files is 11 to 29 ms),
and the heap rises by about 123 MB after a full collect either way.
`:SnippetsReport` prints the pre-warm's state and the loaded, missing and
deduplicated counts for the buffer; `:SnippetsReload` re-adds every
registered package under its key and then calls
`clean_invalidated({ inv_limit = 0 })` (spike: without the clean, the old
rows stay listed as invalidated).

**Gates and providers.** `in_command_context` is the present gate's first
branch only (`\name` being typed); the snippets provider is enabled there
alone. `in_brace_context` is the present brace branch (300-character window)
*minus* the command branch, so that `\textbf{\al` is a snippets context (as
built 2026-09-13; the brace branch alone would have let VimTeX's bare-name
command rows through); the `omni` provider is enabled there alone, so
VimTeX's command completer never fires. The path provider is unchanged. On the snippets provider,
`use_label_description = true` and a `transform_items` that (1) subtracts the
sink constant from the offset of rows whose snippet priority is below 1000,
via a table memoised per snippet id, and (2) drops repeated (label,
description) pairs. On the omni provider, a `transform_items` that (1)
removes duplicate labels (VimTeX returns `amsmath` twice from two trees) and
(2) inside `\begin{…` rewrites each row into a snippet-format text edit,
`name}` + newline + body + newline + `\end{name}`, extending the edit over
an auto-paired `}`, with `\item` in the body for list environments, then (3)
appends the environment names of the buffer's loaded files and its document
that VimTeX did not return, as the same template, stamped with the fields
blink puts on a provider's own rows (decided and built 2026-09-13). Both
transforms are idempotent: blink re-applies them when it resolves an item.
`snippets.active` is answered from LuaSnip's session alone; the expandable
check blink's preset ran on every keystroke is kept for `<Tab>`/`<S-Tab>`;
the description column is 45 cells (stage 4, 2026-09-13).

## 3. Stages and acceptance

**Stage 1 — the cwl front end.** Write `snipgen.py`'s cwl mode,
`pkg/NOTICE` (draft), and `tests/snipgen`. No config changes. Accept when:
the suite is green; `--all` converts the clone's whole `completion/`, with
its running time, file count and total size recorded here; on amsmath, `\binom` has named
placeholders, `\cfrac` gives two rows, `\dotsb` is math-wrapped, `align`
becomes an environment template and is named in `lists` only if its body is
`\item` (it is not), `\Hat` is absent, `\AmSfont` carries `∗`; `--check` is
green twice in a row; one mutation (break the `%<…%>` rule) turns the suite
red, and the README records it.
*Landed 2026-09-13, build chat 1.* `--all` converts the clone at
`0362907c2` in 4.3 s into 4,419 files, 29.3 MB of content (38 MB on disk),
the largest `logix.lua` at 392 KB, far under the 25 MB vet limit; 104
files with neither rows nor includes are skipped and expl3-commands
excluded; `--check` green twice; 42 warnings, every one an upstream data
error, listed in `next-chat-2026-09-13.md`. Every acceptance row holds and
is pinned by the suite's amsmath checks. Cross-check against the closure
spike's per-file counts of typical commands: amsmath 67, biblatex 125,
class-memoir 46, tikz 18 and tex 347, all exact; latex-document 371 after
the core dedupe drops the six rows tex carries (377 before it, the spike's
377); latex-dev 30 against the spike's 25, because the spike's filter
excluded five Expl rows whose `*` sits after `beginEnv` and is no
classification, typical in TeXstudio's reading and here. `\parbox` four
signatures, `\textcite` three, `\section` three with memoir's. Both Neovim
suites green with `pkg/` in place; `stow-all-dry` shows nothing to do (the
fold is above `lua/snippets`, so the new directory is live through the
link). Suite: 14 checks, one mutation recorded.

**Stage 2 — the `.sty` front end folded in.** The existing generator's
parsing moves into `snipgen.py --sty`, emitting one file per unit plus the
hub file, the hub's `includes` naming the units, each unit's its own
requires, the lists unit's `lists` naming french-logic's list environments,
all under `sty/`; `--coverage` unchanged; the startup sha check left on the
old file until stage 3 flips (decided 2026-09-13; the brief had offered
re-pointing it at once). Accept when the french-logic files regenerate from
the hub alone with `--check` green and the 537 commands and environments
are all present, now without `~`.
*Landed 2026-09-13, build chat 2.* `snipgen.py --sty
latex/french-logic/french-logic.sty` writes 15 files under `sty/` in 0.09 s:
544 rows over 540 names, the old 537 plus `\Yright`, `\shortminus` and
`\strictif`, the four extra rows being the bracket signatures of `\tcite`,
`\pcite`, proof and proofsketch; no trigger carries `~`; the lists unit's
file names its ten list environments (axiomproof now among them, block,
proof and proofsketch not); the hub file has no rows and the 14 units as
includes, the units their own requires (preamble 18, core 9, diagrams 7 with
the five tikz libraries); `\qedsymbol` once. `--check` green twice,
`--coverage` exit 0, the old `french-logic.lua` `--check` still up to date
and its startup check untouched (decided: it flips at stage 3), both Neovim
suites green with `sty/` in place, `stow-all-dry` nothing to do, `--all
--check` 0/0/0 after the emitter refactor. Suite: 22 checks, the generator
met the hand-written goldens byte for byte on its first run, one mutation
recorded.

**Stage 3 — loader, gates, provider; retire the old files.** Accept when both
Neovim suites are green with these changes to the latency suite: the
`\cite{`/`\ref{` gate checks flip to snippets-closed and omni-open; a
bare-backslash check shows omni closed; accepting `enumerate` at
`\begin{enum` writes `\begin{enumerate}`, an indented `\item` line and
`\end{enumerate}` with no stray brace (the breakage pin); omni rows appear
at `\cite{` with a small `fixture.bib` added beside the fixture; a snippet
row carries a description; `\alpha` accepted in prose yields `$\alpha$` and
in math `\alpha`; an environment-restricted row is hidden in prose and shown
inside its environment; the fixture, which has no `.fls`, still offers
`align` through the hub-implies header; a `\newcommand` in the fixture's
preamble completes with its arity; the Lua buffer check still passes; the
`<Tab>` jump checks still pass. `:SnippetsReport` on `completeness.tex`
lists about 100 packages.
*Landed 2026-09-13, build chat 3.* The two smalls asked in one round with
their measurements (section 1), the rest applied as objective. `helpers.lua`,
`loader.lua`, `hand/bibtex.lua` (the 32 templates, no `~`), `hand/local.lua`
(empty); `snippets.lua` thin, with the per-file stamp check; `completions.lua`
with the two gates, the omni provider in the three TeX source lists,
`use_label_description`, the two transforms; `french-logic.lua`,
`latex-workshop.lua`, `sty-lua-snippets.py` and the blob stamp gone, the two
stylua ignore lines with them. Latency suite 67 checks (was 42): the two
`\cite{`/`\ref{` checks flipped, the window pins moved to the omni gate,
and 27 added, every acceptance row above among them plus `:SnippetsReload`
keeping its counts and a hand row shadowing its generated twin; three mutations
recorded in its README (union removed: exactly the `hilbertlist` and
`proofsketch` template checks; nested branch removed: exactly the
`\textbf{\al` omni check; math wrap disabled: exactly the `\alpha` wrap and
the four `\frac` checks). Syntax suite 56, snipgen 22, `stow-all-dry`
nothing to do. `:SnippetsReport` headless: the completeness chapter (main the
article wrapper, 111 packages) loads 104 files, 7,834 rows, 31 names with no
file, 6 document rows, 211 environment names for `\begin{`; the root (103
packages) 110 files, 9,330 rows, 33 missing, 7 document rows, 259 names; the
fixture 100 files, 7,756 rows, 24 missing. First `ft_func` 654 ms on the
chapter and 763 ms on the root, 0.4 ms after. The description column's width
is not yet decided (section 8).

**Stage 4 — measure, then tune.** `bench.py` per keystroke inside a
`\command` context and in prose, before and after, on both machines; the
two transforms' cost at the full row count (spike: 0.19 ms per 200 rows
before memoisation); the sink constant against frecency (accept one `∗` row
three times and observe its rank); the first-use cost of `\begin{` and
`\usepackage{` on a cold package cache (`vimtex-warm` primes
`pkgcomplete.json` already; confirm it suffices); memory and startup time.
Write the numbers here; tune the one constant.
*Measured and tuned 2026-09-13, build chat 4, fedxps in performance mode;
bigfed pending the twin (queue item 4 of the brief).* The section 9 before
figures were taken in balanced mode and could not be reproduced (the same
pre-campaign tree measures 53 and 19 ms here against the 146 and 92 recorded;
the power mode explains part, the rest is unexplained), so both trees were
measured under one machine state, interleaved: the live tree against a
scratch extraction of the committed pre-campaign tree (HEAD `1bb69b1`, 1,054
snippets). Per keystroke at the end of the fixture's 2,069-character line,
spike4's method, medians of three runs: inside a command name 53 ms before
and 54 after (p90 56 and 64); in prose 19 before, 23 after as landed and 19
after the `snippets.active` fix (section 1, stage-4 smalls). Per request in a
command name the luasnip source costs 12 to 13 ms (0.8 to 1.1 before: blink's
shallow copy of 7,760 rows against 1,054), the Rust fuzzy pass 5.4 ms per
call (0.9), the live transform 0.6 ms; six requests for 35 keystrokes in both
trees, none in prose. The transforms at the full row count, isolated: 7,758
rows, cold memo 5.2 ms, warm 1.4 ms; blink's per-request shallow copy of
every row 5.9 ms and its show_condition pass 3.3 ms (233 rows hidden in
prose); the omni transform at `\begin{a` 0.7 to 2.3 ms with 137 rows,
VimTeX's env completer 23 ms for the empty prefix and 2 ms for `a`,
`loader.envs()` 0.35 ms. The first keystrokes of a session, fresh instances,
medians of three: entering insert mode 107 ms in both trees; the closure
load 660 to 750 ms (`ft_func`), which as landed fell on the first
insert-mode keystroke and now falls on the first completion request; that
request's own first build 25 to 75 ms for the source items, 6 to 22 ms
transform, 18 to 19 ms fuzzy, the menu 32 to 43 ms after the keystroke; the
second request 27 ms to the menu (before: 15 and 10). Memory: the closure
adds 123 MB of Lua heap after a full collect and 174 MB of RSS (before: 1
and 4; headless `loadprobe.lua` on the chapter: heap 10 to 151 MB, 129 after
a full collect, execute plus add 603 ms, 61.5 µs a row). Startup to VimEnter
with the fixture, headless, five runs: 216 ms after against 285 before (the
old layer built its 1,054 snippets at `FileType`); the per-file stamp check
0.9 ms. The sink against frecency, a fresh frecency store per condition:
accepting `\AmSfont` three times from `\AmS` changed nothing at any sink
(0, 3, 5, 8, 10), because blink hands an accepted LuaSnip row to the
source's own `execute`, which never reaches the accept path's
`fuzzy.access` (wrapped: zero calls; the store stayed at 0 bytes), so
frecency never ranks a snippet row and the sink is a static tie-break: at 0
the fuzzy score already puts `\AmS` (99) over `\AmSfont` (91); at 5 the
first three rows keep their order; at 10 `\AMSautorefname` drops below the
unrelated `\atoms`. The cold package cache on the chapter (111 packages,
headless, a scratch cache root): `\begin{a` 13.3 s cold, 28 ms in the same
session and 31 ms in a new session on the primed root, so `vimtex-warm`
suffices for `\begin{`; `\usepackage{a` 1.3 s cold and 0.9 s in every new
session (VimTeX's package completer lists `kpsewhich --all ls-R` per session
and caches nothing on disk), 11 to 23 ms after. On the fixture (one package
in the table, the closure through the hub): `\begin{a` 356 ms cold, 16 to
21 ms primed; `\usepackage{a` 0.8 s per session. Tuned in his round (section
1, stage-4 smalls): the sink stays at 5, the closure is pre-warmed in idle
time, the description column is 45 cells. After the pre-warm the first
request of a session finds `ft_func` at 0 ms and the menu 27 to 38 ms after
the keystroke; typing within the first second leaves about 100 ms of
registration on that request. The backslash that opens a command is itself a
request in both trees (blink asks the source on the lone `\` and refilters
the letters locally, with no fuzzy pass until a letter arrives): 21 ms in
the old tree, 50 ms (p90 63) in the new, the source's 10 ms copy of 7,760
rows and 2 ms of transform per request, so a command word costs about 30 ms
more once, at its backslash, and the same per letter after; cutting that
means fewer rows per request, a source of our own rather than LuaSnip's,
and is not proposed.

**Stage 5 — records, then close.** Section 7. On bigfed: `gpullall`, both
suites, `:SnippetsReport` on a chapter, and the stage-4 measurements there
(the successor brief's queue). Annotate this file closed.
*Landed 2026-09-13, build chat 5, fedxps.* The baseline first: syntax 56,
latency 71 and snipgen 22 all green; the clone unmoved at `0362907c2`; `--all
--check` 4,419 files, 0 stale, 0 missing, 0 extra (42 warnings, as recorded);
`--sty --check` 15 files, 0/0/0; the four plugin commits unchanged;
`:SnippetsReport` headless on the completeness chapter 104 files, 7,834 rows,
the pre-warm done in 3,580 ms of idle ticks, 31 names with no file, 6 document
rows, 211 environment names, `:messages` holding only the report. Then the
records of section 7, each from a draft he approved, in order: the
`DECISIONS.md` section; `TODO.md`; the charter's head sentence and its
Completion, cold-cache and Snippets sections whole; the `configs/CLAUDE.md`
line; and three one-line fixes a sweep for the retired names found
(`~/Desktop/CLAUDE.md`, machine-local, so bigfed's copy is mirrored by hand;
`latex/CLAUDE.md`; `nvim/docs/latex-register-taxonomy.md`). The comment in
`french-logic-cite.sty` that names the old generator is left for his next
french-logic session (a `.sty` change wants both nets). bigfed pending: the
successor's queue; he cloned the twin there at the close, at the same HEAD,
and copied the charter byte-identical, so its queue is the suites, the
`~/Desktop/CLAUDE.md` items and the numbers.

## 4. How the work is done

Both Neovim suites after every stage; the syntax suite is not expected to
move but is run. Nothing is hand-edited under `pkg/` or `sty/`; a wanted
divergence goes into the generator's overrides table (TODO item 8's missing
mechanism). The clone is pulled `--ff-only` before a cwl regeneration and
its HEAD stamped into every `pkg/` file; `--all --check` is the drift test
for `pkg/` and runs only where the clone exists, `--sty
latex/french-logic/french-logic.sty --check` the one for `sty/` and runs
anywhere. Generation is light. The benches run on both
machines. Git is his: the tree is left dirty and described. His documents
(`CLAUDE.md` files, `TODO.md`, `DECISIONS.md`) are edited only after he
approves the draft.

## 5. Hazards to design for

- **Stale or absent `.fls`.** The root `dissertation.fls` (2026-08-09) lists
  no french-logic unit; the fixture has no `.fls` at all. The hub-implies
  header is the fallback; VimTeX refreshes the table only on a successful
  compile, so a freshly added `\usepackage` shows up after the next save
  under the watcher.
- **Auto-pair and `close_braces`.** Inside `\begin{ali}` VimTeX's
  `s:close_braces` sees the `}` ahead and adds none; the omni transform
  extends its edit over that `}`; the suite pins the exact output.
- **Per-request costs.** blink shallow-copies every cached row per request
  and caps the list at 200 (`max_items`); the transforms run over the full
  provider result, so their per-row work must be a table lookup. Stage 4
  measures.
- **Menu opening.** blink opens on keyword characters, not on `{`, so a
  row inside `\cite{` or `\end{` appears once a letter is typed. VimTeX's
  `]]` closes the innermost environment in insert mode.
- **Case.** TeXstudio is case-insensitive by his setting; blink's matcher has
  its own rules; VimTeX's `ignore_case`/`smart_case` govern omni rows. A
  place where behaviour can surprise, not a design point.
- **The cold scan returns.** The omni provider re-introduces VimTeX's
  kpsewhich scan on a cold machine for `\begin{` and `\usepackage{`
  (measured 2.9 s once, then tens of ms). `vimtex-warm` primes that cache;
  the charter's cold-cache rule must say so again.
- **Public repo and licence.** TeXstudio is GPL-3 (its `COPYING`); the cwl
  files carry no licence statement of their own; the configs repo has no
  LICENSE file. VimTeX (MIT) and LaTeX Workshop (MIT) redistribute converted
  lists, a precedent, not a licence. Settled 2026-09-13 (section 1): `pkg/`
  is committed with per-file attribution and `pkg/NOTICE`. The startup
  check must never try to regenerate cwl files on a machine without the
  clone; it regenerates only the french-logic files, as today. `--sty`
  reads nothing but `.sty` files (decided 2026-09-13), so that
  regeneration is byte-identical on both machines.
- **The first push.** About 4,400 new files appear at once; `gpushall` lists
  first-time-committed files in its output and prompts only above 25 MB or
  on a secret glob, so expect one long listing and no questions. Confirmed
  2026-09-13: 4,419 files, 29.3 MB, the largest 392 KB.
- **Includes of files that do not exist.** latex-dev includes
  expl3-commands, which is excluded; the loader must skip a missing include
  without noise and report it only in `:SnippetsReport`.
- **TeXstudio's `#*` is a prior, not his usage.** Hence the small offset and
  the kept flag; a corpus-frequency input is the refinement if it ever
  chafes.
- **blink re-applies a provider's transform on resolve** (to the one item
  being documented) and **stamps its own fields on a provider's rows before
  the transform runs** (`source_id`, `source_name`, `cursor_column`,
  `score_offset`, `kind`). A transform must be idempotent, and a row a
  transform adds must carry the stamps or the accept path errors inside
  blink (found 2026-09-13). The provider's `score_offset` is *added* to each
  row's before the transform, so a per-row assignment is the whole offset.
- **The first request loads the closure.** 0.6 to 0.8 s once per session per
  document, nearly all LuaSnip snippet construction, and about 120 MB of
  heap; measured 2026-09-13 (section 9). Stage 4 measured it in the bench
  (section 3) and moved it into idle time: the next bullet but one.
- **blink asks LuaSnip on every keystroke.** Its luasnip preset's `active()`
  runs `ls.expandable()`, a scan of every registered trigger, on each
  `InsertCharPre` and `TextChangedI`; it scales with the rows a buffer
  reaches (3.5 ms per prose keystroke here) and it was what first called
  `ft_func`. Overridden in `completions.lua` (stage 4, 2026-09-13); a blink
  update adding another no-filter caller brings it back, and the `ft_func`
  pin says so.
- **Frecency never sees a snippet row.** An accepted LuaSnip row goes to the
  source's `execute`, not through blink's accept path, so `fuzzy.access` is
  never called for it (measured 2026-09-13); the `#*` sink is a static
  tie-break, and ranking from his corpus frequency (section 6) is the only
  route to usage-based order.
- **The pre-warm runs for every TeX buffer VimTeX initialises.** 0.7 s of
  CPU per session per closure whether or not the buffer is typed in;
  `:SnippetsReload` forgets it and the request path takes over; a package
  table that changes mid-warm is rebuilt at the next request.
- **The harness is not quite hermetic.** Each instance writes a
  `bibcomplete%tmp%…` file into the live `~/.cache/vimtex` (eight on
  2026-09-13) and its accepts feed the live frecency store; a scratch
  `cache_root` and `XDG_STATE_HOME` are the fixes (`TODO.md` at stage 5).

## 6. Deferred, to become TODO items at stage 5

- Key-value completion inside `[…]` (4,486 keys for 178 targets in the
  dissertation's closure): a small custom blink source fed by the sidecar,
  not snippets.
- Named placeholders for french-logic's own commands (99 of 100 bare): a
  comment convention in the `.sty` read by `snipgen.py --sty`. Math-only
  marking for them rides the same convention: a `\newcommand` carries no
  classification, so only the three `\DeclareMathSymbol` rows are
  math-wrapped (by construction, 2026-09-13).
- `\poscite`, a `\DeclareCiteCommand` whose arity (`[pre][post]{key}`, as
  `\textcite`) is biblatex's and not in the definition: the same comment
  convention could carry it; today it is not completed, as before stage 2.
- The stage-1 empty-file rule skips 77 cwl files that hold only `#keyvals`
  blocks (lmodern, fontenc, tikzlibrarypositioning among them); the
  key-value tier will want them, and the rule then needs a third case.
- Ranking from his corpus frequency as a generator input, replacing the
  `#*` prior.
- A bench sitting for the five stray colours (comparison 1.4): `&` and `\\`
  to the scaffold rung, math environment names into the env-name family,
  `#1` parameters, `texLength`.
- Autogenerating a bare list from the `.sty` or `.cls` for a package with
  no cwl, through kpsewhich, as TeXstudio does: the `.sty` front end already
  parses definitions with arity, so this is a lookup plus a run. Relevant to
  his own classes (mod-cv, eptcs, deon16) and to the old documents on
  bigfed.
- (Planned, not deferred: whenever a campaign chat first opens on bigfed,
  he clones the twin there first; the clone's untracked root `CLAUDE.md` is
  copied to it and mirrored, per that charter. The committed `pkg/` files
  never depend on it; regeneration and `--check` then work on either
  machine.)

## 7. Record trail, for his approval at stage 5

- `DECISIONS.md`: a dated section, "nvim/LaTeX: completion rebuilt on
  TeXstudio's model", with the verdicts of section 1 and the numbers of
  stage 4.
- `TODO.md`: items 8 and 15 to the Closed ledger with pointers here; new
  items from section 6.
- `nvim/CLAUDE.md`: the Completion section (sources, the two gates, the omni
  provider and its `\begin{` transform, the `snippets.active` override of
  stage 4), the Snippets section (generator,
  `pkg/`, loader, hand files, stamps), the cold-cache rule, the
  Regression suites list (`tests/snipgen`), the README's plugin tour. An
  interim paragraph on `pkg/`, the Formatter sentence and the suite bullet
  landed 2026-09-13 with his approval, and at the close of build chat 3 four
  interim passages (a head note on Completion, the Snippets paragraph for
  stage 3, the cold-cache sentence, the suite bullet); the rewrite stays
  here. `nvim/README.md` (the blink and LuaSnip bullets of the plugin tour)
  and `latex/french-logic/README.md` (the Snippets and Highlighting bullets
  under Tooling) named the retired generator and libraries; both rewritten
  at the close of build chat 3 with his approval, the charter's suite count
  corrected to 67 and its Layout bullet for `lua/snippets/` rewritten. At
  the close of build chat 4, with his approval, three more interim passages:
  the suite bullet at 71 with the four stage-4 pins, a stage-4 sentence
  under the Completion head note, and the cold-cache sentence corrected
  (13 s on the chapter, `\usepackage{` unprimed).
- `~/Desktop/CLAUDE.md`: `texstudio/` added to the read-only clones list
  (fedxps only as of 2026-09-12).
- `configs/CLAUDE.md`: `tests/snipgen` where the suites are named.
- `tests/nvim-latency/README.md`: the flipped and added checks, and why
  (landed at stage 3, 2026-09-13, with the three mutations).
- Memory: `latex-completion-redesign-2026-09` updated as stages land;
  `nvim-snippet-gradual-perfection` superseded when item 8 closes.
- Landed 2026-09-13, build chat 5, each with his approval: the `DECISIONS.md`
  section; `TODO.md` (8 and 15 to the Closed ledger, 16 to 21 opened); the
  charter's head sentence and its Completion, cold-cache and Snippets sections
  rewritten whole, the retired names gone; `configs/CLAUDE.md`'s
  `tests/snipgen` line; the two memory notes and their index lines. The
  Regression-suites list and the two READMEs needed nothing. Found by the sweep
  and fixed the same day: `~/Desktop/CLAUDE.md`, `latex/CLAUDE.md`,
  `nvim/docs/latex-register-taxonomy.md`; deferred to his next french-logic
  session: the `french-logic-cite.sty` comment. At the close, the latency
  README's cold-cache section and `bin/vimtex-warm`'s header comment were
  corrected for where the stall is paid now (both still said the first
  backslash) and for the TeX Live claim (an upgrade does not empty the cache).

## 8. Open at build time, small

- Closed at stage 4 (2026-09-13, section 1, stage-4 smalls): the sink (5),
  the description width (45; the knob is
  `completion.menu.draw.components.label_description.width.max`, measured
  over the corpus 1,785 of 8,110 environment and 11,527 of 198,293 command
  descriptions over 30, on the chapter's closure 9.9% of rows over 30 and
  2.3% over 45, the `∗` being the last character and the first thing a cut
  removes), the first-request load (the idle pre-warm), the per-keystroke
  `snippets.active` check.
- Closed at stage 5 (2026-09-13): the `∗`-first marker and the harness's
  hygiene are `TODO.md` items 18 and 20; the two looks of the `\begin{` list,
  `in_env`'s innermost-only reading, the missing-includes line and
  `\usepackage{`'s 0.9 s are recorded as left in `DECISIONS.md`.
- `snipgen.py --sty` accepts several files (`nargs="+"`) though this plan and
  the charter describe one argument, the hub; the startup check and the suite
  pass one, and nothing depends on the difference. Seen in build chat 5; left.
- `∗` before the shape rather than after it, so that a cut never removes
  the marker: a generator change and a full regeneration; his call, to
  `TODO.md` at stage 5.
- The harness's hygiene (a scratch `cache_root` and `XDG_STATE_HOME` by
  default; section 5), to `TODO.md` at stage 5.
- Section 9's balanced-mode before figures (146 and 92 ms) are unreproduced
  against the same tree's 53 and 19 in performance mode; both trees can be
  re-measured in balanced mode with `spikes/stage4_keys.py` if he switches
  the profile.
- At `\begin{` the list has two looks: VimTeX's names carry the field icon
  and a dim `[env: <package>]` tag, the loaded files' names the snippet icon,
  `~` and `[env: snippets]`; seen 2026-09-13, nothing reported wrong, left.
- `\usepackage{` costs 0.9 s once per session on the chapter and
  `vimtex-warm` cannot prime it (section 3); the charter's cold-cache
  sentence at stage 5 says so.
- `in_env` reads the innermost environment only (`vimtex#env#get_inner()`),
  so a restricted row inside a nested environment (a `\TextField` in a
  `tabular` inside `Form`) is hidden; `vimtex#env#get_all()` is the switch if
  it ever chafes (six rows in his packages).
- `:SnippetsReport` names every include with no generated file, 24 to 33 on
  his documents, most of them keyvals-only or expl3 files the generator
  skips by rule (section 6); a "skipped by rule" line would need the
  generator to emit its skip list.
- Closed at stage 3 (2026-09-13): the `from_lua` lazy loader and its
  filetype registration of `pkg/`, `sty/`, `helpers`, `loader`; the
  `require("snippets.helpers")` the generated files carry; the startup
  check's flip to per-file stamps; the `pkg/` then `sty/` lookup and the
  core-first order; the interim charter text (four passages of `nvim/CLAUDE.md`
  applied with his approval at the close of build chat 3).

## 9. Spike results, 2026-09-13

All in the latency harness on its throwaway fixture copy, or headless and
read-only on `completeness.tex`, with everything injected at runtime.

- A runtime `ft_func` plus `ls.add_snippets("pkg-x")` puts the package's rows
  in blink's menu in a TeX buffer and leaves a Lua buffer's filetypes at
  `{lua, all}`.
- A snippet's `show_condition` returning false removes its row; a per-item
  `score_offset` sinks a row; the transform's dedupe collapsed two identical
  rows; the description column rendered from `dscr` under blink's default
  layout `{ {kind_icon}, {label, label_description} }`; the transform cost
  0.19 ms for 200 rows.
- Tilde-less triggers: `\spikeone` accepted after full and after partial
  typing gave `\spikeone{a}{b}` both times.
- Math wrap: `$\alpha$` in prose, `\alpha` after `$x `.
- `\begin{`: omni rows rewritten into snippet-format edits gave
  `\begin{enumerate}` / `  ` / `\end{enumerate}`. A `regTrig` environment
  snippet inserted its pattern text; a pre-expand callback that edited the
  buffer scrambled the line.
- `vim.b.vimtex.packages` costs 0.09 ms per read; `in_mathzone()` 0.05 ms.
- Keyed re-registration marks the old rows invalidated and `get_snippets`
  keeps listing them until `clean_invalidated({ inv_limit = 0 })`.
- In the dissertation's closure, 117 of 8,716 distinct rows appear in two or
  more files, 74 of them in a core file; six typical rows carry an
  environment restriction; his biblatex options select no option block.
- `vimtex-warm` writes `pkgcomplete.json` as well as the kpsewhich cache.
- Math-only commands in prose: none. 73 commands sampled up to three times
  per file across 41 files: 1,023 occurrences in math, 0 in text (100
  apparent text hits were commented-out code).
- Keystroke cost at scale, measured 2026-09-13 in the bench's method (one
  character, synchronous redraw, 0.4 s gaps) at the end of the fixture's
  2,079-character line, fedxps in balanced mode: with today's 1,054 snippets,
  a keystroke inside a command name costs a median 146 ms (p90 190) and a
  prose keystroke 92 ms; with 8,000 synthetic rows injected (9,054 in all)
  the command-name median is 160 ms (p90 192) and prose 94 ms. blink calls
  the source once per command word (6 requests for 35 keystrokes) and
  refilters locally after that; the source's per-request copy rose from 5 to
  20 ms, the Rust fuzzy pass from about 2 to about 8 ms per keystroke. The
  planned transform costs 7.2 ms cold and 2.5 ms warm at 9,054 rows; blink's
  own per-request shallow copy 4.8 ms. The gate keeps prose at zero snippet
  requests in both states. Stage 4 re-measures on both machines against
  these figures.
- Weight: `completion/` is 24 MB and 493,816 lines over 4,524 files; the
  largest sources are expl3-commands (347 KB, excluded), biblatex (276 KB,
  9,896 lines), biblatex-ms (198 KB); the existing generated files run 69
  bytes per bare snippet and about 190 per named one; the configs pack is
  4.35 MiB today. `gpushall`'s vet prompts only above `GSYNC_MAX_MB` (25)
  or on a secret glob.
- Build chat 1, 2026-09-13, measured while reading and building: the clone's
  `completion/` differs from the installed 4.9.7 tag in 100 files (tikz +22
  lines, biblatex 3, latex-document 2; amsmath and class-memoir identical);
  `cwlAliases.dat` has 401 entries, six not derivable from the class name,
  none his; 444 cwl files yield no visible row outside option blocks and
  344 of those carry `#include` lines (kept, for the loader's closure);
  `#keyvals` blocks: 2,900 files, 109,547 lines, 1.9 MB raw; 3,968 of 4,524
  files are CRLF; TeXstudio's `hideFromCompletion` covers `B` rows as well
  as `S`; TeXstudio adds bracket placeholders only to rows without any `%`
  and strips `%[A-Za-z]+` first; blink's keyword is `\k*` under an
  iskeyword of letters, digits, `_`, `-` and Latin-1, so neither `\` nor
  `*` is a keyword character; blink labels a LuaSnip item by its trigger
  and its `label_description` column defaults to 30; stylua's ignore in
  `nvim/` does not reach `tests/`, so the suite carries its own; a golden
  `.lua` under `tests/` is reflowed by an in-editor save without it.

- Build chat 3, 2026-09-13, measured while reading and building: VimTeX's
  env completer on the fixture (no `.fls`) offers 65 names and none of
  french-logic's 25, on the root (`.fls` of 2026-08-09, 103 packages, no
  unit) 179 and none of the 25, on the completeness chapter (main the article
  wrapper, `.fls` of 2026-09-12, 111 packages with the 14 units) 171 and all
  25; `align` absent on the fixture; 16 to 20 ms per call on the dissertation
  warm, 280 ms cold. The fixture's closure: 100 files, 7,756 rows, 293
  environment rows over 212 names, 13 list environments; VimTeX's data knows
  125 of the 212. Loading that closure into LuaSnip: the includes walk 12 ms,
  `loadfile` of the 100 files 29 ms, execution plus `add_snippets` 598 ms,
  `ls.snippet()` 68 µs a row; heap 23 MB before, 165 after, 141 after a full
  collect. The root's closure: 110 files, 1.4 MB, 9,330 rows, 0.7 s. The
  dissertation's own definitions: six commands in the main file, three of
  them after `\begin{document}`; `readfile` of the main file 0.06 ms (142
  lines), VimTeX's whole-project parse 11.6 ms (2,461 lines; 3.7 ms on the
  article's 800), the project mtime 0.08 ms. blink: a provider's transform
  runs on every response including an empty one, and again on resolve; the
  provider's `score_offset` is added to each row before the transform; rows
  are stamped with `source_id`, `source_name`, `cursor_column`, `kind`. On
  the harness the first `\cnec` request after opening the fixture took 4.55 s
  wall for five keystrokes at 0.3 s and a 2 s settle, so about 1 s beyond the
  typing, blink's first build of the 7,756 items included (inferred, not
  timed apart). `:SnippetsReload` re-reads the fixture's 100 files in 0.77 s
  with every count unchanged; a hand-local row with a generated row's label
  and description is the one row shown and the one that expands (both
  pinned). The four probes are kept in `spikes/` (`envprobe.lua`,
  `loadprobe.lua`, `report.lua`, `spike5.py`).

- Build chat 4, 2026-09-13, measured while reading and building (the stage-4
  numbers themselves are in section 3): spike4's `silent! undo` never
  reverted the typed text, so its phase B ran on a line 47 characters longer
  than phase A (both trees alike in the stage-4 bench, which restores the
  line explicitly); `ls.expandable()` costs 1.14 ms per call at the end of
  the longest fixture line with the closure registered, and blink's preset
  called it twice per keystroke (52 calls for 25 prose keystrokes); blink
  reads a provider's `transform_items` from its own provider object, copied
  at creation, so a runtime hook must wrap
  `get_provider_by_id(id).config.transform_items`; blink's frecency store is
  `stdpath('state')/blink/cmp/frecency.dat` (12 KB live, written by omni and
  LSP accepts, never by a LuaSnip row); a VimTeX row carries no blink kind,
  so it draws the Field icon, and its `[env: …]`/`[bib]` kind text lands in
  `labelDetails.detail`, appended to the label; the fixture's package table
  holds one package (french-logic), the 100 files come from the includes
  walk; entering insert mode costs about 107 ms the first time in a session
  in both trees (not the campaign's); the pre-campaign tree kept its 27 MB
  of heap from `FileType` on. The probes are in `spikes/` with README rows.

## 10. Chat log

- 2026-09-12, fedxps: planning chat 1. The comparison, the four questions,
  the first draft of this plan.
- 2026-09-13, fedxps: planning chat 2 (the same session, continued). The
  spikes of section 9, whole-corpus conversion and the commit decision, the
  math-only sweep, `next-chat.md` written. No configuration touched.
- 2026-09-13, fedxps: build chat 1, from `next-chat.md`. Stage 1 landed: the
  eight smalls asked in one round with measurements, `snipgen.py`'s cwl
  mode, `tests/snipgen` (suite first, golden by hand, one recorded
  mutation), `pkg/` generated from the clone at `0362907c2`, `pkg/NOTICE`
  and `pkg/COPYING`, the two stylua ignores. Three refinements found by the
  suite and the spot checks are in section 2 (marker-row bracket chain,
  core lists inform every file, typical row beats its unusual twin). No
  configuration touched; an interim note in `nvim/CLAUDE.md` with his
  approval. Successor: `next-chat-2026-09-13.md`.
- 2026-09-13, fedxps: build chat 2, from `next-chat-2026-09-13.md`. Stage 2
  landed: the four smalls asked in one round with measurements (directory,
  optional-argument rows, core dedupe, `\DeclareMathSymbol`), the rest
  applied as objective; `snipgen.py --sty` and `--coverage`; `tests/snipgen`
  extended by a `.sty` fixture, two hand-written goldens and eight checks,
  one mutation recorded; `sty/` generated (15 files, 544 rows, 540 names).
  No configuration touched but `nvim/.styluaignore`; the old startup check
  and `french-logic.lua` left live; three passages of `nvim/CLAUDE.md`
  updated with his approval at the close (`sty/` in the interim paragraph
  and the Formatter sentence, 22 checks in the suite bullet), and
  `tests/stylua.toml` added so test files stop reflowing on an in-editor
  save. Successor: `next-chat-2026-09-13b.md`.
- 2026-09-13, fedxps: build chat 3, from `next-chat-2026-09-13b.md`. Stage 3
  landed: the two smalls asked in one round with their measurements (the
  `\begin{` union, the whole main file on mtime change), the rest applied as
  objective; `helpers.lua`, `loader.lua`, the hand files, the thin
  `snippets.lua` with the per-file stamp check, `completions.lua` with the two
  gates, the omni provider and the two transforms; the three old files
  retired; the latency suite at 65 checks with three mutations recorded;
  `:SnippetsReport` on the chapter and the root. The first-request load cost
  measured and left to stage 4; the description width left for a live look.
  Successor: `next-chat-2026-09-13c.md`.
- 2026-09-13, fedxps: build chat 4, from `next-chat-2026-09-13c.md`. The
  live look (nothing wrong; the math awareness the surprise). Stage 4
  landed: the measurements of section 3 on both trees under one machine
  state; the `snippets.active` fix applied as objective with two pins and a
  mutation; the round (sink 5, idle pre-warm, width 45) asked with the
  measurements and built, with two more pins and a mutation; the suite at
  71; the probes in `spikes/` with README rows; PLAN.md sections 1, 2, 3,
  5, 8, 9; three interim passages of `nvim/CLAUDE.md` with his approval at
  the close. Successor: `next-chat-2026-09-13d.md`.
- 2026-09-13, fedxps: build chat 5, from `next-chat-2026-09-13d.md`. Stage 5
  landed and the campaign closed: the baseline verified (section 3), the
  records drafted and approved in order (the `DECISIONS.md` section, `TODO.md`,
  the charter round with the configs line and three one-line fixes), the memory
  notes rewritten, this plan annotated closed. No code touched; at the close a
  stale header comment in `bin/vimtex-warm` and the latency README's cold-cache
  section were corrected. Successor: `next-chat-2026-09-13e.md`, whose queue is
  the bigfed twin with the suites and the stage-4 measurements there, the
  `.sty` comment at his next french-logic session, and the optional
  balanced-mode re-measure.
- next: the first chat on bigfed, from `next-chat-2026-09-13e.md`.
