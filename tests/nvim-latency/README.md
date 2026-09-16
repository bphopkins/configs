# tests/nvim-latency

Guards the insert-mode typing latency of the LaTeX editing setup, and gives you
the tools to measure it again. Written 2026-08-22, after typing in the
dissertation's long paragraph lines on `fedxps` had become slow enough to
notice — several hundred milliseconds per character, against a 3.6 ms floor.

Everything here is hermetic: `fixture.tex` is self-contained, all editing
happens on a copy under `$TMPDIR`, `persistence.nvim` is disarmed so no session
is written, and no repo or real document is touched. Two leaks are known
(2026-09-13): each instance writes a `bibcomplete%tmp%…` file into the live
`~/.cache/vimtex`, and its accepts feed the live blink frecency store under
`~/.local/state/nvim`; a scratch `cache_root` and `XDG_STATE_HOME` are the
fix, a `TODO.md` item of the completion campaign. The external
dependencies are `french-logic.sty`, which the fixture loads from `~/texmf`
via the usual stow link, and since 2026-09-13 the generated snippet files
under `nvim/lua/snippets/`, reached through the `~/.config/nvim` link.

Requires `pynvim` (`python3 -m pip install --user pynvim`); a real UI is
attached to the test instance, because without one there is no screen, hence no
syntax evaluation and no redraw, and every timing would be meaningless.

## What is here

| file | what it is |
|---|---|
| `run.sh` | the regression gate — run this |
| `verify.py` | its 79 checks |
| `bench.py` | the measurement tool (no pass/fail) |
| `stallwatch.lua` | in-session diagnostic for stalls you can't reproduce |
| `harness.py` | shared Neovim harness |
| `fixture.tex` | 4 paragraph lines of ~840/1250/1670/2080 chars; its preamble loads french-logic, names `fixture.bib` and defines one command (2026-09-13) |
| `fixture.bib` | two keys for VimTeX's citation completer, copied beside the fixture by the harness |

## The regression gate

```bash
./run.sh          # ~150 s (146 s measured 2026-09-13), exit 0 = intact
```

It asserts no milliseconds — timings move with the machine, the power profile
and whatever else is running, so they make a terrible gate. What it asserts is
the *structure* the speed-up rests on, plus the behaviour that must not have
broken:

- VimTeX's matchparen is hooked in normal mode, unhooked during insert, and
  restored on leaving it — and `g:vimtex_matchparen_enabled` is still `1`, i.e.
  it was not blanket-disabled;
- the two gates of the completion layer rebuilt on TeXstudio's model
  (2026-09-13, stage 3 of the campaign in
  `docs/latex-completion-campaign-2026-09/`): blink's `snippets` provider is
  enabled while a `\command` name is typed and nowhere else, its built-in
  `omni` provider (VimTeX's completers) inside a command's braces and nowhere
  else — so `\cite{` and `\ref{` are omni contexts (these two checks
  *flipped* on 2026-09-13; they pinned the snippets gate open there while
  VimTeX's rows were out of the menu), a command name typed inside another
  command's braces (`\textbf{\al`) is a snippets context, and running prose
  is neither, where blink used to fire on every character; no `vimtex`
  provider exists, no TeX source list names it, every TeX source list names
  `omni`, and VimTeX's omnifunc stays wired for `<C-x><C-o>` — all pinned;
- the rows: VimTeX's citation keys arrive through omni (from `fixture.bib`);
  a snippet row carries its description column; a math-only row is wrapped in
  `$…$` in prose and bare inside math; an environment-restricted row (hyperref's
  `\TextField`, `/Form`) hides in prose and shows inside its environment; the
  fixture, which has no `.fls`, reaches amsmath's `\align` through the
  french-logic hub's includes; the fixture's own `\newcommand` completes with
  its arity, and a definition added to the file and saved is offered at the
  next request; the core file and a french-logic unit are registered under
  their `pkg-` keys and the retired `french-logic` filetype is empty;
  `:SnippetsReload` keeps the registered row count and raises nothing, and a
  row in the hand file with the same label and description as a generated row
  shadows it (the loader lists `hand-local` first, the request-time dedupe
  keeps the first);
- `\begin{`: accepting `enumerate` at `\begin{enum` writes `\begin{enumerate}`,
  an indented `\item` line and `\end{enumerate}` with no stray brace (the
  2026-09-12 breakage wrote `\begin{\begin{align*}` / `\end{align*}}`), and
  so does `hilbertlist`, a french-logic list environment VimTeX does not know
  on the fixture, which reaches the menu from the loaded files (the union
  decided 2026-09-13); a non-list environment gets an empty indented body line;
- `<Tab>` and `<S-Tab>` jump between LuaSnip placeholders, from insert mode
  and from select mode, through the real path (the `\frac` row accepted with
  `<CR>`, since 2026-09-13 TeXstudio's math-only `$\frac{num}{den}$` with named
  placeholders, so the typed letters replace the selected text) — LazyVim's
  own `<Tab>` entry jumped native snippets only, and under the luasnip preset
  it inserted whitespace instead (2026-09-12);
- blink's per-keystroke snippet check stays off LuaSnip's trigger scan
  (2026-09-13, stage 4 of the campaign): the luasnip preset answered
  `snippets.active()` with `ls.expandable()`, a match of every registered
  trigger against the line, on every `InsertCharPre` and `TextChangedI`,
  where the answer is discarded — 3.5 ms per prose keystroke with the
  closure's 7,760 rows, and the closure load on the first insert-mode
  keystroke of a session; `completions.lua` keeps the scan for `<Tab>` and
  `<S-Tab>` only.  Pinned twice: prose keystrokes never reach the loader's
  `ft_func` (the scan begins by asking for the buffer's filetypes), and the
  one thing the scan served, a fully typed trigger expanding on `<Tab>` with
  the menu closed, still works;
- the loader's idle pre-warm registers a TeX buffer's closure after VimTeX's
  init, one file per timer tick, so the first request no longer pays 660 to
  750 ms (2026-09-13, stage 4): pinned before any keystroke, the pre-warm
  reports done, a french-logic unit is registered, and the request path
  never ran; and the description column is 45 cells (blink's default 30 cut
  a tenth of the rows);
- a Lua buffer still auto-completes, i.e. non-TeX filetypes are untouched;
- the auto-save autocmds live in the `bph_autosave` group, none is left
  ungrouped, and re-sourcing `autocmds.lua` does not duplicate them;
- the CTRL-D step is 10 *display* rows and stays there (2026-09-15): the
  `bph_scroll_step` autocmd in `autocmds.lua` holds `'scroll'` through a
  window resize and into a new split, `<C-d>` moves exactly ten display rows,
  and a window no taller than the step keeps Vim's own half-window default.
  `'scroll'` is window-local and Vim resets it to half the window height on
  every size change, so the thing being pinned is that the autocmd re-applies
  it — a plain `vim.opt.scroll` in `options.lua` is indistinguishable from
  having nothing at all (mutation, below).
  ⚠ The row count is measured *in the fixture*: the filetype check above
  leaves a two-line `enew` Lua buffer current, where `<C-d>` cannot scroll and
  the count reads 0 against an expected 10. It did, on the first run; the
  `v.open_fixture()` and the filetype guard beside it are what stop that check
  going quietly vacuous;
- the gate's look-behind survives *long* arguments: the provider stays enabled
  deep in a 75-char `\cite` key list and after a long optional argument (at the
  original 60-char window both went dead mid-argument — found 2026-08-22,
  while the short arguments above had been passing all along);
- auto-save failures are loud exactly once: a readonly buffer is skipped
  silently, a disk-level failure notifies once per buffer with repeats quiet,
  and recovery saves and notes once (`silent! write` used to swallow all of
  it — and the replacement needed a confirm-guard, because under LazyVim's
  `'confirm'` a failing `:write` pops a modal dialog instead of erroring);
- markdown `<CR>` serves both masters: blink's enter-accept (blink applies
  its own buffer-local mapping and snapshots ours as its fallback —
  undocumented upstream behaviour) and checkbox-list continuation.

Run it after a VimTeX, blink.cmp or LuaSnip update, after editing
`lua/plugins/{vimtex,completions,snippets}.lua`, `lua/snippets/{loader,helpers}.lua`
or `lua/config/autocmds.lua`, or whenever typing in a long LaTeX paragraph starts
feeling heavy again.

**2026-09-15, the scroll step**, three mutations of a copied config tree via
`NVIM_LATENCY_CONFIG`, each run and checked against its exact failure set:

- *The `bph_scroll_step` autocmd deleted outright*: `74 passed, 5 failed` —
  the step (24, want 10), its survival of a resize (24) and of a split (12),
  the return after resizing back (24), and the row count (22 rows, want 10).
  The two checks that stay green are the ones that should: the fixture guard,
  and the short-window default, which without the autocmd is what you get
  everywhere.
- *`vim.opt.scroll = 10` in `options.lua` instead of the autocmd* — the
  tempting wrong implementation: **the identical `74 passed, 5 failed`**, the
  same five values. Expected to survive the first check and did not, because
  this harness attaches its UI after startup and the attach is itself a size
  change, so Vim has already reset it to 24 before the first check reads it.
  ⚠ That totality is a property of the harness; in an ordinary launch a plain
  option would last until the first resize or split. The claim that does not
  depend on the harness is the measured decay, 10 to 19 after a resize and to
  13 in a split.
- *The height guard dropped* (`> SCROLL` removed from the window test): **not
  a failure but an abort** — `WinNew Autocommands for "*": E49: Invalid
  scroll size`, raised on the first small window the suite opens, killing the
  run before any count. Setting `'scroll'` larger than its window is an error,
  and this autocmd fires on `WinNew`, so the guard is what keeps a completion
  menu or a popup from throwing. That is the guard's real job; the
  half-window-default check merely records the visible half of it.

**Mutation-verified**, in three directions (2026-08-22, each run and checked
against its exact failure set):

```bash
NVIM_LATENCY_CONFIG=/path/to/mutated-tree python3 verify.py
```

- *Pre-fix `autocmds.lua` + `completions.lua`* (60-char window, `silent!
  write`): exactly the two long-argument checks and three auto-save-loudness
  checks fail — plus the two markdown-menu checks as **cascade**: the old
  `silent!` code under `'confirm'` leaves a modal dialog pending, which eats
  the markdown block's keystrokes.  Non-local, but itself a demonstration of
  the bug being guarded.
- *`lua/plugins/markdown_tasks.lua` removed*: exactly the buffer-local `<CR>`
  mapping check and the checkbox-continuation check fail.
- *The confirm-guard deleted from the auto-save callback*: the four
  disk-failure/recovery checks fail (the dialog is back, so no notification
  ever fires), plus the same two-check cascade — which is what pins the
  guard.
- *`completions.lua` without its `<Tab>` entry* (the state before 2026-09-12):
  exactly the three jump checks fail — `<Tab>` inserts whitespace, the
  `<S-Tab>` check then lands its text before the snippet, and select-mode
  `<Tab>` inserts more of it; the session-opens check passes, as it always
  did.

**2026-09-13, stage 3 of the completion campaign**, three mutations of a copy
of the tree with `pkg/` and `sty/` symlinked in (the copy has no
`latex/french-logic`, so the startup regeneration check skips itself):

- *The `\begin{` union removed* (the omni transform appends no names of the
  loaded files): exactly the `hilbertlist` and `proofsketch` template checks
  fail — VimTeX offers neither on the fixture — while `enumerate`, VimTeX's
  own, still passes.  Found while doing this: a row that never appears made
  the check *raise* instead of fail, aborting the run; `begin_accept` now pads
  its result, so a mutation reaches its full failure set.
- *The nested-command branch removed from the omni gate*: exactly the
  `\textbf{\al`: omni closed check fails.
- *The math wrap disabled in `helpers.lua`*: exactly five checks fail, the
  `\alpha` prose wrap and the four `\frac` jump checks, whose expected text
  carries the `$…$`.

The two checks added at the close (`:SnippetsReload` keeps its counts; a
hand row shadows its generated twin) were not mutation-run.

**2026-09-13, stage 4**, one mutation of the same kind of copy, *the
`snippets.active` override removed from `completions.lua`*: exactly the
`ft_func` pin fails (24 calls for 12 keystrokes, want 0).  The `<Tab>`
expansion check passes either way, as it must: it pins what the override
preserves, not what it removes.  A second mutation the same day, *the
`VimtexEventInitPost` autocmd removed from `loader.lua`*: exactly the
pre-warm pin fails (no pre-warm state, want done) and the other 70 pass,
the request path still registering the closure on its own. The shadow check
cannot pass vacuously: it compares the list of `\frac` rows to exactly the
injected row's id, so a loader that listed `hand-local` after the generated
files, or a transform that kept the second row, both fail it. Its first run
did fail, for a reason worth knowing: the patch that wrote it ate one level
of backslashes and the injected trigger became a form feed plus `rac`.

(Historical, against the original pre-2026-08-22 tree of the then-23 checks:
`16 passed, 7 failed — one matchparen, three prose-gating, three auto-save`.)

That environment variable exists for this purpose. One honest note about how it
was built: the idempotency check originally counted only *grouped* autocmds,
which made it pass vacuously against the pre-fix code (0 == 0). It now counts
tex auto-save autocmds regardless of group, so the pre-fix duplication (2 → 4)
is visible. Worth remembering if you add checks here — a check that cannot fail
is worse than no check.

## Measuring

```bash
./bench.py                          # cost vs. logical line length
./bench.py --ablate                 # attribute it subsystem by subsystem
./bench.py --file ~/Desktop/dissertation/completeness/completeness.tex
# --file alone measures EVERY paragraph line of the document, 14 keystrokes
# each: minutes on a chapter.  --ablate confines itself to the longest line.
./bench.py --config /path/to/other-config
```

`--file` measures a throwaway **copy** of the document, never the document
itself. `measure()` types characters into the buffer and undoes them, but the
undo does not reach disk — the auto-save autocmd has already written on
`InsertLeavePre` — so pointed at a real file it used to leave its filler
string on every long line it visited, and an interrupted run left it with no
undo at all. The damage is invisible in the tool's own output, which prints
timings either way; `verify.py` now pins byte-identity of the target.

The cost is driven by **logical line length**, and these files are one
paragraph per line. Measured on the real completeness chapter (median ms per
keystroke, `fedxps`, tuned `powersave`):

| line length | 585 | 1001 | 1417 | 1860 |
|---|---|---|---|---|
| before | 44 | 82 | 262 | 218 |
| after | 13 | 23 | 84 | 54 |

Below roughly 1000 characters the config was never the problem. The floor for
comparison is `nvim -u NONE` on the same line: **3.6 ms**.

**2026-09-12 — those are power-saver numbers.** The laptop was in Power Mode
power-saver (tuned `powersave`, EPP `power`, clocks pinned at 900 MHz) for
every row above. Re-measured with this bench on the same 1841-char line:
performance mode 7 ms, balanced 8 ms, power-saver 17–21 ms (p50), against
4 ms on bigfed; by line length under balanced, 585/1007/1417/1841 → 7/12/13/8.
The residual was the power mode, not the engine; write in balanced or
performance mode. Full record: `docs/insert-latency-2026-08.md`, addendum.

The attribution that produced the fix, at the end of an 1860-char line:

| component | ms |
|---|---|
| VimTeX's own matchparen | 62 |
| blink `snippets` source (1063 tex snippets) | 33 |
| blink `vimtex` source via blink.compat | 26 |
| the 250 custom syntax cmd rules | 29 |
| base VimTeX syntax (946 match rules, 97 packages) | 20 |

Two things worth keeping in mind when reading `--ablate` output. The rows do
not sum — turning syntax off also removes the syntax lookups that matchparen
and completion perform. And **Neovim's built-in matchparen costs nothing
here**: it returns immediately unless the cursor sits on a bracket, which at
the end of a prose line it does not. It was VimTeX's own that was expensive,
and only that one is touched.

## Catching a stall you cannot reproduce

Some stalls are seconds long and don't show up in a benchmark, because they are
one-shot costs. Load this in the real session and keep working:

```vim
:luafile ~/Desktop/configs/tests/nvim-latency/stallwatch.lua
```

Every keystroke slower than the threshold (default 400 ms, override with
`STALLWATCH_MS`) is appended to `~/nvim-stalls.log` with the file, line length,
package count, whether a compile was running and whether the completion menu
was open. On the first stall it also dumps a VimTeX profile to
`~/nvim-stalls.profile`. Nothing is written unless a stall happens.

`:StallWatchStatus`, `:StallWatchDump`, `:StallWatchOff`.

It measures by stamping the time in `InsertCharPre` — which fires the moment
the character arrives, before anything else runs — and scheduling a callback
the event loop can only run once it is free again. The gap between the two is
the time the character spent not reaching the screen.

Proved non-vacuous when written: against a deliberately induced 900 ms block it
logged 903 ms, and logged nothing for ordinary keystrokes. Note that inducing
one with `:sleep` does **not** work — `:sleep` yields to the event loop, so the
scheduled callback runs during it and measures nothing. Use a busy loop.

## The other stall: VimTeX's cold package cache

Separate from per-keystroke cost, and much larger. VimTeX resolves every
`\usepackage`'d package by spawning `kpsewhich`, then reads the `.sty` it
finds, caching both under `~/.cache/vimtex`. The completeness chapter's root
pulls in 111 packages (97 before the french-logic unit split), and on `fedxps`
one `kpsewhich` spawn costs ~190 ms in power-saver mode — which is *process
startup*, not the lookup: `kpsewhich --var-value TEXMFHOME`, which looks
nothing up, costs the same.

Where it is paid has moved with the completion layer. Measured 2026-08-22:
**18,676 ms for the first `\command` completion with a cold cache, against
235 ms warm**, on the first backslash typed in a session, because VimTeX's
command completer was in the menu then. Since 2026-09-12 that completer is out
of the menu, and since 2026-09-13 VimTeX's argument completers are back inside
braces through blink's omni provider, so the scan is paid at the **first
`\begin{`** of a session (or `<C-x><C-o>`): 13.3 s cold on the chapter with
111 packages, 28 to 31 ms primed; 356 ms cold on this suite's fixture (stage 4
of the completion campaign, `docs/latex-completion-campaign-2026-09/PLAN.md`
section 3). It recurs whenever the cache goes cold — a new machine,
`:VimtexClearCache`, or a document whose preamble brings in packages not seen
before; a TeX Live release upgrade does *not* empty it (the cached paths keep
resolving; the risk there is staleness). `\usepackage{` is a separate 0.9 s
per session that no cache covers: VimTeX lists `kpsewhich --all ls-R` per
session and stores nothing.

Reproduce it deliberately by pointing the cache elsewhere:

```bash
nvim --cmd "let g:vimtex_cache_root='/tmp/cold'" chapter.tex
```

The remedy is `bin/vimtex-warm`, which pays it on purpose rather than
mid-sentence. This suite runs against the live cache, so its instances are
primed and never see the stall (and each leaves a `bibcomplete%tmp%…` file
there: `TODO.md` item 20 is the scratch cache root).
