# tests/nvim-latency

Guards the insert-mode typing latency of the LaTeX editing setup, and gives you
the tools to measure it again. Written 2026-08-22, after typing in the
dissertation's long paragraph lines on `fedxps` had become slow enough to
notice — several hundred milliseconds per character, against a 3.6 ms floor.

Everything here is hermetic: `fixture.tex` is self-contained, all editing
happens on a copy under `$TMPDIR`, `persistence.nvim` is disarmed so no session
is written, and no repo or real document is touched. The one external
dependency is `french-logic.sty`, which the fixture loads from `~/texmf` via
the usual stow link.

Requires `pynvim` (`python3 -m pip install --user pynvim`); a real UI is
attached to the test instance, because without one there is no screen, hence no
syntax evaluation and no redraw, and every timing would be meaningless.

## What is here

| file | what it is |
|---|---|
| `run.sh` | the regression gate — run this |
| `verify.py` | its 37 checks |
| `bench.py` | the measurement tool (no pass/fail) |
| `stallwatch.lua` | in-session diagnostic for stalls you can't reproduce |
| `harness.py` | shared Neovim harness |
| `fixture.tex` | 4 paragraph lines of ~840/1250/1670/2080 chars |

## The regression gate

```bash
./run.sh          # ~40 s, exit 0 = intact
```

It asserts no milliseconds — timings move with the machine, the power profile
and whatever else is running, so they make a terrible gate. What it asserts is
the *structure* the speed-up rests on, plus the behaviour that must not have
broken:

- VimTeX's matchparen is hooked in normal mode, unhooked during insert, and
  restored on leaving it — and `g:vimtex_matchparen_enabled` is still `1`, i.e.
  it was not blanket-disabled;
- blink still completes after `\command`, inside `\cite{` and inside `\ref{`;
- blink's `snippets` and `vimtex` providers report *disabled* in running prose,
  where they used to be queried on every character;
- a Lua buffer still auto-completes, i.e. non-TeX filetypes are untouched;
- the auto-save autocmds live in the `bph_autosave` group, none is left
  ungrouped, and re-sourcing `autocmds.lua` does not duplicate them;
- the gate's look-behind survives *long* arguments: sources stay enabled deep
  in a 75-char `\cite` key list and after a long optional argument (at the
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

Run it after a VimTeX or blink.cmp update, after editing
`lua/plugins/{vimtex,completions}.lua` or `lua/config/autocmds.lua`, or whenever
typing in a long LaTeX paragraph starts feeling heavy again.

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
pulls in **97 packages**, and on `fedxps` one `kpsewhich` spawn costs ~190 ms —
which is *process startup*, not the lookup: `kpsewhich --var-value TEXMFHOME`,
which looks nothing up, costs the same.

Measured: **18,676 ms for the first `\command` completion with a cold cache,
against 235 ms warm.** It is paid synchronously on the first backslash you type
in a session, and it recurs whenever the cache goes cold — a TeX Live release
upgrade, a new machine, `:VimtexClearCache`, or a document whose preamble
brings in packages not seen before.

Reproduce it deliberately by pointing the cache elsewhere:

```bash
nvim --cmd "let g:vimtex_cache_root='/tmp/cold'" chapter.tex
```

The remedy is `bin/vimtex-warm`, which pays it on purpose rather than
mid-sentence.
