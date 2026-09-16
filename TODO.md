# TODO List

Planned pieces of work, each big enough to want its own session. Written up in
enough detail to brief a fresh chat without re-deriving the findings — the
notes under each item come from a full repo survey on 2026-07-26. Items keep
their original numbers because other docs reference them; completed items and
their full post-mortems live in `DECISIONS.md` under those same numbers
(tracker/record split 2026-08-26 — the ## Closed ledger below is the index).

Priority for the next working day: **(3)**.

---

## 3. Overhaul the `~/.bashrc.d` cluster

- [ ] Review the whole modular bash setup for robustness.

The last remaining survey item (1 and 2 are done). The structure is sound — `.bashrc` sources
`~/.bashrc.d/*.sh` in numbered order, and everything parses. Things a review might look
at: whether `00-shell-opts.sh` should finally get real `shopt`/`set` options (history
handling, `globstar`, `checkwinsize`); whether `30-prompt.sh` should go further and
build PS1 itself, now that it colours the prompt but still inherits the string
(2026-09-14); and whether the aliases in `40-aliases.sh` still match how the machines
are actually used.

**Deliberate, not oversights:** `00-shell-opts.sh` is a *reserved empty slot*, not a
dead file; `30-prompt.sh` was the other until 2026-09-14, when it took the per-machine
prompt colours. `90-nix.sh` is **load-bearing on bigfed**, where nix has
been installed since 2025-03-05 and this file is the only thing putting it on PATH —
bigfed is the machine that builds Carnap, and the Stage 3 build ran through it.
`.bashrc.min` / `.bash_profile.min` are rescue configs.
A `~/.config/environment.d` PATH drop-in was considered and **declined** — it would
give PATH a second source of truth that wouldn't reproduce `20-path.sh`'s
TeX-Live-first ordering.

*Corrected 2026-08-17.* The `90-nix.sh` sentence above previously read "kept ready for
Carnap development even though nix isn't installed" — false when written (2026-07-26),
since nix had been on bigfed for seventeen months by then. It was written from fedxps,
where nix genuinely is absent, and generalised without checking the other machine. The
same claim appeared in `90-nix.sh` and `CLAUDE.md` and was corrected there on
2026-08-17; **this third restatement was missed by that sweep and caught a day later**,
which is the argument for the `grep -rn` step whenever a restated fact changes. Note the
failure mode is not staleness but *unverified generalisation across machines*: a
two-machine setup makes "on either machine" the easiest sentence to write and the
hardest to check.

---

## 7. A dedicated secret scan across the repos

- [ ] Build a content-based secret scan. Decide first whether it belongs inside
  `gpushall` or — the stated preference — as a separate command run across all of
  `REPOS_DESKTOP` on its own schedule.

Raised 2026-08-17 out of a full public-exposure audit of this repo (all 138 tracked files,
the working tree, and all 89 commits / 376 blobs of history). **The audit found nothing to
remove as of that date**: no key, token, JWT, IP, MAC, phone, address, student data, or
third-party PII had been committed, in HEAD or in history. This item is about the
*mechanism*, not a spill. One instance has landed since, and it is what the mechanism would
have caught: `f5cc9df` (2026-09-03) committed nousowl's private LAN address in
`docs/ghostty-vs-wezterm-2026-09-03.md`, redacted in the working tree 2026-09-14 but **still
present in `HEAD` and on the public remote** until that redaction is committed. Non-routable,
so nothing to rotate and no history rewrite is warranted — but do not read the sentence above
as a standing claim about the repo.

**The gap, precisely.** `_gsync_vet_new_files` lists staged paths with

```
git -C "$repo" -c diff.renames=false diff --cached --name-only --diff-filter=AT -z
```

`AT` is **Added + Typechanged**. Modifications (`M`) to already-tracked files are never
vetted — no size check, no glob check, no prompt. So a secret pasted into `CLAUDE.md`
(78 KB of constantly-churning prose), `TODO.md`, or any `bash/.bashrc.d/*.sh` commits and
pushes to a public remote in silence. Given this repo's file mix, that is the most
realistic remaining leak path.

**Do not "fix" it by adding `M` to the diff-filter.** The vet matches *filenames* against
`GSYNC_SECRET_GLOBS`, and a modified file's name has not changed — it was already vetted
when it was added. Re-globbing it every run buys nothing and would prompt on ordinary
edits. Closing this needs a different instrument: a scan of the *content* of the staged
diff.

**Shape of the remedy, when it is built.** Scan added lines only (`diff --cached -U0`,
`^+` minus `+++`) for high-signal patterns, and keep the list tight so it stays
false-positive-free enough to be trusted: `BEGIN [A-Z ]*PRIVATE KEY`, `BEGIN CERTIFICATE`,
provider prefixes (`ghp_`, `gho_`, `github_pat_`, `sk-ant-`, `sk-`+20, `AKIA`, `AIza`,
`xox[abprs]-`, `glpat-`), JWTs (`eyJ` + two more dot-separated b64 segments), and
`Authorization:\s*(Bearer|Basic)`. Prompt with the same `[[ -t 0 ]]`-gated y/N flow as the
existing vet, and fail the same way it does — **closed**, refusing the commit if the
listing itself errors. Extend `tests/gsync/` in step; note that a naive fixture will trip
the scanner on the test file itself, which is exactly the false-positive shape to design
against.

**Two things already decided (2026-08-17), so they need no re-litigating:**

- **`.gitignore` is the cheap second layer, and it was taken.** It had only the three
  path-specific rules and now carries generic hygiene groups. That was not speculative:
  `init.el~` (2025-10-30), `sway/config.save` (2025-11-09) and two nvim `*.bak` files
  (2026-03-19) had *already* been committed and published by `git add -A`, and are still
  in history. Ignore rules refuse where the vet only prompts, and they cover the
  modified-file gap the vet structurally cannot see — but only for whole files, never for
  a secret inside a legitimate one. Hence this item.
- **The preference is a dedicated scan over `REPOS_DESKTOP`, not a `gpushall` bolt-on.**
  `gpushall` is already the most safety-critical function here, guarded by 168 checks;
  growing it has a cost. A separate command can also be run on demand and against repos
  that are not being pushed.

**Worth folding in while there:** `GSYNC_MAX_MB` is env-overridable, so a stray value in
the environment silently relaxes the size guard (a non-numeric one already warns and falls
back to 25; a numeric one does not). And the audit's other standing note — `~/.bashrc.d`,
`~/.config/nvim/{lua,after}`, and each `~/texmf/tex/latex/<pkg>` are whole-**directory**
symlinks into this repo, so anything a tool writes under those paths lands in the working
tree with no further step. All are clean today.

---

## 10. `gpullall`'s restow hint cannot see a *new* stow package

- [ ] Build the package list for the post-pull hint from the repo's directories
  on disk rather than from the in-memory `STOW_ORDER`, and add a regression test
  that adds a new package directory and asserts the `stow-all` hint fires.

Found 2026-09-03 by exercising the workflow end to end: a `configs` pull on
bigfed that added the new `ghostty` package printed only
`[HINT] configs: bash files changed — run: source ~/.bashrc`, and never
mentioned `stow-all`.

**The gap, precisely.** In the post-pull hint classification loop
(`50-git-sync.sh`, around line 311):

```
local -A is_pkg=() pkg_hit=()
if declare -p STOW_ORDER >/dev/null 2>&1; then
  for p in "${STOW_ORDER[@]}"; do is_pkg[$p]=1; done
fi
...
[[ -n "${is_pkg[${p%%/*}]:-}" ]] && pkg_hit[${p%%/*}]=1
```

`is_pkg` comes from `STOW_ORDER` **as loaded in the running shell**. A brand-new
package is by definition absent from that array, because the pull that added it
has only just updated `60-stow.sh` on disk. So `ghostty/config` classified as
"not in a stow package", `pkg_hit` stayed empty, and the hint could not fire.

This is the same in-memory-versus-disk trap `stow-all` itself has — documented
in the root charter — reappearing one layer up, in the tool built to warn about
it. And it misses **exactly** the case that matters: the hint is reliable for
changes to *existing* packages and structurally blind to a *new* one, which is
the only case where forgetting to restow fails silently.

**Why it did not bite.** Adding a package requires editing `60-stow.sh`, which
lives in `bash/`, so `bash_hit` fired and produced the re-source hint. That
coupling is luck, not design, and the hint says `source ~/.bashrc` and stops —
followed literally, the new package is never linked.

**Why the suite did not catch it.** `test-gsync.sh:129` and `test-audit.sh:10`
both `source` the current `60-stow.sh`, so `STOW_ORDER` is always fully
populated, and every stow-hint assertion adds files to an *existing* package
(`bash/.bashrc.d/95-added.sh`, `test-audit.sh:249`). No test has ever introduced
a new package directory.

**Proposed fix.** Populate `is_pkg` from the repo's top-level directories after
the pull — every entry except the known non-packages (`docs`, `tests`,
`wallpapers`, `.git`) — optionally unioned with `STOW_ORDER`. It degrades in the
right direction: an unrecognised directory yields a spurious hint at worst,
never a missing one. Run `tests/gsync/run-all.sh` after.


## 12. The fontconfig duplicate-rejection over-rejects

Found 2026-09-07 in the home-directory audit, after `dejavu-sans-fonts` left
fedxps as a Thunderbird dependency and took the only visible DejaVu Sans with
it. `fontconfig/conf.d/09-texlive-fonts.conf` block (1) rejects whole TeX Live
directories on the premise that Fedora packages the same families. Measured at
the family level on both machines (`fc-scan` of each rejected directory, then
`fc-list ":family=…"` for every family it yields), the premise fails for part
of several directories:

- **Invisible on both machines:** DejaVu Sans Mono and DejaVu Serif (Fedora
  splits DejaVu into three packages and only `dejavu-sans-fonts` is installed),
  Montserrat Alternates, Open Sans Condensed and Condensed Light, STIX Math
  (the `stix` directory is STIX 1; Fedora's `stix-fonts` is STIX Two), and
  fifteen RIT Malayalam families (Fedora has only Meera New and Rachana).
- **Invisible on fedxps only:** Latin Modern Math and MnSymbol (bigfed has the
  `texlive-lm-math` and `texlive-mnsymbol` rpms; fedxps has Latin Modern
  *text* from a user font dir, `~/.local/share/fonts/latinmodern`, and nothing
  for math), Courier 10 Pitch, and FontAwesome 4 (bigfed has
  `fontawesome4-fonts`).

Three ways out, not decided:

1. **Narrow the globs to the files whose families Fedora provides** — reject
   `DejaVuSans*.ttf` but not Mono/Serif, `Montserrat-*` but not the Alternates,
   and drop `stix`, `courierten` and `rit-fonts` from the list. Keeps the
   package machine-independent; the snapshot needs re-measuring after each TeX
   Live release.
2. **Install the Fedora packages the premise assumes, on both machines** —
   `dejavu-sans-mono-fonts`, `dejavu-serif-fonts`, `texlive-lm-math`,
   `texlive-mnsymbol`, each `dnf mark user`. Makes the premise true and settles
   the Latin Modern two-mechanisms question in the rpm direction (the user font
   dir on fedxps then goes). STIX 1, Open Sans Condensed, Montserrat Alternates
   and the RIT set have no Fedora package, so those globs still need option 1.
3. **Accept** the missing families as unused. DejaVu Sans Mono argues against
   this: it is a common monospace fallback.

The measurement is one loop; rerun it on both machines before and after any
change, and after each TeX Live release. Cross-listed in
`org/machines/machines.md` under the Latin Modern item.

## 14. french-logic: deferred, for when the dissertation needs them

Two items the reorganisation campaign (item 13, closed 2026-09-08) declared
out of its scope, and one fine-tune from its confirmation pass. None is broken;
handle each when a document asks for it, through the two nets (`tests/french-logic/run.sh` and the private harness in
`org/claude-config/repos/configs/french-logic-harness/`).

- [ ] Derive `dissertation-template/philogic.sty` from the units instead of
  maintaining it apart. It is the template's one deliberate bundled `.sty`; a
  derivation would be a script over the unit files with the template's trims
  applied, proved by building the template against both.
- [ ] One command for a dyadic connective that spaces itself by context.
  Today `\cnecs` (use, between sentences, padded by hand inside the builder
  `\fl@dyad`) and `\cnecsolo` (mention, unpadded) are two members, and the
  same for `\cobs`/`\cobsolo` and `\cposs`/`\cpossolo`; Brandon said on
  2026-09-08 that one name should do both if there is a natural way. The
  natural mechanism is one `\mathrel` box around the glyph, so that TeX's
  relation spacing applies in use and nothing at the ends of a formula; what
  it needs is a measured comparison of that spacing against the tuned
  paddings (3.5mu left, 2.75mu right) on the use sites — `\cobs` alone has
  745 — with the `\xspace` question for prose considered beside it, since
  these names are math-only today.
- [ ] Fine-tune the decorations' tuck. The ten decorated sets (`\truthsetm`
  and kin, `\proofsetl`, `\eclassl`) carry `\mkern-3mu` inside the script
  since 2026-09-08, the old gap measured within a pixel at every size; Brandon
  suspects −2 mu is the optimum. Rows K3 and K2 of the type board's section
  11.1 are photographed for the comparison; judge by eye, land through both
  nets (24 dissertation pages move by hair widths either way).

---

## 16. Key-value completion inside `[…]`

- [ ] Build a small custom blink source for key-value completion inside a
  command's optional argument, fed by the `keyvals` field of the generated
  snippet files; give the stage-1 empty-file rule its third case, so the 77
  keyvals-only cwl files are generated too.

Deferred by the LaTeX completion campaign
(`docs/latex-completion-campaign-2026-09/PLAN.md`, section 6; closed
2026-09-13). The generated files under `nvim/lua/snippets/pkg/` keep every
`#keyvals` block raw, as a fifth field keyed by the block's target text: 2,900
cwl files carry blocks, 109,547 lines, 1.9 MB raw; in the dissertation's
closure 4,486 keys for 178 targets. Snippets are the wrong instrument for them
– a key is completed mid-argument, inside `[…]`, against the command it belongs
to – so this is a third gate in `completions.lua`, inside the brackets that
follow a command, where neither present gate opens and VimTeX's completers
offer nothing, and a small source of our own reading the sidecar. The stage-1
rule skips any cwl file with neither a row nor an `#include` outside option
blocks, and 77 of the 104 files it skips hold only `#keyvals` blocks (lmodern,
fontenc, tikzlibrarypositioning among them); this tier wants them, so the rule
needs a third case, a regeneration (`snipgen.py --all`, where the clone is) and
a `tests/snipgen` check. The latency suite gains the gate's pins.

---

## 17. A comment convention in the `.sty` for `snipgen.py --sty`

- [ ] Design a comment convention in the french-logic `.sty` files that
  `snipgen.py --sty` reads: named placeholders for the package's own commands,
  a math-only mark, and a declared arity where the definition does not carry
  one (`\poscite`).

Deferred by the completion campaign (PLAN.md section 6). Three gaps with one
shape. The cwl rows name their placeholders (`{num}{den}`); the `.sty` front
end reads a definition's arity only, so 99 of french-logic's 100 bare command
rows have unnamed `{}` stops. A `\newcommand` carries no classification, so
only the three `\DeclareMathSymbol` rows (`\Yright`, `\shortminus`,
`\strictif`) are math-wrapped by construction, and every other math-only member
expands bare in prose where a cwl `#m` row is wrapped in `$…$`. `\poscite` is a
`\DeclareCiteCommand`, its arity `[pre][post]{key}` biblatex's and absent from
its definition, so it is not completed at all (as before the campaign). A
comment beside each definition, in a form the generator reads and TeX ignores,
serves all three; `tests/snipgen` gets fixture rows for it, the startup check
regenerates `sty/` at the next Neovim start, and the `.sty` edits go through
both french-logic nets (`tests/french-logic/run.sh` and the private harness),
as every edit there does. Related: item 14.

---

## 18. The unusual-row prior: the marker's position, and ranking from his corpus

- [ ] Decide whether the `∗` that marks a TeXstudio "unusual" row goes before
  the shape in the description column rather than after it, so that a cut never
  removes it: a generator change and a full regeneration.
- [ ] Ranking from his corpus frequency as a generator input, in place of the
  `#*` prior.

Deferred by the completion campaign (PLAN.md sections 6 and 8). The `#*` flag
is a cwl author's guess at typicality; his usage of unusual-marked commands is
half a percent of stock tokens, all preamble plumbing, so the flag stays in the
data and a small static sink (5, under the provider's offset of 10) breaks
ties. Two facts measured at stage 4 bound the design. The description column is
45 cells, 2.3% of the completeness chapter's rows are still cut, and the `∗` is
the last character, the first thing a cut removes. And blink's frecency never
sees an accepted LuaSnip row (`fuzzy.access` is never called for one; the store
stayed at 0 bytes across every probe), so usage-based order cannot come from
the menu and the generator is the only route; `spikes/usage.py` in the campaign
directory already classifies every command he types over the dissertation,
which is the input.

---

## 19. Bare lists for packages with no cwl

- [ ] Autogenerate a bare snippet list from the `.sty` or `.cls` of a package
  that has no cwl, found through kpsewhich, as TeXstudio does for a package
  without a word list.

Deferred by the completion campaign (PLAN.md section 6). His own classes
(mod-cv, eptcs, deon16) and the old documents on bigfed name packages with no
file under `pkg/` or `sty/` and get nothing for them; `:SnippetsReport` lists
such names under "missing". The `.sty` front end already parses definitions
with arity, so this is a lookup (`kpsewhich <name>.sty`, about 190 ms a spawn
on fedxps in power-saver mode, measured 2026-08) plus a run of the same parser,
cached as a generated file. The design question is where the output lives:
`pkg/` is covered by `NOTICE` (GPL-3 data from TeXstudio) and pruned by
`--all`; `sty/` is pruned by the sourceless-file rule of `--sty --check`, which
removes a file whose header names a path that no longer exists, so a
kpsewhich-found path would survive there until the tree it points into is
deleted. A third directory, or a per-machine cache outside the repo, are the
alternatives.

---

## 20. The latency harness's hygiene

- [ ] Give `tests/nvim-latency/harness.py` a scratch VimTeX `cache_root` and a
  scratch `XDG_STATE_HOME` by default, the cache seeded from the live one, so a
  run leaves the live state untouched.

Found at stage 4 of the completion campaign (PLAN.md section 5, the last
hazard). Each harness instance writes a `bibcomplete%tmp%…` file into the live
`~/.cache/vimtex` (eight found 2026-09-13), and its accepts feed the live blink
frecency store (`stdpath('state')/blink/cmp/frecency.dat`), shada and undo
history. The stage-4 probes isolated both per instance (`spikes/stage4lib.py`:
`XDG_STATE_HOME` for state, `g:vimtex_cache_root` for the cache) and it works;
making it the harness's default asserts nothing new, so no check changes. One
thing to design for: a scratch cache root is cold, and the `\begin{` checks
would then pay VimTeX's kpsewhich scan in every instance (356 ms on the
fixture, one package in its table), so copy the live `~/.cache/vimtex` into the
scratch root per run rather than starting empty. The suite's README records why
each check exists; record the hygiene there.

---

## 21. A bench sitting for the five stray colours

- [ ] Exhibit on the bench (`nvim/docs/latex-register-taxonomy.md`, the Status
  section) the five theme colours that leak into TeX highlighting unassigned,
  and land what he accepts.

Found 2026-09-12
(`docs/latex-completion-campaign-2026-09/comparison-2026-09-12.md`, section
1.4) and kept out of the completion campaign by his rule: the register taxonomy
changes only from instances he brings, exhibited on the bench before the config
is touched (`nvim/CLAUDE.md`). The five: TokyoNight's Special reaches 19
groups, among them `&` and `\\` in align and tabular (`texTabularChar`;
TeXstudio gives alignment points a deliberate bold blue), math environment
names (`texMathEnvArgName`, so `align` is cyan while `proof` is mint and
`tabular` teal, and the family matches in `after/syntax/tex.lua` never see
them) and `#1` parameters (`texNewcmdParm`); `texLength` resolves to Constant;
the todo groups to Todo; the error and warning groups to red and amber,
arguably right. All are retunes within existing species, no new genus:
alignment furniture is pure structure, math environment names belong to the
env-name family. Suite: `tests/nvim-syntax/run.sh` after.

---

## 22. The wheel's lag and overshoot

- [ ] Decide whether `mousescroll`'s `ver:` value should come down from 3, and
  whether anything can be done about the input backlog itself.

Measured on bigfed 2026-09-15, the half of that day's scroll work that was
left open — see `nvim/CLAUDE.md`, "Scroll cost, and the CTRL-D step", and the
`DECISIONS.md` section of the same date. `mousescroll=ver:3` gives **3 display
rows per scroll *event***, and his MX Master reports `REL_WHEEL_HI_RES`, so
libinput subdivides one physical detent into roughly three events — about ten
display rows per notch, which is what he reported feeling.

The complaint is not the distance but the lag and the overshoot, and that is an
input backlog: 60 wheel events sent in 70 ms took **951 ms to drain** with
syntax on and 344 ms with it off, so Neovim services about **63 wheel events a
second** in a TeX buffer, ~190 display rows/s. The MX Master's free-spin wheel
outruns that by a wide margin, the queue grows for as long as the flick lasts,
the view keeps travelling after his hand stops, and it lands at an end of the
document. Nothing coalesces the events – every one is serviced.

snacks.scroll is not involved: it deliberately skips animation for wheel input,
so this is mechanically distinct from the keyboard judder, though both are paid
for out of the same 4.65 ms/screen row of syntax.

What to weigh when it is picked up: a lower `ver:` cuts rows per event but not
events per second, so it shortens the overshoot without fixing the lag; the
free-spin/ratchet switch on the mouse itself is a hardware lever that costs
nothing to try first; and whether a debounce is even expressible here is
unknown — Neovim has no scroll-event coalescing to hook.

---

## 23. Multi-line paste arrives a line at a time under `TERM=xterm-ghostty`

- [ ] Find out why a pasted block splits at its newlines, and decide what, if
  anything, to change here.

Raised 2026-09-15. Pasting a block of commands into Claude Code's prompt in
Ghostty raised Ghostty's unsafe-paste dialog, and on confirming, each line was
submitted as its own message.

Half of it is closed. `clipboard-paste-protection = false` in `ghostty/config`
removes the dialog, and the dialog was only ever a report of the condition:
Ghostty asks when a paste carries a newline and the program reading input has
not enabled bracketed paste mode. Silencing the report leaves the split
untouched.

**Upstream.** `anthropics/claude-code#54700`, "Multi-line paste fails in
Ghostty 1.3.x with TERM=xterm-ghostty (works after switching to
TERM=xterm-256color)". Reported at Claude Code 2.1.123 against Ghostty 1.3.1,
regression traced to ~2.1.119, whose changelog carries "Fixed multi-line paste
losing newlines in terminals using kitty keyboard protocol sequences inside
bracketed paste". Closed as **not planned**; present here at 2.1.273. Their
diagnosis is that Claude Code takes a kitty-protocol-aware paste tokenisation
path when TERM is `xterm-ghostty`, and that path mangles the paste.

Measured here the same day, the one factual error in that report and why the
diagnosis survives it: they say `xterm-256color` declares neither bracketed
paste nor the kitty extensions. On Fedora both entries declare `BE`/`BD` – the
whole discriminator between them is `fullkbd`, which is the kitty keyboard
capability, so the report points at its own cause more squarely than it knows.

**Untested workaround:** `TERM=xterm-256color claude`, which would live on the
`cc`/`ccf` aliases in `bash/.bashrc.d/40-aliases.sh`. It costs Claude Code's
TUI the kitty keyboard protocol, so extended key reporting — shift+enter and
its neighbours — changes inside it. Try it before adopting it.

**A separate finding, unexplained, relevance unknown.** On nousowl the login
shell sshd starts emits `\e[?2004h` under `TERM=xterm-256color` and never
under `TERM=xterm-ghostty`; four reproductions off the raw pty stream. Ruled
out by measurement: the entry's content (nousowl's `~/.terminfo` copy is
byte-identical to bigfed's RPM entry), its `BE`/`BD` capability, the lookup
path, the rc chain, login vs non-login, `-t` vs `-tt`, and termcap-buffer
truncation (xterm-ghostty's termcap form is 1053 bytes against
xterm-256color's 1086, and its compiled entry is the smaller of the two).
Every bash started by hand over that same connection enables bracketed paste
under `xterm-ghostty`; only the shell sshd starts does not. ⚠ Caveat that
wants clearing first: this was measured through a bare Python pty with nothing
at the far end to answer terminal queries, which is not a real Ghostty window.
Re-measure in one before treating it as a fact about live use.

⚠ The Clipboard comment in `ghostty/config` gives the cause of that nousowl
finding as `ssh-terminfo` installing only into the login user's
`~/.terminfo`, leaving nested contexts without it. That was measured wrong the
same day: the entry is present for the login user and bracketed paste is off
regardless. The comment stands as written by request — correct it when this
item is picked up.

---

## Notes

- From the 2026-08-09 git-sync audit (item 4's gpushall question), two observations,
  deliberately not acted on absent a concrete failure: the five network git calls in
  `50-git-sync.sh` have no timeout beyond the 4s TCP probe of `github.com:22`, so a
  connection black-holed *after* the probe hangs — silently at the `>/dev/null 2>&1`
  sites; and `git commit -m` in `_gsync_push_repo` is the one place a future
  pre-commit hook could recreate the dnf-style invisible prompt (captured stdout +
  live terminal stdin) — `</dev/null` there is free insurance if hooks ever appear.
- `markdown-preview.nvim` is pinned to commit `a923f5f` (2023-10-17). That is not a
  stale pin — it is the newest commit upstream has ever had; the project was abandoned
  in October 2023. Nothing to update. It works today; if a future Neovim release breaks
  it, the replacements to look at are `render-markdown.nvim` or `peek.nvim`.
- Desktop typography under Sway, surveyed 2026-08-13. The bar and the launcher were
  brought in line; the rest was **deliberately left alone**. There is no XSettings daemon under sway, so GTK3 apps read gsettings
  directly (`Adwaita Sans 11`) and agree with each other — but anything shipping its own
  stylesheet does not participate. `wofi` ($mod+a) *was* the worst outlier — no config at
  all, running on compiled-in defaults — and got its own stow package the same day
  (palette + Source Code Pro matching Waybar; see `wofi/CLAUDE.md`). mako and swaylock still
  fall back to their own defaults for fonts, which has not mattered in practice. Judged too big to
  fold into a config pass; it is a design question, not a config sweep. Waybar was
  monospaced (Source Code Pro, matching the terminals) on its own merits — see `waybar/CLAUDE.md`.
  Note the Wi-Fi tray icon can never join in: it is an SNI *icon* painted by `nm-applet`
  from the Adwaita icon theme, not text, so no font setting reaches it. Replacing it with
  waybar's text `network` module is possible but `nm-applet` must keep running regardless
  — it is the 802.1x secret agent — so that would add a text indicator without removing
  the icon.
- Alacritty carries font settings only, no colourscheme, so it is the one terminal not
  on TokyoNight. Deliberate or not, it's a one-block fix whenever wanted.
- `wallpapers/monarch1080.png` (2.0 MB) and the five solid-colour PNGs are referenced
  nowhere; only `monarch1080dark.png` is used (by `sway/config` and the GNOME
  background). ~3.6 MB of the repo's 9.2 MB is this directory, which is not a stow
  package.

## Closed

One line per closed item — verdict, date, pointer. Full notes and post-mortems
are in `DECISIONS.md` under the same item numbers.

- **1. Git-sync overhaul** — collapsed into shared per-repo helpers with vetting and
  guards; 153-check suite. Closed 2026-07-26 → `DECISIONS.md`, Done ledger.
- **2. french-logic ↔ Neovim optimization** — 504/509 coverage, three latent VimTeX
  bugs fixed, self-regenerating snippets. Closed 2026-07-26 → `DECISIONS.md`, Done
  ledger (with same-day follow-ups).
- **4. reboot-check's repo-metadata dependence** — hybrid fallback adopted; degraded
  verdicts flagged in-line. Closed 2026-08-09 → `DECISIONS.md`, Done ledger.
- **5. Sway deferred tiers** — all four tiers done; idle timers and screen blanking
  stay declined. Closed 2026-08-13 → `DECISIONS.md` item 5.
- **6. Sway binding grammar** — the modifier-names-the-target law adopted; container
  tier dropped. Closed 2026-08-22 → `DECISIONS.md` item 6.
- **8. Gradually perfect the generated snippet libraries** — closed by the
  completion campaign: the two libraries retired, the generated files
  (`nvim/lua/snippets/pkg/`, `sty/`) never hand-edited, a systematic fix a
  generator change, a one-off a shadowing row in `hand/local.lua`. Closed
  2026-09-13 → `DECISIONS.md`, "nvim/LaTeX: completion rebuilt on TeXstudio's
  model" (2026-09-13).
- **9. live-server root wrapper** — explicit directories at both ends plus
  `last_root`; simpler shapes measured lossy. Closed 2026-08-22 → `DECISIONS.md`
  item 9.
- **11. Per-window cgroup scopes after the Ghostty launcher change** — confirmed:
  one process per window means the window *is* the cgroup, so `linux-cgroup =
  always` stays declined. The item's *reasoning* needed correcting — `systemd-oomd`
  is inactive here, so the cgroup-level reaper it assumed is not running; the
  verdict survives on other grounds. Closed 2026-09-05 → `DECISIONS.md` item 11.
- **13. french-logic: the map, the unit split, the rendering suite** — a hub over
  fourteen units, two nets, the map and the generated inventory, 59 renames, every
  unit ordered, v1.0 released. Closed 2026-09-08 → `DECISIONS.md` item 13; the
  three briefs in `docs/french-logic-campaign-2026-09/`.
- **15. Completion gate: the brace branch** — two gates now: snippets while a
  command name is typed, VimTeX's completers through blink's omni provider
  inside its braces; `\begin{` writes the environment template, the exact
  output pinned. Closed 2026-09-13 → `DECISIONS.md`, the same 2026-09-13
  section.
- Unnumbered closed work (the 2026-08-22 latency fix, lock/notifications, the sway
  restructure, the `scripts` repo retirement, the 2026-07-26 staleness sweeps,
  earlier setup) → `DECISIONS.md`, Done ledger.
