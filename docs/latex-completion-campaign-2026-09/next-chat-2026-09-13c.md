Annotation, 2026-09-13: build chat 4 opened from this brief and landed stage 4; its successor is `next-chat-2026-09-13d.md` beside this file. Sections 1, 6 and 8 of `next-chat.md`, section 5 of `next-chat-2026-09-13.md` and section 5 of `next-chat-2026-09-13b.md` still bind.

Prompt — the opening brief for the fourth build chat of the LaTeX completion
campaign. Dated record, written 2026-09-13 at the close of build chat 3, on
fedxps (the letter: three chats closed on one date). The next chat writes its
own successor beside this file at its close (`next-chat-YYYY-MM-DD.md`),
adds one annotation line at the head of this one, and otherwise leaves it
as it is. Its predecessors stay as written; sections 1 (how the work is
done), 6 (pitfalls) and 8 (where to look) of `next-chat.md`, section 5 of
`next-chat-2026-09-13.md` and section 5 of `next-chat-2026-09-13b.md` still
bind and are not repeated here.

# Read this whole file, then PLAN.md, before touching anything

You are opening the fourth build chat of the campaign that rebuilds the
LaTeX completion layer of `configs/nvim` on TeXstudio's model. Stages 1, 2
and 3 have landed; the menu he types into is now the new layer. This chat
does stage 4, measure then tune, and may open stage 5. The aim, the
decisions, the rules as built, the stages and the record trail are in
`PLAN.md` beside this file (section 0 says what "done" means); the evidence
is `comparison-2026-09-12.md` and section 9 of the plan. Read `next-chat.md`
sections 1, 6 and 8 as instructions.

## 0. The queue, and what closes each item

1. **The live look he has not yet had.** Stage 3 landed headless and on the
   harness; he has not typed into the new menu. Before measuring, ask him
   to open a chapter and try `\name`, `\cite{`, `\begin{`, a math-only row
   in prose, and to say what he sees; the description column's width
   (blink's default 30 truncates 233 biblatex descriptions) is decided then,
   with the knob named in `PLAN.md` section 8. Anything he reports as wrong
   is a stage-3 defect and is fixed first, with a check.
2. **Stage 4, measure, then tune.** Closes by `PLAN.md` section 3, stage 4:
   `bench.py` per keystroke inside a `\command` context and in prose, on
   both machines, against the before figures of section 9 (fedxps balanced,
   fixture's longest line: 146 ms median inside a command name, 92 in
   prose, with the old 1,054 snippets); the two transforms' cost at the
   full row count; the sink constant against frecency (accept one `∗` row
   three times and observe its rank); the first-use cost of `\begin{` and
   `\usepackage{` on a cold package cache; memory and startup time; and the
   first-request load of a closure, measured at stage 3 headless (0.65 s on
   the chapter, 0.76 s on the root, about 120 MB of heap) and to be
   measured now in the bench, with a decision on an idle pre-warm after
   `User VimtexEventInitPost` (a hook the loader does not need for
   correctness; section 8). The numbers go into `PLAN.md` section 3 and the
   sink constant is set in `completions.lua`.
3. **Stage 5, records, then close.** Closes when the record trail of
   `PLAN.md` section 7 is landed with his approval and the plan is
   annotated closed. Section 7 lists the documents. The two READMEs were
   rewritten at the close of build chat 3 with his approval; what stage 5
   owes the charter is the full rewrite of the Completion and Snippets
   sections, whose prose below the interim notes is still the pre-stage-3
   record and still names the retired files as history.
4. **The bigfed twin.** Folded into whichever stage first opens on bigfed:
   clone `~/Desktop/texstudio` there, copy the clone's untracked root
   `CLAUDE.md` to it, `git pull --ff-only`, record both HEADs, check that
   bigfed's `~/Desktop/CLAUDE.md` carries the `texstudio/` line. The
   committed `pkg/` and `sty/` files never need the clone; `--all --check`
   and cwl regeneration do; `--sty` never does. On bigfed the startup check
   regenerates nothing unless a `.sty` differs, and both suites run as here.

Anything not needed for these goes to `TODO.md` as its own item at stage 5
(`PLAN.md` section 6), never into this queue.

## 1. What stage 3 landed (all uncommitted when this was written)

- `nvim/lua/snippets/helpers.lua`: `mathwrap`, `in_env` (innermost
  environment, memoised per request), `docsnippets(lines, lists)` (the
  `.sty` rules in Lua, for the document's own definitions).
- `nvim/lua/snippets/loader.lua`: registration on demand by `dofile` path
  (`pkg/` then `sty/`), the closure walk memoised per buffer on the sorted
  package table plus the class, the document parse on mtime change,
  `ft_func`, `envs(bufnr)` for the `\begin{` transform, `:SnippetsReport`,
  `:SnippetsReload`. Filetype order: `tex`, `hand-local`, `doc-<id>`, the
  core three, the class, the closure.
- `nvim/lua/snippets/hand/bibtex.lua` (the 32 entry templates, no `~`) and
  `hand/local.lua` (empty, his).
- `nvim/lua/plugins/snippets.lua`: thin; the startup check compares the 15
  per-file `sty-sha256` stamps and regenerates with `snipgen.py --sty`.
- `nvim/lua/plugins/completions.lua`: the two gates (omni excludes a nested
  command name), the omni provider in the three TeX source lists,
  `use_label_description`, the snippets transform (sink 5 interim, dedupe),
  the omni transform (label dedupe, the `\begin{` template over the union of
  VimTeX's names and the loaded files', with blink's stamps on appended
  rows).
- Retired: `french-logic.lua`, `latex-workshop.lua`, `sty-lua-snippets.py`,
  the blob stamp, the two stylua ignore lines.
- `tests/nvim-latency/`: `verify.py` at 67 checks (two flipped, the window
  pins moved to the omni gate, 27 added), `fixture.tex` with
  `\addbibresource{fixture.bib}` and `\newcommand{\fixturecmd}[2]{#1#2}` in
  its preamble, `fixture.bib`, `harness.py` copying it, the README with the
  three mutations of 2026-09-13.
- `PLAN.md`: section 1 (the stage-3 smalls; two bullets amended), 2 (as
  built), 3 (stage 3 landed), 5 (two hazards), 7 (the records landed and the
  two READMEs), 8 (rewritten), 9 (build chat 3 measurements), 10. Four probes
  in `spikes/` with README rows. This brief; the annotation on its
  predecessor; the campaign memory note, and one-line addenda on the four
  memories that named the retired layer (`nvim-snippet-gradual-perfection`,
  `nvim-snippet-trigger-tilde-was-a-mistake`, `fedxps-vimtex-cold-cache-stall`,
  `vimtex-harvest-empty-after-split`).
- With his approval at the close, four interim passages of `nvim/CLAUDE.md`:
  a head note on Completion, the Snippets interim paragraph rewritten for
  stage 3, a sentence on the cold-cache rule (VimTeX's completers are back
  inside braces), and the latency suite bullet at 65 checks. The Completion
  and Snippets prose below those notes is still the pre-stage-3 record,
  rewritten at stage 5. Also with his approval: the blink and LuaSnip
  bullets of `nvim/README.md` and the Snippets bullet and coverage sentence
  of `latex/french-logic/README.md`.

## 2. The state of the trees you inherit

- `git status` in `configs`, at the close of this chat, showed everything
  the earlier chats left plus this chat's paths (section 1) and the three
  deletions; in `org`, the campaign's memory files and changes of his own
  (`CLAUDE.md`, `licensing/`, a `licensing-has-a-home` memory) that are not
  the campaign's. He may have committed all of it by the time you read this.
  Never sweep, revert or "clean up" what you did not make; when you report
  the tree, say which changes are yours.
- The clone `~/Desktop/texstudio` was at `0362907c2` (2026-09-12), already
  up to date on 2026-09-13.
- Plugin commits unchanged since the spikes: blink.cmp `78336bc`, LuaSnip
  `0abc8f3`, vimtex `45a5a56`, live and in the lockfile. LazyVim `99970099`.
- stylua `--check` from the repo root flags the same two files as before,
  `nvim/lua/plugins/colorscheme.lua` and `tests/nvim-latency/stallwatch.lua`;
  leave both to him.

## 3. Verify before you build

In this order, and record the results in your successor:

1. `tests/nvim-syntax/run.sh` (56), `tests/nvim-latency/run.sh` (67, about
   90 s), `tests/snipgen/run.sh` (22). Any red: stop and tell him.
2. `git -C ~/Desktop/texstudio pull --ff-only`; record the HEAD. If it
   moved, `python3 nvim/lua/snippets/snipgen.py --all --check` from the
   `configs` root reports the drift; regenerate with `--all` and rerun the
   snipgen suite; if it did not move, `--all --check` must report 0 stale,
   0 missing, 0 extra.
3. `python3 nvim/lua/snippets/snipgen.py --sty latex/french-logic/french-logic.sty --check`
   must report 15 files, 0 stale, 0 missing, 0 extra. (The old generator
   and its check are gone.) If he edited the package, the startup check
   has already regenerated `sty/` on his next Neovim start; `--check` then
   reports 0 stale and `git status` shows the changed `sty/` files, his to
   commit.
4. The three plugin commits against section 2; if one moved, the affected
   spikes of `comparison-2026-09-12.md` section 6 and the latency suite are
   re-run before trusting the plan.
5. `:SnippetsReport` headless on `completeness.tex` (one instance,
   `NVIM_NOSESSION=1`, `+'lua vim.wait(20000, function() return vim.b.vimtex
   ~= nil end, 100) print(vim.fn.execute("SnippetsReport"))'`) must list
   about 104 files and no message in `:messages`.
6. Read `PLAN.md` section 8 and add anything your reading turns up.

## 4. Stage 4: where to start

Read `PLAN.md` section 3 (stage 4), section 9 (both measurement lists), the
latency suite's README (the bench method and the 2026-09-12 power-mode
note: measure in balanced or performance mode, never power-saver), and
`tests/nvim-latency/bench.py`. The before figures are in section 9 (spike
4, 2026-09-13). Measure first, in this order, and write each number into
`PLAN.md` section 3 as you go: per-keystroke cost inside a command name and
in prose on the fixture's longest line (bench method); the transforms'
cost at the full row count (probe8's method on the live layer); the
first-request load in the bench (open the fixture, type the first
backslash, time to the menu; `spikes/loadprobe.lua` and `report.lua` give
the headless figures, `envprobe.lua` what VimTeX offers at `\begin{`);
memory after a full collect; startup time.
Then the sink: accept `\AmSfont` (a `∗` row) three times from `\AmS` and
observe its rank against `\AmS`; set the constant with him. Then decide the
pre-warm with him, with the numbers: an idle registration of the closure in
chunks after `User VimtexEventInitPost` removes the first-request stall at
the cost of one autocmd and the same memory. Then bigfed: the same
measurements there, on the twin.

Clean stopping points if the chat runs long: after the live look and any
defect it found; after the measurements are in `PLAN.md` and before the
tuning; say which one you reached.

## 5. Pitfalls met in build chat 3, so you do not

- blink re-applies a provider's `transform_items` to the one item it
  resolves for the documentation window; a transform that is not idempotent
  double-applies. The provider's `score_offset` is added to every row before
  the transform, so assigning a per-row offset assigns the whole offset.
- blink stamps `source_id`, `source_name`, `cursor_column`, `score_offset`
  and `kind` on a provider's rows before the transform; a row a transform
  appends must carry them or accepting it errors in `text_edits.lua`.
- LuaSnip's `get_snippet_filetypes` inserts `"all"` into the table `ft_func`
  returns; return a fresh copy each time.
- `ls.add_snippets` under a key fires `LuasnipSnippetsAdded`, which resets
  blink's luasnip item cache; registering inside `ft_func` is fine because
  the cache is rebuilt after `ft_func` returns.
- A harness check that indexes an accept's result lines raises, and aborts
  the run, when no row was accepted; pad the result so a mutation reaches
  its full failure set.
- `reset_tail(scratch)` overwrites the fixture's last line, which is
  `\end{document}`; the checks type after the document's end, and a check
  that inserts a preamble line shifts every line below it, so recompute
  `line('$')` after it.
- VimTeX's env completer offers nothing for a package it knows only from a
  scan of the hub `.sty`; its `s:load_from_document` reads
  `\newenvironment` lines of the project, not `\begin` usages.
- `stow-all-dry` with nothing to do prints only its package headers.
- Build chat 1's patch-script pitfall bit again: a Python patch whose
  replacement text is an ordinary (non-raw) string turns `'\\frac'` into
  `'\frac'`, which Lua reads as a form feed and `rac`. Use raw strings for
  every replacement that carries a backslash, assert the match count, and
  read the written lines back before trusting a check that mentions a
  backslash.

## 6. At the close of your chat

As `next-chat.md` section 7: land what is approved and green, record what
is not, update `PLAN.md` (stage status, section 8, the log), run the three
suites, review `git status` in `configs` and `org` and say which changes
are yours, update the memory note `latex-completion-redesign-2026-09` in
one or two lines, leave every tree uncommitted, and write your successor
beside this file, dated, with the queue as a numbered list, without
rewriting this one.
