# Spikes of the planning chats, 2026-09-12 and 13

Dated record. The scripts that produced the numbers in
`../comparison-2026-09-12.md` (sections 4 and 6) and `../PLAN.md` section 9,
kept as they ran so a build chat can re-run one instead of rewriting it.
They are probes, not tests: read-only on his documents, typing only on the
latency harness's throwaway fixture copy, everything injected at runtime
through `require('blink.cmp.config')` and `require('luasnip.session').config`.
Run them from this directory (or `export SPIKES=<this dir>`); the Python
spikes import `harness` from `~/Desktop/configs/tests/nvim-latency`.

| script | how it ran | what it showed |
|---|---|---|
| `xref.py`, `xref2.py` | `python3`, reads the clone's `completion/` | the dissertation's cwl closure, visible rows after `#*`/`S`/`/env`/`#ifOption`, the coverage gap, the LaTeX Workshop file's arity and artefact audit (xref2 is the option-aware version) |
| `usage.py` | `python3` over `~/Desktop/dissertation/**/*.tex` | every command he types, classified typical / unusual / french-logic / absent |
| `dups.py` | `python3` | cross-file duplicate rows in the closure; unusual env-restricted rows |
| `envuse.py` | `python3` | the innermost environment at each use of `\draw`, `\node`, `\item`, booktabs rules |
| `probe.tex` + `probe.lua` | `NVIM_NOSESSION=1 nvim --headless probe.tex +'lua dofile("probe.lua")' +qa!` | final highlight group and colour at 23 spots; the five stray theme colours; VimTeX's 14 default targets resolve to 6 colours |
| `probe2.lua` | same, on a chapter | the same spots in real text (`&` in align, `\text{}` in math) |
| `probe3.lua`, `probe4.lua` | same, on `completeness.tex` | VimTeX's bib/ref/env/pck/cmd completers through `vimtex#complete#complete()`, rows and timings, warm and cold |
| `probe5c.lua` | one headless nvim **per file**, looped from the shell over `texfiles.txt`, reading `m-names.txt` | math-only commands in prose: none (1,023 in math; 100 apparent hits were commented-out code). The same sweep with `:edit` inside one instance never reached VimTeX's post-init and idled for 35 minutes; that design is not kept |
| `probe6.lua`, `probe7.lua` | headless on a chapter / on `probe.tex` | cost of reading `b:vimtex.packages` (0.09 ms) and `in_mathzone()` (0.05 ms); keyed `add_snippets` leaves old rows invalidated until `clean_invalidated({inv_limit=0})` |
| `doc.lua` | headless on `probe.tex` | what the on-highlight window shows (the docstring), blink's menu columns, the provider options |
| `envprobe.py`, `envprobe2.py` | harness | the `\begin{ali` breakage: `\begin{\begin{align*}` / `\end{align*}}`; 175 rows inside `\cite{che`; blink's omni provider enabled at runtime yields package rows |
| `envprobe3.py`, `envprobe4.py` | harness | the omni provider inside `\begin{` (needs an environment VimTeX knows: the fixture has no `.fls`); `enumerate <omni>` as first row |
| `spike1.py` | harness | runtime `ft_func` + per-package registration, `show_condition`, per-item `score_offset` (relative, not absolute), dedupe, description column, tilde-less triggers, Lua buffer untouched, transform cost |
| `spike2.py` | harness | math wrap at expansion (`$\alpha$` / `\alpha`); a pre-expand callback editing the buffer scrambles the line (declined) |
| `spike3.py` | harness | the omni transform that writes an environment template at `\begin{` (kept); a `regTrig` environment snippet (declined); `\end{` shows nothing until a letter is typed |

`m-names.txt` is the list of math-only commands he uses (name, count);
`texfiles.txt` the 41 dissertation files swept. Both are inputs as of
2026-09-12 and regenerate from `usage.py`'s logic and `find`.
| `spike4.py` | harness, bench method | keystroke cost inside a command name and in prose, today (1,054 snippets) and with 8,000 synthetic rows injected: +14 ms median per command-name keystroke, prose unchanged; in-process attribution (source once per word, fuzzy per keystroke) |
| `probe8.lua` | headless on `probe.tex` | the planned transform at 9,054 rows: 7.2 ms cold, 2.5 ms warm; blink's per-request shallow copy 4.8 ms |
| `envprobe.lua` | headless, one instance per file (build chat 3) | what VimTeX's env completer offers at `\begin{` and what it costs: fixture (no `.fls`) 65 names and none of french-logic's 25, the root (stale `.fls`) 179 and none, the completeness chapter (fresh `.fls`) 171 and all 25; whole-project parse 11.6 ms on the root, main-file read 0.06 ms |
| `loadprobe.lua` | headless on a document (build chat 3) | the first-request load of a buffer's closure into LuaSnip: 100 files, 7,756 rows, `loadfile` 29 ms, construction plus `add_snippets` 598 ms (68 µs a row), heap 23 → 141 MB after a full collect; stage 4 re-runs it on bigfed |
| `report.lua` | headless on a document (build chat 3) | the first `ft_func` (654 ms chapter, 763 ms root; 0.4 ms after) and `:SnippetsReport` |
| `spike5.py` | harness (build chat 3) | `:SnippetsReload` keeps every count (0.77 s) and a hand-local row shadows its generated twin; pinned by the latency suite since 2026-09-13 |
| `stage4lib.py`, `stage4_keys.py`, `stage4_first.py`, `stage4_transform.py`, `stage4_ftcalls.py`, `stage4_active.py`, `stage4_active2.py` | harness, build chat 4 (2026-09-13); the pre-campaign tree is `git -C ~/Desktop/configs archive 1bb69b1 nvim latex` extracted into a scratch directory named by `STAGE4_BEFORE` (never inside a repo) | stage 4: the keystroke bench on the live and the pre-campaign tree under one machine state (spike4's method; the line is restored explicitly, since the spike's `silent! undo` never reverted the typed text), the first keystrokes of a session and memory, the two transforms at the full row count, who calls `ft_func` per keystroke (blink's `snippets.active()`, through LuaSnip's `expandable()`), the candidate `active` and the four `<Tab>` corners in fresh instances |
| `stage4_sink.py`, `stage4_frec.py` | harness, a fresh `XDG_STATE_HOME` per condition | the sink against frecency: no effect at 0, 3, 5, 8 or 10, because `fuzzy.access` is never called for an accepted LuaSnip row (the store stays at 0 bytes) |
| `stage4_cold.py`, `coldchap.lua`, `stage4_startup.sh` | harness with a scratch `cache_root`; headless on the chapter with `g:vimtex_cache_root`; `--startuptime` on both trees | the cold package cache on the fixture and on the chapter (`\begin{` primed across sessions by `vimtex-warm`, `\usepackage{` 0.9 s once per session), startup to VimEnter, the stamp check alone |
| `widthprobe.py`, `dscr_widths.py` | harness; python3 over `pkg/` and `sty/` | an in-place change of `label_description.width.max` redraws the menu at the next request; the description-length distribution on the chapter's closure (9.9% of rows over 30 cells) |
| `stage4_backslash.py`, `stage4_twins.py` | harness, build chat 4 | the lone backslash is itself a request in both trees (21 ms old, 50 ms new; no fuzzy pass until a letter); typical and unusual twins order typical-first at sink 0 and 5 alike through blink's sort text |
