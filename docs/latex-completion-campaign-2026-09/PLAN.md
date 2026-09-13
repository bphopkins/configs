# LaTeX completion campaign: TeXstudio's model in Neovim — PLAN

Live campaign plan, opened 2026-09-12 on fedxps, revised 2026-09-13 after
the spikes (section 9). Edit in place while the campaign runs; when it
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

- **Source: the cwl corpus, in its entirety.** Only `#S` (hidden) rows are
  dropped. The LaTeX Workshop file was a lossy copy of a tenth of the data
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
  autogeneration). Needed whenever there is no fresh `.fls` (2.1).
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
  `enumerate` at `\begin{enum` wrote the three lines exactly). List-like
  environments get `\item` in the body, known from the generated data and
  french-logic's list environments. This is what TeXstudio does: in its
  environment mode the row is truncated to `\begin{name}` and `expandCode`
  adds content and `\end`. Two alternatives were tried and are declined: a
  `regTrig` environment snippet (blink inserted the pattern text) and a
  pre-expand callback editing the buffer (blink fixes the clear region
  before LuaSnip's callback runs).
- **Document-local commands complete with arity.** The loader runs the
  `.sty` parser over the main file's preamble (VimTeX's parser gives the
  lines) and registers them under a per-document pseudo-filetype, refreshed
  on compile success. TeXstudio's "user commands"; his dissertation defines
  twelve (2.6). Small; dropped if it grows.
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
- **Excluded from generation:** expl3-commands (expl syntax only), fontenc
  and inputenc (nothing outside option blocks), and any package whose output
  would be empty.
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

## 2. The target shape

Under `nvim/lua/snippets/` unless said otherwise.

| path | role |
|---|---|
| `snipgen.py` | the one generator, replacing `sty-lua-snippets.py`: `--all` (the clone's whole `completion/`), `--cwl` (named files, for spot checks), `--sty` (hub first, then units), `--check`, `--coverage` (kept as is), `--out-dir`; an options table for `#ifOption` blocks, empty by default |
| `pkg/<name>.lua` | generated, never hand-edited, committed; header names the cwl source, its sha256, the clone's commit and the generator version; `return { package=…, includes={…}, lists={…}, snippets={…} }` |
| `pkg/NOTICE` | attribution and licence note for the derived data, drafted at stage 1 for his approval |
| `hand/bibtex.lua`, `hand/local.lua` | hand-kept; `local` is his, initially empty |
| `helpers.lua` | `mathwrap(nodes)`, `in_env({…})` with a per-request memo, `docsnippets(lines)` for the preamble |
| `loader.lua` | registration on demand, `ft_func`, `:SnippetsReport`, `:SnippetsReload` |
| `lua/plugins/snippets.lua` | becomes thin: `ls.setup{ ft_func }`, `loader.setup()`, the startup sha check for the french-logic files |
| `lua/plugins/completions.lua` | the two gates, the `omni` provider in the TeX source list, `use_label_description`, the two `transform_items` |
| `tests/snipgen/` | the generator's suite: fixture cwl and `.sty`, golden Lua, `--check` idempotence, a recorded mutation |

**Generation rules, cwl line to snippet.** Skip `S`; skip `#keyvals` blocks
(the data is parsed and kept in a sidecar for the deferred tier); skip
`#ifOption` blocks unless the generator's options table enables the option; `#include:` to
the header; comments, `#repl`, unknown directives and unknown classification
letters tolerated with one warning (the format grows by a specifier a year).
`\end{…}` lines skipped; `\begin{env}…` lines become environment snippets:
`\begin{env}` plus its arguments, a body line (`\t${n}`, or `\t\item ${n}`
when the cwl line ends in `\item`), `\end{env}`; the file's `lists` table
names the environments whose body is `\item`. Argument groups `{name}`,
`[name]`, `(a,b)`, `<x>` become placeholders named by the cwl; `%<x%>` a
placeholder `x`; `%|` the final cursor; `%\` a newline; `%suffix` markers
(`%text`, `%l`, `%plain`, `%keyvals`, `%:translatable`, …) stripped from the
displayed name. Trigger `\name` (starred forms keep the star). `dscr` is the
line minus its leading `\name`, plus ` ∗` when `#*`. `priority` 1000, or
900 when `#*`. `m` wraps the nodes in `mathwrap`; `/env1,env2` sets
`show_condition = in_env{…}`. Every other classification (`\env` alias,
`L0`–`L5`, `r c l d u i g b U K D B s V N`) is stored as a `cls` string on
the snippet for later use, no behaviour now. Identical (trigger, dscr) pairs
are deduplicated within a file, and against the core three for every other
file.

**Coverage.** Every file in the clone's `completion/` (4,524 on
2026-09-12), one Lua file each, minus expl3-commands and minus any file
that yields no row (fontenc and inputenc among them). The loader treats an
`includes` entry with no generated file as missing, silently, and
`:SnippetsReport` names it. Packages with no cwl at all (his own classes
mod-cv, eptcs, deon16; old files on bigfed) get nothing until the deferred
autogeneration item (section 6).

**Loader behaviour.** The filetype function is the loader. For a TeX-like
buffer it reads `vim.b.vimtex.packages` (0.09 ms, measured; no cache
needed) and the document class, adds the core three, closes over the
`includes` headers, registers on demand any package whose `pkg/` file is not
yet registered (`ls.add_snippets("pkg-<name>", …, { key = "pkg-<name>" })`),
and returns `{"tex", "hand-local", "doc-<id>"}` plus the package
pseudo-filetypes. Bib buffers get `{"bib", "hand-bibtex"}`; everything else
LuaSnip's default. Because registration happens on the request path, no
VimTeX event hook is needed: a package table refreshed by a compile is seen
at the next request. `:SnippetsReport` prints loaded, missing and
deduplicated counts for the buffer; `:SnippetsReload` re-adds every
registered package under its key and then calls
`clean_invalidated({ inv_limit = 0 })` (spike: without the clean, the old
rows stay listed as invalidated).

**Gates and providers.** `in_command_context` is the present gate's first
branch only (`\name` being typed); the snippets provider is enabled there
alone. `in_brace_context` is the present brace branch (300-character window);
the `omni` provider is enabled there alone, so VimTeX's command completer
never fires. The path provider is unchanged. On the snippets provider,
`use_label_description = true` and a `transform_items` that (1) subtracts the
sink constant from the offset of rows whose snippet priority is below 1000,
via a table memoised per snippet id, and (2) drops repeated (label,
description) pairs. On the omni provider, a `transform_items` that (1)
removes duplicate labels (VimTeX returns `amsmath` twice from two trees) and
(2) inside `\begin{…` rewrites each row into a snippet-format text edit,
`name}` + newline + body + newline + `\end{name}`, extending the edit over
an auto-paired `}`, with `\item` in the body for list environments.

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

**Stage 2 — the `.sty` front end folded in.** The existing generator's
parsing moves into `snipgen.py --sty`, emitting one file per unit plus the
hub file whose `includes` carries the units and the requires closure and
whose `lists` names french-logic's list environments; `--coverage`
unchanged; the startup sha check re-pointed at the new files. Accept when
the french-logic files regenerate from the hub and units with `--check`
green and the 537 commands and environments are all present, now without
`~`.

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

**Stage 4 — measure, then tune.** `bench.py` per keystroke inside a
`\command` context and in prose, before and after, on both machines; the
two transforms' cost at the full row count (spike: 0.19 ms per 200 rows
before memoisation); the sink constant against frecency (accept one `∗` row
three times and observe its rank); the first-use cost of `\begin{` and
`\usepackage{` on a cold package cache (`vimtex-warm` primes
`pkgcomplete.json` already; confirm it suffices); memory and startup time.
Write the numbers here; tune the one constant.

**Stage 5 — records, then close.** Section 7. On bigfed: `gpullall`, both
suites, `:SnippetsReport` on a chapter. Annotate this file closed.

## 4. How the work is done

Both Neovim suites after every stage; the syntax suite is not expected to
move but is run. Nothing is hand-edited under `pkg/`; a wanted divergence
goes into the generator's overrides table (TODO item 8's missing
mechanism). The clone is pulled `--ff-only` before a regeneration and its
HEAD stamped into every file; `--check` is the drift test and runs only
where the clone exists. Generation is light. The benches run on both
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
  clone; it regenerates only the french-logic files, as today.
- **The first push.** About 4,400 new files appear at once; `gpushall` lists
  first-time-committed files in its output and prompts only above 25 MB or
  on a secret glob, so expect one long listing and no questions. Confirm the
  largest generated file against `GSYNC_MAX_MB` before that push.
- **Includes of files that do not exist.** latex-dev includes
  expl3-commands, which is excluded; the loader must skip a missing include
  without noise and report it only in `:SnippetsReport`.
- **TeXstudio's `#*` is a prior, not his usage.** Hence the small offset and
  the kept flag; a corpus-frequency input is the refinement if it ever
  chafes.

## 6. Deferred, to become TODO items at stage 5

- Key-value completion inside `[…]` (4,486 keys for 178 targets in the
  dissertation's closure): a small custom blink source fed by the sidecar,
  not snippets.
- Named placeholders for french-logic's own commands (99 of 100 bare): a
  comment convention in the `.sty` read by `snipgen.py --sty`.
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
  provider and its `\begin{` transform), the Snippets section (generator,
  `pkg/`, loader, hand files, stamps), the cold-cache rule, the
  Regression suites list (`tests/snipgen`), the README's plugin tour.
- `~/Desktop/CLAUDE.md`: `texstudio/` added to the read-only clones list
  (fedxps only as of 2026-09-12).
- `configs/CLAUDE.md`: `tests/snipgen` where the suites are named.
- `tests/nvim-latency/README.md`: the flipped and added checks, and why.
- Memory: `latex-completion-redesign-2026-09` updated as stages land;
  `nvim-snippet-gradual-perfection` superseded when item 8 closes.

## 8. Open at build time, small

- The description text of an environment row (`\begin…\end` plus its
  arguments, or the arguments alone).
- Whether `\begin{itemize}` and `\begin{itemize}\item` both become rows or
  only the `\item` form.
- `(x,y)` picture coordinates: placeholders or literal text.
- The sink constant (stage 4 decides).

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
- Weight: `completion/` is 24 MB and 493,816 lines over 4,524 files; the
  largest sources are expl3-commands (347 KB, excluded), biblatex (276 KB,
  9,896 lines), biblatex-ms (198 KB); the existing generated files run 69
  bytes per bare snippet and about 190 per named one; the configs pack is
  4.35 MiB today. `gpushall`'s vet prompts only above `GSYNC_MAX_MB` (25)
  or on a secret glob.

## 10. Chat log

- 2026-09-12, fedxps: planning chat 1. The comparison, the four questions,
  the first draft of this plan.
- 2026-09-13, fedxps: planning chat 2 (the same session, continued). The
  spikes of section 9, whole-corpus conversion and the commit decision, the
  math-only sweep, `next-chat.md` written. No configuration touched.
- next: build chat 1, stage 1, from `next-chat.md`.
