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
