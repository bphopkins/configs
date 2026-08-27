# Insert-mode latency and the cold-cache stall (2026-08-22)

Dated record, true as of 2026-08-22; moved verbatim from the root `CLAUDE.md`
on 2026-08-26 (context-policy Stage 2). The rules that still bind — the
matchparen guard, the completion prose-gate, `vimtex-warm` and its re-warm
triggers — live in `nvim/CLAUDE.md`; this file is the investigation record.
The closed-work ledger entry is in `DECISIONS.md` (Done ledger, 2026-08-22);
the same-day second-pass audit is `nvim-audit-2026-08-22.md`.

Typing in the dissertation's long paragraph lines on `fedxps` had become slow
enough to notice. Two *separate* faults, which is why no single explanation
accounted for both symptoms.

## Fault 1 — a per-keystroke tax

Measured on `dissertation/completeness/completeness.tex`, cursor at the end of its 1860-char paragraph line, against a `nvim -u NONE` floor of **3.6 ms** on the same line:

| component | ms/keystroke |
|---|---|
| VimTeX's own matchparen | 62 |
| blink `snippets` source (1063 tex snippets reachable) | 33 |
| blink `vimtex` source via blink.compat | 26 |
| the 250 custom syntax cmd rules | 29 |
| base VimTeX syntax (946 match rules, 97 packages) | 20 |
| **total** | **212** |

Two findings worth keeping. **Neovim's built-in matchparen costs ~0 here** — it returns immediately unless the cursor sits on a bracket, which at the end of a prose line it does not; it was VimTeX's own that was expensive, and only that one is touched. And the cost is driven by **logical line length**, which in these files means paragraph length: 585ch→44 ms, 1001ch→82, 1417ch→262, 1860ch→218. Below roughly 1000 characters the config was never the problem.

Fixed in two places, both commented in situ. `vimtex.lua` switches VimTeX's matchparen off during insert via its own `vimtex#matchparen#{disable,enable}` — so `$…$`, `\begin/\end` and `\left/\right` matching survive in normal mode, where you are actually looking at delimiters. `completions.lua` gates blink's `snippets` and `vimtex` providers on `in_latex_context()`: part-way through a `\command`, or inside the braces that follow one. Result at those four line lengths: **13 / 23 / 84 / 54 ms**, a 3–4× improvement, with completion after `\command`, `\cite{` and `\ref{` unchanged and the menu no longer firing over running prose.

⚠ **The matchparen toggle must be guarded on `g:vimtex_matchparen_enabled`.** VimTeX creates its per-buffer augroup only when the feature is on, and `disable()` clears that group *by name* — so calling it with the feature off raises `E216: No such group` on **every** `InsertEnter`. This was a real bug in the first version of the fix, caught only by testing the off case; the guard plus a `pcall` backstop is pinned by a regression check.

The 250 custom syntax rules were left alone: 29 ms is the smallest of the four levers and cutting it costs semantic colour. Note this **corrects** the older standing belief that syntax complexity was the cost driver — it is about 14% of the bill.

**Fault 2 — the cold-cache stall.** Separate, one-shot, and much larger: **22.8 s on a single `\` keystroke**, reproduced live. See below.

## Fault 2 — the cold-cache stall

VimTeX resolves every `\usepackage`'d package by spawning `kpsewhich`, then reads the `.sty` it finds, caching both under `~/.cache/vimtex` (`kpsewhich.json`, `pkgcomplete.json`). The completeness chapter's article root pulls in **97 packages**, and on `fedxps` one `kpsewhich` spawn costs ~190 ms — which is *process startup*, not the lookup: `kpsewhich --var-value TEXMFHOME`, which looks nothing up, costs the same. 190 ms × 97 ≈ 18.4 s.

Measured: **18,676 ms for the first `\command` completion with a cold cache, against 235 ms warm**; live on the real chapter it was 22.8 s. It is paid synchronously on the **first backslash you type in a session**, which is why it reads as "I typed `\textit` and waited several seconds" and why it is invisible to any benchmark run after the first.

The cache is plain JSON **on disk**, so it survives logout and reboot, and `vimtex#kpsewhich#find` returns a cached hit **unconditionally — it never re-validates the stored path**. So the cost is per package, per machine, *once*. It recurs only on genuinely new packages, a new machine, or `:VimtexClearCache`.

Two things that sound like they would invalidate it and **do not**: a TeX Live release upgrade leaves the cached absolute paths resolving (and `tl-newyear switch` keeps the old tree deliberately), so the risk there is *staleness*, not slowness — if an old tree is ever deleted, `getftime` returns `-1`, which is not greater than the stored ftime, so VimTeX keeps serving the old definitions rather than rescanning. And editing `french-logic.sty` costs one `.sty` re-read, not a `kpsewhich` spawn.

Remedy: `bin/vimtex-warm`. Reproduce the cold case deliberately with `nvim --cmd "let g:vimtex_cache_root='/tmp/cold'" chapter.tex`. **Both machines are warm** — `fedxps` from the original fix, `bigfed` via `vimtex-warm -a` on 2026-08-22 (`~/.cache/vimtex/pkgcomplete.json`, 561 KB). Re-warm only after `:VimtexClearCache`, deleting an old TeX tree, or a genuinely new package set.
