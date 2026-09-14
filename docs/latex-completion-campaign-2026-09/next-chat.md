Annotation, 2026-09-13: build chat 1 opened from this brief and landed stage 1; its successor is `next-chat-2026-09-13.md` beside this file. Sections 1, 6 and 8 here still bind.

Prompt — the opening brief for the first build chat of the LaTeX completion
campaign. Dated record, written 2026-09-13 at the close of the second
planning chat, on fedxps. The next chat writes its own successor beside this
file at its close (`next-chat-YYYY-MM-DD.md`), adds one annotation line at
the head of this one, and otherwise leaves it as it is.

# Read this whole file, then PLAN.md, then the comparison record, before touching anything

You are opening a fresh chat on the campaign that rebuilds the LaTeX
completion layer of `configs/nvim` on TeXstudio's model. The global rules,
the per-repo charters and the memories load on their own. This brief adds
what is specific to the campaign: what it is and how long it will take, how
the work is done with Brandon, what two planning chats found and decided,
the state of the trees you inherit, what to verify before you build, what
the first build chat does, the pitfalls already met, and how to close. The
order matters. First absorb, as a non-interventionist. Then verify. Only
then build.

## 0. What this campaign is, and how long it takes

The aim, the decisions, the target shape, the stages with their acceptance
checks, the hazards and the record trail are in `PLAN.md` beside this file;
its section 0 says what "done" means and nothing else does. The evidence is
`comparison-2026-09-12.md`, whose section 6 is the table of spikes that
turned the design from reading into measurement. His own study of the
TeXstudio side is `texstudio-summary.md` beside this file.

This will take several chats. The honest expectation is five to seven: one
for the generator's cwl front end (stage 1), one for folding the `.sty`
front end in (stage 2), one or two for the loader, the gates, the provider
and the suite changes (stage 3), one for measuring on both machines (stage
4), one for the records (stage 5). Any of them may split, and it is likely
that one of them, probably before the loader, turns out to be a planning
chat again: the loader touches the most moving parts (LuaSnip, blink,
VimTeX, the auto-pair, two suites), and a chat that finds a gap in the plan
while reading should stop, write the gap into `PLAN.md` section 8 and into
its successor brief, and put the question to him, rather than improvise.
He said on 2026-09-13 that he wants this done right, taking time and being
very careful at each step; a slow chat that lands one stage clean is the
success case, and a fast chat that lands two stages with a suite left red
is the failure case.

The brief chain is how the campaign remembers itself across chats, and it
carries a known hazard: on the french-logic campaign the chain accumulated
sub-tasks until he worried it might never end. The remedy here is that the
campaign has a finite end written in `PLAN.md` section 0, every successor
brief carries the queue as a numbered list with what closes each item, and
anything not needed for that end goes to `TODO.md` as its own item
(`PLAN.md` section 6), never into the queue.

## 1. How the work is done with Brandon

Read this as instructions, not description. Most of it is his standing
working agreement, in the terms the french-logic briefs used; the rest is
specific to this campaign.

- **One decision at a time, in order of obviousness, then importance.**
  Objective fixes he will plainly assent to are applied, not asked. Genuine
  trade-offs are asked. Batch several *independent* decisions into one
  question round only when each is small and self-contained; one
  `AskUserQuestion` call with several questions is welcome, a bare option
  list is not.
- **Every ask carries five things:** what the issue is; why it is an issue;
  why it should be decided; how you propose to decide it; and the plausible
  reasons *not* to. Every option says what it does and what changes if he
  picks it, with a recommendation first and its reasoning. When he says he
  has not been given enough to answer intelligently, he means it literally:
  show the rows, show the measurement, show the mock-up, and ask again. On
  2026-09-12 the argument-completion question had to be asked twice for
  exactly this reason.
- **Vision before tweaks.** Any uncertainty about his intentions is raised
  before the next tweak, however small. He often supplies the history behind
  a mechanism when asked, and the history usually contains the design (the
  trailing `~` on every trigger was an old chat's misreading of blink's
  menu; he told the story and settled it in one line).
- **Act immediately after his answer.** Build it, prove it with the suites,
  land it, update `PLAN.md`, report. Do not accumulate approved work.
- **Show the measurement, do not summarise it.** A number is stated once
  cross-checked; "this depends on X, which I could not verify" beats a clean
  verdict on an assumption. Confidently wrong output is his central concern
  with LLMs. Say what was measured and what is inferred, every time.
- **When he corrects you, check his usage before answering,** then concede
  with the evidence. When he asks "what do you think?", give a real opinion
  with its reason and its cost. Repeated pushback means the approach is
  wrong, not the phrasing: re-derive from his framing.
- **His documents are his.** `CLAUDE.md` files, `TODO.md` and `DECISIONS.md`
  are edited only after he approves a draft. The campaign's own files
  (`PLAN.md`, the records, the briefs, memory) you edit freely.
- **He commits, never you.** Leave every tree dirty and describe it; never
  `git commit`, never push, never nag about `gpushall`, never attribute
  anything to Claude. The configs repo is public: no secrets, no private
  content, and `gpushall` runs `git add -A`, so never leave scratch inside
  a repo.
- **Nothing breaks the dissertation.** Both Neovim suites
  (`tests/nvim-syntax/run.sh`, ~5 s; `tests/nvim-latency/run.sh`, ~50 s,
  needs pynvim) after every stage, and before any change to the completion
  config lands. A watcher compiles his LaTeX in the background; never
  compile to check your own edit.
- **Probes are read-only and harness-bound.** Anything that types goes
  through `tests/nvim-latency/harness.py` on its throwaway fixture copy;
  anything read-only goes through one `nvim --headless FILE +'lua …' +qa!`
  per file with `NVIM_NOSESSION=1`. Never kill `nvim --embed` broadly: the
  pair of long-running nvim processes is his editor. Never edit a stowed
  file through its live path.
- **The register taxonomy is out of scope.** The five stray colours found
  on 2026-09-12 (comparison 1.4) go to the bench by his process, not into
  this campaign.
- **Keep the last rounds of a long session short.** When he says to wrap
  up, close cleanly (section 7).

## 2. What the planning chats found and decided

The full list with rationale is `PLAN.md` section 1; the spikes are section
9 and comparison section 6. Do not re-litigate any of it. The shape:

- Generic snippets are regenerated from TeXstudio's cwl corpus, every file
  converted one-to-one, only `#S` rows dropped. `latex-workshop.lua` was a
  lossy copy of a tenth of the data with 21 artefacts and 13 wrong arities;
  the corpus adds about 450 math commands he lacked and named placeholders.
- One Lua file per cwl (about 4,400 after exclusions), committed to the
  public repo with per-file attribution and a `pkg/NOTICE`. Both were his
  own calls on 2026-09-13; the weight is measured (24 MB of cwl, an
  estimated 35 to 45 MB of Lua before git's compression) and `gpushall`
  prompts only above 25 MB per file.
- The loader is document-driven: on each completion request the LuaSnip
  filetype function reads VimTeX's package table, registers on demand any
  package not yet registered, follows `includes` headers, and returns the
  buffer's pseudo-filetypes. No VimTeX event hook. The hub `french-logic`
  implies its units and their requires for documents without an `.fls`.
- Unusual (`#*`) rows are generated with a small sink subtracted from the
  provider's offset; his own usage of them is half a percent, all preamble
  plumbing.
- One row per distinct signature; the compact shape in blink's description
  column, the expansion with named placeholders in the on-highlight window;
  unusual rows end with `∗`.
- Math-only rows are wrapped in `$…$` at expansion outside math (validated:
  1,023 sampled uses in math, none in prose). Environment-restricted rows
  hide outside their environment (measured nearly moot: six typical rows).
- VimTeX's argument completers reach the menu through blink's built-in
  `omni` provider inside `\command{…` contexts only; snippets close there.
  Inside `\begin{` the omni rows are rewritten into environment templates
  (measured). The old brace branch was harmful, not merely noisy: accepting
  an environment snippet inside `\begin{` wrote `\begin{\begin{align*}`.
- Document-local `\newcommand`s complete with arity, from the preamble.
- Triggers are plain `\name`. Dedupe at generation against the core three,
  and per request in the transform, never at registration.
- Option blocks are skipped (his options select nothing); expl3-commands,
  fontenc and inputenc are excluded.
- Deferred to `TODO.md` at the end: keyvals inside `[…]`, named placeholders
  for french-logic's own commands, corpus-frequency ranking, the stray
  colours, autogenerated lists for packages with no cwl (his own classes;
  the old documents on bigfed), a clone twin on bigfed.

Two things were tried and are declined with evidence: a `regTrig`
environment snippet (blink inserted the pattern text) and a pre-expand
callback editing the buffer (blink fixes the clear region before LuaSnip's
callback runs).

## 3. The state of the trees you inherit

- Nothing in `configs/nvim`'s configuration was changed by the planning
  chats. The campaign directory holds `PLAN.md`, `comparison-2026-09-12.md`
  and this brief. Two memory notes were written
  (`latex-completion-redesign-2026-09`, `nvim-snippet-trigger-tilde-was-a-mistake`)
  and one got an addendum (`nvim-input-probes-use-latency-harness`).
- `git status` in `configs` showed, before this campaign touched anything,
  modifications of his own in progress: `CLAUDE.md`,
  `bash/.bashrc.d/60-stow.sh`, `nvim/CLAUDE.md`, `nvim/after/ftplugin/tex.lua`,
  `nvim/after/syntax/tex.lua`, `nvim/docs/latex-register-taxonomy.md`,
  `nvim/lua/plugins/{completions,persistence,snippets,vimtex}.lua`,
  `tests/nvim-latency/{README.md,run.sh,verify.py}`,
  `tests/nvim-syntax/verify.lua`, and an untracked `tmux/`. They are not
  yours. He may have committed them by the time you read this. Never sweep,
  revert or "clean up" what you did not make; when you report the tree,
  say which changes are yours.
- The spike scripts are kept in `spikes/` beside this file, with a README
  that says what each showed and how it ran; re-run one rather than rewrite
  it. `tests/nvim-latency/harness.py` is the tool for anything that types.
- The read-only clone `~/Desktop/texstudio` is on fedxps, where the next
  chat most likely opens. Whenever a campaign chat first opens on bigfed, he
  clones a twin onto that Desktop first, so TeXstudio is local there too.
  The clone's root `CLAUDE.md` is its one untracked file, must stay
  untracked and visible, and must be copied to the twin and mirrored on
  every edit (that charter says so). The first bigfed chat does that copy,
  pulls `--ff-only`, records both HEADs, and checks that bigfed's
  `~/Desktop/CLAUDE.md` carries the `texstudio/` line added to fedxps's on
  2026-09-13: that charter is a plain per-machine file, not a synced link. Upstream master was `0362907c2` on 2026-09-12; the 4.9.7 tag,
  which is the installed rpm, has byte-identical definition files.
- Plugin commits on which the spikes were run (`nvim/lazy-lock.json`):
  blink.cmp `78336bc`, LuaSnip `0abc8f3`, vimtex `45a5a56`. If any has
  moved when you read this, the affected spikes are re-run before building
  (section 4).

## 4. Verify before you build

In this order, and record the results in your successor brief:

1. Both suites green as the baseline: `tests/nvim-syntax/run.sh` (56 checks)
   and `tests/nvim-latency/run.sh` (42 checks). If either is red before you
   touch anything, stop and tell him; the campaign does not start on a red
   baseline.
2. `git -C ~/Desktop/texstudio pull --ff-only`; record the new HEAD. A pull
   that aborts because upstream added its own `CLAUDE.md` is the documented
   case: rename theirs, keep his.
3. The existing generator is current: from the `configs` root,
   `python3 nvim/lua/snippets/sty-lua-snippets.py -i latex/french-logic/french-logic.sty -i …units… -o nvim/lua/snippets/french-logic.lua --check`
   (the unit list is the hub's `\RequirePackage{french-logic-…}` lines, hub
   first; `lua/plugins/snippets.lua` shows the order).
4. Compare the three plugin commits with section 3. If blink moved, re-run
   the loader spike (comparison 6, first six rows) before trusting the
   `complete_func` source, the per-item `score_offset`, `use_label_description`
   and `get_snippet_filetypes()`. If LuaSnip moved, re-check `ft_func`,
   `clean_invalidated` and function-node evaluation at expansion. If VimTeX
   moved, re-check `vimtex#complete#complete()`, `update_packages`, and that
   `b:vimtex.packages` still comes from preamble plus `.fls`.
5. `nvim/.styluaignore` lists the two generated files by name; LazyVim's
   format-on-save would reflow anything under `pkg/` that is ever opened in
   the editor. Extend the ignore before the first generated file exists.
6. Read `PLAN.md` section 8 and add anything your reading turns up. Those are
   the questions for him, asked in one round before the first file is
   generated (section 5).

## 5. The first build chat: stage 1

Stage 1 is the generator's cwl front end and its suite, with no change to
any configuration file. Its acceptance is in `PLAN.md` section 3; the
generation rules are in section 2. The procedure:

1. Read TeXstudio's cwl format reference
   (`utilities/manual/source/background.md`, "Description of the cwl
   format") and the loader that consumes it (`src/latexpackage.cpp`,
   `loadCwlFile`), then the existing generator `sty-lua-snippets.py` whose
   Lua emitter you will keep and whose `--coverage` mode you must not break.
   Note how TeXstudio itself renders a row (`CodeSnippet`, `codesnippet.cpp`)
   and expands an environment (`expandCode`, `environmentContent`): the
   generated rows should look the way his TeXstudio looked.
2. Put the design smalls to him in one round, with the five parts each,
   before generating anything: the environment row's description text;
   whether `\begin{itemize}` and `\begin{itemize}\item` are one row or two;
   `(x,y)` picture coordinates; how a `%<…%>` partial placeholder embedded in
   literal text renders (`\includegraphics[scale=%<1%>]{file}`); starred
   variants; the sidecar format for `#keyvals`; the wording of `pkg/NOTICE`;
   the file layout of `tests/snipgen`. Add whatever your reading of the
   format turned up. He would rather answer eight small questions at once
   than find a choice made for him.
3. Write the suite first: a fixture cwl exercising every rule of `PLAN.md`
   section 2 (each classification letter, `#include`, `#ifOption`,
   `#keyvals`, `%<…%>`, `%|`, `%\`, `%suffix` names, `\begin` lines with
   and without `\item`, hidden and unusual rows, an unknown suffix), a
   golden Lua output, a `--check` idempotence check, and a README. Then the
   parser, until the suite is green. Then one mutation (break the `%<…%>`
   rule), see red, restore, record it in the README.
4. Run `--all` against the clone; record running time, file count and total
   size in `PLAN.md` section 3; spot-check amsmath, class-memoir, biblatex,
   tikz and latex-document rows against the visible-row lists of comparison
   section 2.5, and against what TeXstudio shows for the same commands.
5. Draft `pkg/NOTICE` for his approval; extend `.styluaignore`; confirm
   `stow-all-dry` shows nothing surprising for a new directory under
   `nvim/lua/snippets/` (the directory is folded into one symlink today;
   new files inside it appear without a restow, a new directory may not).
6. Stop there. Do not touch `snippets.lua`, `completions.lua` or the loader
   in this chat, even if time remains; write the successor brief instead.
   Stage 2 begins the next chat.

If the chat runs long, the clean stopping points are after step 3 and after
step 4; say which one you reached.

## 6. Pitfalls already met, so you do not

- The trailing `~` on every current trigger is a mistake, not a convention;
  new files never carry it, and blink expands correctly without it.
- The auto-pair writes a `}` after `\begin{`; anything inserted there must
  consume it (the omni transform extends its edit by one character when the
  next character is `}`), or `\end{align}}` results.
- A per-item `score_offset` replaces the provider's offset (10 for
  snippets); subtract from it, never set an absolute.
- Dedupe at registration makes a row's home depend on which document loaded
  first; dedupe at generation (against the core three) and per request.
- `ls.add_snippets` under an existing key marks the old rows invalidated and
  `get_snippets` keeps listing them until
  `clean_invalidated({ inv_limit = 0 })`.
- blink shows at most 200 rows (`max_items`); the transforms still run over
  the whole provider result, so their per-row work must be a table lookup.
- `vim.b.vimtex` is absent until VimTeX has initialised a buffer, and VimTeX
  may choose a chapter's article wrapper as the main file; read the package
  table on the request path, not at `FileType`.
- The root `dissertation.fls` (2026-08-09) predates the unit split; the
  package table refreshes only on a successful compile; the latency fixture
  has no `.fls` at all and loads everything through french-logic.
- The first `\begin{` on a machine with a cold VimTeX package cache costs
  about 3 s; `vimtex-warm` primes `pkgcomplete.json`. The charter's
  cold-cache rule must say so again at stage 5.
- `vimtex#env#get_inner()` is a search; memoise it once per request.
- A headless sweep that `:edit`s file after file never reaches VimTeX's
  syntax post-init; use one instance per file. Strip comments on lines that
  begin with `%`, or commented-out code counts as prose.
- `#*` is a cwl author's guess at typicality, not his usage; the flag stays
  in the data for a later corpus-frequency pass.
- Names containing `@` are internal to a package; the `.sty` front end skips
  them by design.
- The public repo and `git add -A`: the campaign directory and `pkg/` are
  meant to be committed; the scratchpad is not in any repo; never write a
  probe or a generated file anywhere else inside a repo.

## 7. At the close of your chat

Land what is approved and green, record what is not, update `PLAN.md`
(stage status, the numbers stage 1 asks for, section 8), run both suites,
review `git status` in `configs` and `org` and say which changes are yours,
update the memory note `latex-completion-redesign-2026-09` in one or two
lines, leave every tree uncommitted for his sync, and write your successor
to this brief beside it, dated, with the queue as a numbered list, without
rewriting this one. If your chat was a planning chat after all, say so in
the first line of the successor and in `PLAN.md` section 10.

## 8. Where to look

| what | where |
|---|---|
| the plan, decisions, stages, hazards, chat log | `configs/docs/latex-completion-campaign-2026-09/PLAN.md` |
| the measurements and spikes | `comparison-2026-09-12.md`, beside it |
| his study of TeXstudio | `texstudio-summary.md` beside this file (the Desktop original is unsynced scratch) |
| the clone and its charter | `~/Desktop/texstudio`, `~/Desktop/texstudio/CLAUDE.md` |
| cwl format reference | `texstudio/utilities/manual/source/background.md`, "Description of the cwl format" |
| cwl loader, completer rows, environment expansion | `texstudio/src/latexpackage.cpp`, `src/codesnippet.cpp`, `src/latexcompleter.cpp` (`filterList`) |
| the existing generator and its consumers | `configs/nvim/lua/snippets/sty-lua-snippets.py`, `lua/plugins/snippets.lua`, `lua/plugins/completions.lua` |
| VimTeX completion and package detection | `~/.local/share/nvim/lazy/vimtex/autoload/vimtex/complete.vim`, `state/class.vim` (`s:parse_packages`, `update_packages`), `complete/tools/convert-cwl` |
| blink's sources | `~/.local/share/nvim/lazy/blink.cmp/lua/blink/cmp/sources/{snippets/luasnip.lua,complete_func.lua}`, `config/sources.lua` (the `omni` provider), `fuzzy/init.lua` (`score_offset`) |
| LuaSnip's filetype and loader hooks | `~/.local/share/nvim/lazy/LuaSnip/lua/luasnip/{default_config.lua,util/util.lua,loaders/init.lua}` |
| the suites and the harness | `configs/tests/nvim-syntax/`, `configs/tests/nvim-latency/` (`harness.py`, `verify.py`, `README.md`) |
| the spike scripts and their index | `configs/docs/latex-completion-campaign-2026-09/spikes/README.md` |
| the charter that will change at stage 5 | `configs/nvim/CLAUDE.md`, sections Completion, Snippets, the cold-cache stall, Regression suites |
