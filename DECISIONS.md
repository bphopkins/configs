# Decisions — configs

Dated record — the closed-work ledger for this repo, created 2026-08-26
(context-policy Stage 2) by moving `TODO.md`'s completed items here. Numbered
headings keep their original TODO.md item numbers, which code comments and
other docs cite — "item 6" means the same item in either file. Entries are
never rewritten, only annotated; new entries are appended at the end with
their date. References to `CLAUDE.md` sections inside the moved text predate
the 2026-08-26 decomposition of the root charter; that content now lives in
the per-package charters and `docs/`.

---

## 5. Sway config: the deferred tiers — COMPLETE 2026-08-13

- [x] All four tiers done, verified from inside a live Sway session. @done(2026-08-13)

Kept rather than folded into Done because the per-tier notes below record *why* things
were done the way they were, and the declined list at the foot is the part most likely to
be re-proposed by a future session. From a full inspection on 2026-08-13.

**Tier 1 — lid/lock. DONE 2026-08-13**, see the Done entry. Screen blanking and idle
timers remain **declined**. One follow-up if a timer is ever added after all: pair it
with `for_window [app_id=".*"] inhibit_idle fullscreen`, or a fullscreen talk will lock
mid-presentation.

**Tier 2 — `focus parent`. DONE 2026-08-13.** `$mod+p` walks up the tree, `$mod+Shift+p`
(`focus child`) comes back down; the pair is bound because parent alone leaves you
steering back with direction keys. `$mod+v` remains deliberately free. *(Superseded
2026-08-22: the pair — and the splits — were dropped with the whole container tier;
see item 6.)*

**Tier 3 — screenshots. DONE 2026-08-13.** `Print` full-screen->file, `Shift+Print`
region->clipboard, `$mod+Print` region->file.

Two findings baked in. **The cancel guard is load-bearing:** written the obvious way as
`grim -g "$(slurp)" - | wl-copy`, pressing Esc leaves an empty geometry, grim fails, and
wl-copy still runs with empty stdin — silently **wiping the clipboard**. Testing both
slurp's exit status and the resulting string means a cancelled screenshot changes nothing;
verified with stub slurps for both the cancel and success paths.

**The destination is not redirectable from bash.** grim honours `GRIM_DEFAULT_DIR`, but
the `XDG_PICTURES_DIR` *environment variable* is ignored — setting it to a scratch dir
still wrote to `~/Pictures`, so grim reads `~/.config/user-dirs.dirs` instead and the man
page's "falls back first to `$XDG_PICTURES_DIR`" names the value, not the variable. And
exporting `GRIM_DEFAULT_DIR` from `bash/.bashrc.d` would not reach the keybinding anyway:
sway's children inherit the *session* environment, not an interactive shell's — the same
trap documented for `okular-inverse`. Redirecting it would mean naming a path in
`sway/config`. Left at `~/Pictures`.

**Tier 4 — DONE 2026-08-13.** `$mod+Tab` -> `workspace back_and_forth` (the third motion
the `$alt` prev/next pair left missing). `client.urgent` now uses `$urgent` `#d08770`, so
sway finally matches Waybar, mako and swaylock — one urgent colour desktop-wide. Waybar's
battery gained `states` (warning 20 / critical 10) with CSS classes, plus **notifications
via waybar's own `events` mechanism** — no daemon, no timer, because the module already
polls; critical fires at `urgency=critical`, which mako keeps on screen until dismissed.
Two incidental fixes found while there: the battery format used `{icon}` with no
`format-icons` array, so it rendered nothing (dropped — this bar is deliberately all
plain text); and the clock's `interval` defaulted to **60**, polling on the minute, which
is why `%T` showed `00` seconds forever under Sway while GNOME ticked. `interval: 1`
fixes it — verified by diffing two `grim` captures of the clock region 1.6 s apart.

A follow-on from that: with seconds now visible, the centred clock **jittered** once a
second, because the default proportional font renders different digits at different
widths (measured 145 <-> 146 px) and `modules-center` turns a width change into
horizontal movement. Fixed with `font-feature-settings: "tnum"` on `#clock` — tabular
figures, so every digit has one advance width; re-measured as a constant 155 px at a
constant offset across 8 consecutive seconds. Two things learned doing it, both now in
`CLAUDE.md`: GTK3 **rejects** the CSS-spec form `"tnum" 1` and knows nothing of
`font-variant-numeric`; and **a CSS parse error makes waybar exit silently**, leaving
sway with no bar and nothing in the journal but `Using CSS file …`. Parse-check
`style.css` before every reload.

**Not a gap, checked 2026-08-13:** `xdg-desktop-portal-wlr` *is* installed (it is a
libexec binary, so `command -v` misses it) and Fedora ships
`/usr/share/xdg-desktop-portal/sway-portals.conf` routing ScreenCast/Screenshot to wlr —
screen sharing will work. mako is installed and D-Bus-activated
(`fr.emersion.mako.service`), so notifications need no `exec` line.

**`seat * xcursor_theme`: investigated and struck, 2026-08-13.** It was on Tier 4 on the
theory that XWayland clients fall back to an unthemed X cursor. Tested live by running
the *same* binary on both backends (`alacritty` vs `env -u WAYLAND_DISPLAY alacritty`,
which is the way to force XWayland here) — **the cursors are identical**. The reason is
structural, so it is stable: Adwaita is the only cursor theme installed, and
`/usr/share/icons/default/index.theme` has `Inherits=Adwaita`, so the unnamed `default`
theme that both paths resolve lands on the same theme either way; `XCURSOR_SIZE=24` is
set session-wide. Nothing to fix unless a second cursor theme is ever installed. (Unrelated
observation from the same test, deliberately not pursued: the XWayland Alacritty renders
its font larger. `Xft.dpi` is unset and output scale is 1.0, so the likely cause is X11
clients deriving DPI from the panel's EDID physical size rather than assuming 96 —
unverified, and moot while every app in use is native Wayland.)

**Regression suite added 2026-08-13:** `tests/desktop/run.sh`, 24 checks, mutation-verified.
It guards the four silent-catastrophic failure modes this work uncovered (waybar CSS typo
kills the bar; unknown swaylock key means no lock; `sway --validate` skips binding command
bodies; mako/wofi unknown keys), plus the cross-config wiring that nothing else holds in
place. Run it after touching sway, waybar, swaylock, mako or wofi.

**Considered and DECLINED 2026-08-13** (asked and answered, do not re-propose):

- *Clipboard persistence* (`wl-clip-persist` / `cliphist`) — has never actually been a
  problem in practice, and is not worth running a daemon for.
- *Multi-monitor bindings* — sway has never been used with multiple monitors; the one
  attempt was on `bigfed`, which has been abandoned as a sway machine.
- *`for_window` floating rules* — no misbehaving dialog was ever demonstrated, so there is
  nothing to fix yet. The `inhibit_idle fullscreen` half only applies if idle timers are
  ever adopted, which they are not.
- *A clock on the lock screen* — wanted, but mainline swaylock cannot do it (see the
  swaylock note in `CLAUDE.md`); `indicator-idle-visible` was taken instead.

---

## 6. Impose an explicit logic on the sway keybindings — COMPLETE 2026-08-22

- [x] Grammar adopted, header rewritten to state it, config brought into line, both
  gates green. @done(2026-08-22)

Kept with full notes because the reasoning is the deliverable here: the law, the one
move it cost, the tier it deleted, and the reversals a future session would otherwise
re-litigate. The 2026-08-13 measurements the item opened with (plain `$mod` 32 /
`$mod+Shift` 24 / `$mod+Ctrl` 3 / `$mod+$alt` 8; Shift already ~79% "take the window
with you"; Ctrl definitionally incoherent) were the basis and held up.

**The law: the modifier names what the action acts on.** `$mod` = you — attention,
instruments, summoning (focus, workspaces, launchers, menu, scratchpad show, bar and
touchpad toggles). `$mod+Shift` = the focused window — move, send, stash, toggle
state. `$mod+Ctrl` = the session — `l` lock, `c` reload. `$mod+$alt` = the workspace
row — walk it; +Shift carries the window, so Shift's meaning composes. Two clauses
complete it: **key families override the table on their own key** (Escape = leaving,
graded by weight — the session, then the machine; Print = capture; XF86 = hardware;
the clause is forced by Print regardless, so the endorsed Escape gradient became
lawful in place), and **promotions are a stated, closed list** (`q` kill and `r`
resize: window verbs one tier light for daily frequency; a new window verb defaults
to Shift). The header now states all of this; its self-contradictory "heavier
variant" rule is gone.

**Moves: exactly one.** reload `$mod+Shift+c` → `$mod+Ctrl+c` (same letter, c =
config). Untouched: every launcher, `$mod+q` kill, `$mod+Escape` exit,
`$mod+Shift+Escape` poweroff — whose nag gained a **Reboot** button (machine actions
share the nag rather than claiming chords; the parked `#$mod+Shift+r` comment went
with it) — vim/arrow parity, `$mod+v` free.

**Dropped: the whole container tier**, user decision after its use-cases were laid
out — `splith`/`splitv` (`$mod+Ctrl+h/v`) and `focus parent`/`child`
(`$mod+p`/`$mod+Shift+p`). Splits had never been pressed intentionally, parent/child
never at all: with one or two windows per workspace, the group a parent would select
coincides with the workspace itself, and workspaces-as-the-grouping-unit is a
first-class way to run a tiling WM, not a deficiency. **This supersedes the "preserve
splits on Ctrl+h/v" constraint this item originally recorded** (item 5's Tier 2 note
is flagged too). Nothing is stranded — measured in a nested headless sway the same
day: an orthogonal `$mod+Shift+j/k` move still builds stacked layouts implicitly (two
640x720 columns → two full-width 1280x360 rows on one `move down`), which is also
where accidental vertical splits always came from. Revival chords are recorded in the
config's Layout section — plausibly relevant if a big-screen sway ever lands on
bigfed, where three-plus windows per workspace would make the tree earn its keep.

**Declined** (asked and answered, do not re-propose):

- *Re-grading the Escape column* (lock as its lightest ring, exit/poweroff one
  heavier) — the existing gradient was explicitly endorsed mid-design; the family
  clause covers it with zero moves.
- *`poweroff` → `$mod+Ctrl+Escape`* (this item's own starting hypothesis) — same
  reason: the override clause makes it lawful where it sits.
- *Rehoming `focus child`* to `$mod+i`, an out/in pair on `o`/`i`, or scope brackets —
  mooted by dropping the tier; the `o`/`i` out/in pair is the idiom-pure shape if the
  pair ever returns on letters.
- *A standalone reboot chord* — the nag button plus `reboot` in a terminal cover it.
- *A `tests/desktop` check pinning `sway/README.md` to the config's binding set* —
  declined 2026-08-22, same day the quick-reference card was added: the README is a
  best-effort courtesy that may be hand-edited or deleted at will, and a suite check
  would turn a stale doc into a failing gate, making the card an obligation on every
  binding change rather than a convenience.

Verification: `sway --validate` clean; `tests/desktop/run.sh` 24/24 (the suite adapts
to the binding set, so the dropped and moved chords needed no test edits); the
stacking claim measured, not assumed. GNOME was the live compositor, so no running
session was touched — the next sway login picks the grammar up.

---

## 9. Simplify the live-server root wrapper — COMPLETE 2026-08-22

- [x] Replaced the buffer-juggling in `nvim/lua/plugins/live-server.lua` with
  explicit directories at both ends plus one remembered string. @done(2026-08-22)

Kept rather than folded into Done because the upstream-bug record below is
referenced by the wrapper's own header comment, and the declined shapes are the
ones a future session would re-propose.

**History.** Raised 2026-08-22, off the notification "``require("live-server").setup()``
was removed in v0.2.0", seen on the first `<localleader>hh` of a session: the
plugin was rewritten under us (pin `v0.1.7-7` → `v0.3.0-3` on **2026-06-03**,
`nvim/lazy-lock.json`) and had been erroring on first use ever since — it only
surfaced then because the plugin is lazy-loaded on the command. The dead
`setup()` call and the npm `build` step were removed the same day
(`~/.local/npm-global/bin/live-server` left in place, harmless and usable
standalone). The simplification was first deferred for lack of verification,
then landed the same day after a 52-check measured comparison — old wrapper,
plain form, adopted variant, each against fixture repos, plus a read-only round
trip against the real `bphopkins.net` (fedxps, plugin pin `f1a2def`).

**Why a wrapper exists at all — confirmed, not assumed.** From a body file
under `bphopkins.net/src/`, the bare command serves `src/`, which has no
`index.html`, so the plugin falls through to its directory-listing branch:

| | served | `<title>` |
|---|---|---|
| bare `start()` from a body file | `src/` | `Index of /` |
| `start(root)` | repo root | `Brandon Hopkins' Homepage` |

**The upstream bug the design works around** (recorded here per the standing
rule; **not to be filed**). `start(dir)` keys the instance on the resolved
directory, which for a directory ends in a trailing slash (`:p`); the stop
path's upward walk strips components with `:h`, which never reproduces a
trailing slash — so a *bare* stop finds an instance only when its starting
point resolves to the stored key verbatim. Consequences, each pinned by a
suite canary: bare start serves the buffer's directory; bare stop from
elsewhere in the project silently misses an explicitly-started instance; and a
miss says nothing (`M.stop` has no else branch). The explicit form is immune —
equal input strings resolve to byte-identical keys, and the lookup probes the
exact key before walking — and it is the plugin's *documented* usage
(`:h live-server-api`), where the old wrapper leaned on the undocumented fact
that bare resolution reads the buffer's path.

**What the full investigation added: the plain 4-liner
(`stop(project_root())`) is NOT lossless.** Two losses, measured:

- *Cross-project stop.* The old wrapper stopped the server from any buffer by
  teleporting through a remembered `index.html` buffer; the plain form
  resolves wherever you are *now* — start in `bphopkins.net`, wander into
  `nousowl.net` (the stylesheet flows between exactly those repos), stop, and
  nothing happens, silently.
- *The index-less-root fallback.* Serving the root there renders a bare
  listing **and** — the Linux watch being non-recursive on the served root —
  never live-reloads anything in a subdirectory: the tool inert precisely
  where it runs. Serving the buffer's directory renders the page beside the
  buffer and keeps reload alive for its siblings. Affects no current repo
  (both sites have a root `index.html`); the old notes had marked this
  behaviour change an improvement, which the reload angle overturns.

**The adopted shape** closes both: explicit dir at both ends, `last_root` — a
string — remembered at start and used by stop, and the fallback branch serving
the buffer's directory when the root has no `index.html`. Measured
lossless-or-better against the old wrapper in every scenario, and strictly
better in three: the old buffer memory died on `:bwipeout` (silent stop-miss
that also loaded the *wrong project's* `index.html`; plain `:bdelete` it
survived — the handle stays valid, only a wipe kills it); the old `:edit`
errored outright in a `winfixbuf` window, so no server started; and the old
fallback's `lcd` permanently changed the window's cwd while every start loaded
the generated root `index.html` into the buffer list.

**Declined:**

- *Tracking the root via the `LiveServerStarted` event* instead of assigning
  `last_root` at the call site: the event's `data.root` is the realpath, the
  instance key is the `:p`-expanded path — the exact mismatch class that
  created the original bug.
- *The plain 4-liner* — the losses above, for ~10 saved lines.
- *Filing upstream* (standing rule: local record only, here and in the
  wrapper's header).

**Regression suite:** `tests/live-server/run.sh` — 27 checks, ~10 s, hermetic
(fixtures and XDG state under `mktemp -d`, loopback only on a runtime-free
port, `browser=false`, real repos untouched). W checks pin the wrapper
contract; D checks the no-repo directory semantics (next paragraph); U checks
pin the upstream behaviours above **as canaries** — a U failure after a plugin
update means the ground moved (perhaps upstream fixed its bug), not that
something broke. Mutation-verified in three directions with disjoint
fingerprints: old wrapper → W3 W8 W11 W13 W13b W13c; `last_root` dropped from
stop → W7 W8 W12b; fallback branch dropped → W10 W12 D2. Its README records
the two harness rules the mutation runs forced (pcall every wrapper call so
the summary line always prints; force-stop per section so a leaked server
cannot smear a fingerprint). Run it after editing the wrapper or after any
live-server.nvim update.

**Directory semantics, measured 2026-08-22** (same day, off the planned
`nousowl.net` → `nousowl/` move). `project_root()` resolves in order: nearest
`.git` upward from the *buffer* (`vim.fs.root`), then `git rev-parse
--show-toplevel` in *nvim's cwd*, then `getcwd()` — so outside any repo the
cwd acts as the declared root. Every leg measured, with the wrapper's branch
on top: a site subdirectory inside a repo whose root has no `index.html` (the
nousowl-move shape; fixture `projC` pins the mechanism, and a depth-2
`opsrepo/www/site/` case was measured besides) serves the *site* directory
with live-reload firing on its `index.html`; a git-less directory with
`index.html` at the cwd serves the cwd even from a subdir buffer (D1); a
git-less directory without one serves the buffer's directory (D2); an unnamed
buffer degrades to serving the cwd, because `expand('%:p:h')` on an unnamed
buffer is the cwd — measured, not `''` (D3). One inherited corner,
deliberately recorded rather than pinned: a buffer *outside* any repo while
the cwd sits *inside* a site-shaped repo serves the cwd's repo — the
`git rev-parse` leg asks about the cwd, not the buffer. Identical under the
old wrapper (same `project_root()`, same branch), and rare enough to leave.

**Interactively verified the same day** (live session, `bphopkins.net`):
`<localleader>hh` opened the browser on the served homepage and
`<localleader>hk` stopped it, including under deliberate buffer-hopping
stress — so the one path headless testing cannot reach (`vim.ui.open`) is
confirmed too, and nothing about this item remains unverified. Two adjacent
facts settled from source the same day: a stale server after a crash is structurally impossible (the server runs
in-process on `vim.uv` and dies with Neovim; `VimLeavePre` also stops all
instances), and serving *two* projects at once is broken upstream regardless
of wrapper — the second bind fails silently (`server.lua` checks neither
`bind` nor `listen`), the plugin still notifies "started", and the port keeps
serving the first project.

**Do not rediscover this and panic:** on Linux the rewritten server cannot
watch subdirectories at all (`server.lua`: `local recursive = jit.os ~= 'Linux'`;
libuv's `uv_fs_event` has no recursive mode on inotify; upstream documents it,
`:h live-server-limitations`), so only files directly in the served root
trigger a reload — `css/style.css` never will. Settled 2026-08-22 as **not a
problem here**: `make` in `bphopkins.net` always runs the phony `smarten`
target, whose script unconditionally `mv`s a rewritten temp over root
`index.html`, which fires the watcher and forces a full reload (not a CSS
injection — the changed name doesn't match `%.css$`). *Corrected 2026-08-22:*
this note previously said responses carry `Cache-Control: no-cache`; that was
the npm-era server. Measured on v0.3.0, file responses carry **no** caching
headers at all — no `Cache-Control`, no `Last-Modified`, no `ETag` — so
nothing marks the stylesheet cacheable across the reload (and CSS-only
injections bust with a `?_lr=` query regardless). Reload there is make-driven
rather than save-driven, and structurally has to be: everything hand-edited in
that repo lives in `src/`, `templates/` or `css/`, and the generated root
`index.html` is the only watched file in the tree. `nousowl.net` is the easy
case — hand-edited `index.html` at root, stylesheet a build artifact never
touched there. Noted in passing: upstream development moved to Forgejo
(`git.barrettruth.com`); GitHub is now a mirror, the pin still fetches fine —
relevant only if the mirror ever lags.

---

**Addendum 2026-09-04 — the page-load stall (upstream; recorded, not
filed).** Clicking around a site under the plugin's server, a page load
sometimes hangs for about a minute. Reproduced headlessly against
`bphopkins.net` with Chrome 152 and Brave 152 driven over the DevTools
protocol, and explained by the server's design: every response is
`Connection: close`, and every page that has the site loaded holds one
never-ending Server-Sent-Events connection (`/__live/events`). Chromium's
back/forward cache keeps the pages just left alive, streams included, and
Chromium allows six connections per host — so in one tab loads 1–5 each leave
a stream behind and load 6 has no connection to use until Chromium evicts a
cached page on its own (50 s in Chrome, 58 s in Brave, measured). Every other
tab open on the dev server holds a stream too, so tabs bring the limit
closer (three tabs: the stall arrives on load 3); a suspended or blocked
Neovim stalls the server outright with nothing to release it. With the
back/forward cache disabled the connection count stays at one and nothing
stalls; a plain static server never stalls even with six tabs open on it. The
site is not involved: production is HTTP/2 with no long-lived connections.

The proper fix is two lines in the plugin's injected client (`CLIENT_JS` in
`lua/live-server/server.lua`): close the `EventSource` on `pagehide` and
recreate it on `pageshow`, so a cached page holds no connection. Workarounds
until then: `brave://flags/#back-forward-cache` → Disabled (global, removes
the stall entirely); or, when it happens, wait about a minute or close that
tab and open a fresh one, which drops all its cached pages at once. Opening
pages in new tabs makes it worse. The wrapper cannot reach the client script,
so nothing changes in `nvim/lua/plugins/live-server.lua`.

## Done ledger (moved verbatim from TODO.md, 2026-08-26)

- [x] **Diagnosed and fixed Neovim's LaTeX editing latency on `fedxps`.** Two separate
  faults, which is why no single explanation fitted both symptoms. (1) A per-keystroke
  tax of **212 ms** at the end of an 1860-char paragraph line, against a `nvim -u NONE`
  floor of 3.6 ms on the same line — attributed by ablation to VimTeX's own matchparen
  (62 ms), blink's `snippets` (33) and `vimtex` (26) sources, the custom syntax cmds
  (29) and base VimTeX syntax (20). Fixed by switching VimTeX's matchparen off *during
  insert only* (its public API, so normal-mode `$…$`/`\begin`/`\left` matching survives)
  and gating blink's two heavy sources on being part-way through a `\command` or inside
  its braces → **13/23/84/54 ms** at 585/1001/1417/1860 chars, a 3–4× improvement.
  (2) A one-shot **22.8-second stall on the first backslash of a session**, reproduced
  live: VimTeX spawns `kpsewhich` once per `\usepackage`'d package (97 of them) and one
  spawn costs ~190 ms here — which is process *startup*, not the lookup. Remedied with
  `bin/vimtex-warm`, which pays it deliberately (`-a`: 38 documents covering all 109
  packages under `~/Desktop`, 90 s, once per machine).
  **Corrections to prior beliefs, all measured:** syntax complexity was *not* the cost
  driver (~14% of the bill, not the bulk); Neovim's built-in matchparen costs ~0 here;
  a TeX Live upgrade does *not* invalidate the kpsewhich cache (risk there is staleness,
  not slowness); and latexmk continuous does not multiply write cost (`$sleep_time` is 2 s,
  so writes coalesce). **Declined:** trimming the custom syntax rules (smallest lever,
  costs semantic colour); changing the `tuned` `powersave` profile, which is deliberate
  despite a measured 2.4× cold-clock penalty on post-pause keystrokes; and any change to
  the auto-save, whose two events turn out to be the *minimum* pair yielding "in normal
  mode ⟹ saved" — `TextChanged` does not fire on Esc, `InsertLeavePre` does not fire on
  normal-mode edits, so neither is redundant (`write`→`update` and debouncing were both
  measured/considered and rejected). New suite `tests/nvim-latency/run.sh` (26 checks,
  hermetic, mutation-verified); one bug in the first version of the fix — `E216` on every
  `InsertEnter` when `vimtex_matchparen_enabled=0` — was found by testing the off case and
  is now pinned by its own check. @done(2026-08-22)

- [x] **Tier 1 of item 5: lock before suspend** (`swaylock` + `swayidle`), plus a `mako`
  notification config — both new stow packages, both verified in a live Sway session.
  **The lock is `before-sleep` only**, with no `timeout` clause, so the no-idle-timers
  posture is structurally preserved; it exists solely to close the measured hole that
  lid-close → suspend → reopen landed on an unlocked desktop. `$mod+Ctrl+l` locks on
  demand. Verified: PAM authentication works (password unlock succeeded under a
  watchdog harness that made lockout impossible), and the lid path now locks.
  **mako:** its `default-timeout` defaults to `0` — never expire — which is why the
  NetworkManager "Connection Established" popup persisted until clicked; now 5 s, with
  `ignore-timeout=1` so a sender asking to persist forever cannot override that, and a
  `[urgency=critical]` section giving persistence back where it belongs. Both configs
  had every key validated against their man pages first, because an unrecognised key
  makes swaylock **exit** — i.e. no lock at all, a fail-open direction. Also learned and
  recorded: **sway is `fedxps`-only**; `bigfed` never boots it, which moots the
  cross-machine caveats in these packages. @done(2026-08-13)
- [x] Inspected `sway/config` end to end and restructured it for readability, plus two
  defect fixes (opened item 5 for the deferred tiers). **Verification:** `sway --validate`
  clean, and — because validate provably does *not* check `bindsym` command bodies — all
  83 bindings were additionally executed against a headless nested sway, giving zero
  parse errors; the restructure was diffed as a normalized *set* of active directives to
  prove nothing was lost (115 before, 115 after, only the intended changes).
  **Fixed:** the `$mod+Shift+Escape` poweroff nag's Cancel button did nothing — per
  `man 1 swaynag` only `-z`/`-Z` dismiss, so `-b 'Cancel' 'true'` ran `true` and left the
  bar on screen; now `-s 'Cancel'` renames the built-in dismiss button, and `-b` became
  `-B` on both nags so neither action can be routed through `$TERMINAL`. Also replaced
  the two hardcoded `/home/bph/` paths with `~` (verified sway expands it — validate
  stats the background path, so a bogus one fails rc=1 while the `~` form passes).
  **Readability:** the live touchpad block was sitting under an `# Example configuration:`
  header with more commented example below it; app launchers lived under `### Variables`;
  the trackpad toggle was orphaned flush-left in no section; a stray `# ~/.config/sway/config`
  comment pointed at exactly the file the header warns against editing. Bindings are now
  grouped by function with the binding grammar stated once at the top, every parked
  decision carries its reason inline, and a "Deliberate omissions" section records the
  declined items. @done(2026-08-13)
- [x] Decided how `reboot-check` depends on repo metadata (was item 4): adopted the
  **hybrid fallback**. Full check first (advisories are a documented input, so repos
  stay enabled); on any unparseable verdict a retry with `--disable-repo='*'` — no
  metadata, no keyring, works with zero cache — reports the core-package verdict
  visibly flagged as degraded. Exit codes stay verdict-matched (rc 2 remains "no
  verdict at all"); the degraded message shrinks its claim to its evidence ("no core
  updates or stale services since boot") and carries the failing call's stderr
  excerpt plus a paste-ready remedy (`dnf needs-restarting`). The service scan runs
  `--disable-repo='*'` unconditionally — dnf5-needs-restarting(8) defines `-s` by
  rpmdb facts alone, no advisory input; measured byte-identical and ~1.2s faster
  (the scan was empty that day, so the man-page definition carries the semantic
  claim). Both calls surface stderr's first line in degraded/[WARN] messages.
  **Live findings that correct this item's original account** (same dnf5 5.4.2.1
  as the incident): with a tty on stdin dnf asks and blocks — reproduced via a pty,
  and the question never even flushes through a captured stdout, so the hang is
  signless; with stdin closed the question lands on *stderr*, EOF declines it, and
  dnf **skips the unverifiable repo and succeeds** — so a declined key no longer
  fails the check (the "declined key → [WARN]" model was wrong), and the hybrid's
  real triggers are hard failures. Degraded path live-verified with a cold cache
  behind a dead proxy: flagged core verdict with the true cause in-line, 2.9s.
  Suite grown to 75 checks, mutation-verified five ways (fallback disabled → exactly
  the 15 fallback checks fail; `-s` repos re-enabled → exactly 1; degraded note
  silenced → exactly 5; each `</dev/null` guard → exactly its own stdin probe).
  Declined: always `--disable-repo='*'` for the main check (silently narrows the
  verdict); rc 2 for a degraded no; prompt-text sniffing (dnf's human text is not a
  contract — and its stream choice proved variable within one day); upstream dnf5
  report (user decision 2026-08-09: local workflow only); any gpushall change — an
  independent audit found the dnf bug class absent from `50-git-sync.sh` (git, ssh,
  and gpg all prompt via `/dev/tty`, so nothing blocks invisibly under capture; the
  vet prompt is `[[ -t 0 ]]`-gated), with two adjacent observations recorded under
  Notes. @done(2026-08-09)

- [x] Retired the `scripts` repo (survey + fold-in). Verdict of the survey: 14 of its
  16 items were regenerable one-offs (OCR/PDF/plot/file-management scripts, a stale
  third-party tweet-deleter) — deleted. Adopted the two keepers: the 153-check
  git-sync regression battery as `tests/gsync/` (suites re-rooted via `CFG_ROOT` so
  they test the checkout they live in, not a hardcoded `~/Desktop` path; verified
  153/153 post-move) and `sysinfo.sh` into `bin/` (stowed). Dropped `scripts` from
  `REPOS_DESKTOP`; local repo moved to `~/Desktop/archive/scripts` with full history
  — the **sole** history copy once the GitHub remote is deleted (planned). Docs
  updated here (CLAUDE.md) and in the Desktop-level CLAUDE.md. @done(2026-08-04)

- [x] Post-sweep self-audit (prompted by "did anything break?"): discovered that every
  headless `nvim` run — the day's test probes and `tests/nvim-syntax/run.sh` alike —
  had been saving a session for its CWD on exit, and the smoke tests had overwritten
  the real `configs` session with a scratch-file buffer (unrecoverable, low-value; the
  next interactive exit in `configs` re-creates it). Deleted the five junk/synthetic
  session files (kept `dissertation.vim` — 7 real buffers, genuine). Added a headless
  guard to `persistence.lua`: an init()-registered VimLeavePre autocmd calling
  `stop()` when no UI is attached. First attempt used VimEnter and **failed** —
  `nvim --headless +qa!` exits before VimEnter fires; the VimLeavePre placement is
  load-bearing. Verified: neither headless exit pattern saves; the syntax suite leaves
  no session; a pynvim `ui_attach` instance (interactive-equivalent) still saves
  normally. @done(2026-07-26)

- [x] Staleness sweep of `nvim/` (full-directory audit). Removed the 8 dead
  `vimtex_*` settings from `vimtex.lua` — 7 (`root_markers`, `texmf_home`,
  `includegraphics_search_paths`, `complete_{recursive_bib,input_paths,scan_files_depth}`,
  `include_search_paths`) were never VimTeX options at all, and `compiler_progname` was
  deprecated upstream in 2021. Verified inert three ways: grepped every installed plugin,
  the whole config, and `~/Desktop` scripts for readers (none); confirmed absent from
  VimTeX code *and* docs; diffed VimTeX's resolved runtime state on a dissertation
  chapter before/after (identical — root/main-file detection was always VimTeX's own
  heuristics). Widened persistence autoload from the six-root allowlist to any CWD under
  `~/Desktop` — sessions were already saved for every CWD (80 on file, incl. Carnap,
  LogiKEy, org subdirs) and `<leader>qs` already restored anywhere; the list gated only
  empty-start autoload. Verified end-to-end in a scratch dir (save → autoload-restore →
  negative control outside Desktop). Everything else checked healthy: syntax regression
  suite 24/24 before and after; snippet `--check`/`--coverage` clean; treesitter
  `highlight.disable` still honored by LazyVim's `main`-branch shim (and no latex parser
  installed — double protection); headless startup clean; new `after/syntax/` live via
  the existing `after` symlink (no restow needed); `nvr`/`pandoc`/`live-server`/`latexmk`
  all resolve; lockfile matches installed plugins. `lua/plugins/inactive/` kept
  deliberately (parked experiments, per session decision). Same-day follow-up resolved
  the stylua question: it is *load-bearing* — LazyVim format-on-save (conform → Mason's
  stylua) formats Lua on every in-editor save, which is why the tree was mostly clean;
  the 4 drifted files had last been written outside Neovim. (Headless probes first made
  it look inactive: LazyVim registers format-on-save in its VeryLazy callback, which
  never fires under `--headless` — firing it manually proved the chain.) Formatted the
  4 files via CLI (verified byte-identical to what an in-editor save produces), added
  `nvim/.styluaignore` for the 2 generated snippet files (verified honored by both CLI
  walk and editor path), restowed, corrected CLAUDE.md's formatter docs; `--check` now
  clean. @done(2026-07-26)

- [x] Follow-ups to item 2, same day: `--coverage` mode in the snippet generator
  (cross-references the `.sty` against `vimtex.lua`'s registrations; wired into the
  auto-regen notification, so a new macro without highlighting is flagged on next
  Neovim start); committed the 24-check headless syntax regression suite as
  `tests/nvim-syntax/run.sh` (verified both green and red paths); env snippets no
  longer emit macro-valued optional defaults (`\proof~` dropped its redundant
  `[\proofname]`). @done(2026-07-26)

- [x] Optimized the `french-logic.sty` ↔ Neovim interplay (was item 2). **Coverage:**
  registered the ~60 unhighlighted commands (affirm/deny family, metalanguage
  connectives, `\by`/`\close`/`\infr`/`\hyphantom`, `Rup`/`Rdown`/`Lup`/`Ldown` order
  conditions, `cax`/`Kfour`/`Kfive`/`Kfourfive`/`EN`/`Rlog`, `r[me]?poss` rules, `qed`,
  `tuple`, `precedes`, `metalogic`, `incomp`, I/O connectives) — now 504/509 covered,
  the 5 exclusions deliberate and documented. **Environment names** coloured by family
  via a new `after/syntax/tex.lua` (theorem-family orange, proof/derivation magenta,
  lists default cyan); gentzen math-region registration deliberately skipped (retired
  notation, per session decision). **Three latent bugs found and fixed:** (a) every
  `re()`/`mre()`/`mare()` pattern registration had been silently dead — VimTeX drops
  `cmdre` entries without `name`; all 31 patterns now have group-name slugs and were
  runtime-verified; (b) `argstyle` never accepted highlight groups, so all intended
  argument colouring was dead — replaced with `arglink()` + explicit links applied in
  the ftplugin; (c) an unguarded `serverstart("/tmp/nvimsocket")` aborted the whole
  vimtex `init()` in any second Neovim instance — now `pcall`ed. **Rebalance:**
  `texCmdRule` dark5 → TokyoNight purple (hue-tied to the magenta proof envs).
  **Snippets:** generator now parses `\newtheorem` (11 new env snippets incl.
  `definition`/`theorem`) and env optional args (`proofsketch[Proof sketch]`), stamps
  the `.sty` sha256 into the output, and gained `--check`; `snippets.lua`
  auto-regenerates on stamp mismatch at LuaSnip load (chosen over hook/manual
  options). Verified by a 24-check headless suite plus a live dissertation-chapter
  smoke test (`\CMr` → axiom gold). @done(2026-07-26)

- [x] Configure markdown-tasks.lua(s) to handle all of the following:
    - mt - toggle `[ ]/[x]`
    - md - toggle marked done
    - ms - toggle marked started
    - mD - toggle both `[ ]/[x]` and done
- [x] Configure markdown_tasks.lua(s) to either (a) generate a TASKS.md file with all open tasks in a directory, or (b) write a bash script/function that accomplishes the same thing. @done(2025-11-25 09:16)
- [x] Initialize `~/.bashrc.d` directory and split up aliases and functions. @done(2025-11-24 21:28)
- [x] Update Neovim README when the dust settles @done(2026-03-20)
- [x] Full staleness survey of the repo; fixed the README's missing `bin` package, corrected the Sway accent colour in the docs, cleared stale `.bak`/`.save`/diff artifacts, guarded the dead bun PATH entry @done(2026-07-26)
- [x] Consolidate homegrown scripts into `bin/`: moved `okular-forward` / `okular-inverse` from `~/.local/bin`, verified resolution is unchanged. Left `~/bin/isabelle*` untracked — generated by `isabelle install ~/bin` @done(2026-07-26)
- [x] Add an `okular` stow package for `okularpartrc`, excluding `okularrc` and `docdata/`; confirmed over two write cycles that Okular does not break the symlink @done(2026-07-26)
- [x] Four-lens adversarial audit of the git-sync rewrite (independent reviewers: control flow, bash semantics, git semantics, test blind spots) after a return-status bug reached production. Fixed everything found: unborn-branch guard bypass (gpush could root-commit a fresh `git init`), fail-open vet listing (now fails closed), `:(literal)` unstaging with post-verify (leading-colon/glob filenames could dodge a decline), rename/typechange vet bypass (`git mv x .env` now vetted), embedded-git-repo detection, per-component secrets matching (`.env/` dirs), `REVERT_HEAD` in-progress guard, dropped `--tags` from pulls (force-moved tag wedged every sync), `gpushall` parser (`-f` no longer commits 13 repos with message `-f`; multi-word positional messages no longer truncate), offline no-upstream PEND, push-path integrated-changes reporting + hints (silent fast-forward fixed), rebase-abort verification, prompt context duplicated to stderr under capture, `GSYNC_MAX_MB` validation, exact-ref `ls-remote`. Regression suites grown to 153 checks in four files. @done(2026-07-26)
- [x] Overhauled the git-sync commands (was item 1): collapsed the gpull/gpullall and gpush/gpushall duplication into shared `_gsync_pull_repo`/`_gsync_push_repo` helpers; added new-file vetting (size via `GSYNC_MAX_MB`, secrets globs, y/N prompts), listing of first-time-committed files, an in-progress rebase/merge guard, auto-abort on rebase conflict, offline-aware pushes (commit locally, mark pending), non-main-branch warnings, compact colorized output with named-repo summaries, multi-name `gpull`/`gpush` with `-m` and tab completion, a `gstatall [-f]` dashboard with per-repo sync verdicts (needs push / needs pull / DIVERGED), a post-pull ahead-of-origin warning, post-pull re-source/restow hints, and removal of the redundant pre-pull fetch (~half the network round-trips). Verified by a 37-check sandbox suite plus a live `gstatall`/`gpullall` run. @done(2026-07-26)

---

## 11. Per-window cgroup scopes after the Ghostty launcher change

Opened 2026-09-03, closed 2026-09-05. **Verdict unchanged — `linux-cgroup =
always` stays declined — but the reasoning the item gave for it was wrong and is
corrected here.**

**What was measured.** Under `--gtk-single-instance=true` a shell sat in
`app-ghostty-surface-transient-13234.scope`, a per-surface scope Ghostty creates
itself. Under the sway launcher's `--gtk-single-instance=false` the shell shares
`app-com.mitchellh.ghostty-17355.scope` **with the GUI process itself** — the
launcher's scope, named for the GUI's pid. So the item's expectation is
confirmed: with one process per window, the window is the cgroup. (The item
predicted the GNOME name `app-gnome-ghostty-<pid>.scope`; on sway it is
`app-com.mitchellh.ghostty-<pid>.scope`. Same structure, different launcher.)

**The correction.** The item argued the arrangement is fine because the window
scope "is the unit `systemd-oomd` acts on". **`systemd-oomd` is inactive on
fedxps.** Three readings settle what actually happens:

| | value | consequence |
|---|---|---|
| `systemctl is-active systemd-oomd` | inactive | no pressure-based, cgroup-level killing |
| `memory.oom.group` | `0` | an OOM kill takes one process, not the scope |
| `MemoryMax` | `infinity` | no cgroup bound is in play at all |

So a runaway is handled by the kernel OOM killer picking a single process
system-wide, not by anything cgroup-aware. Per-surface scopes with no limit and
no cgroup reaper are bookkeeping, and `linux-cgroup = always` would cost the
man page's ~100 ms per window to buy nothing observable. The verdict survives;
its justification changes from "the scope is what oomd acts on" to "nothing
cgroup-aware is running to act on it".

**The one variant with teeth is ruled out separately.**
`linux-cgroup-memory-limit` would give each surface a hard `MemoryMax`. That
contradicts an existing recorded policy: `n-cube/notes/isabelle-notes.md`
records that `systemd-run --scope` breaks Isabelle's prover-subprocess spawning
and `ulimit -v` breaks JVM startup, and settles on running **uncapped** with a
process-RSS guardian at ~12 GB. A per-surface cap would be a third capping
mechanism at the wrong layer, and below ~12 GB it would kill runs that policy
intends to allow. Note this is about the *cap*, not scope membership: terminals
already run inside a launcher-made scope (`Delegate=no`, `TasksMax=18924`) and
Isabelle is fine there.

**Premise revised.** The item recorded "one window per task through the WM
rather than terminal tabs or splits (measured 2026-09-03)". He uses tabs
occasionally (2026-09-05), so per-surface and per-window do not partition
sessions quite identically — but the reaper findings above decide the question
regardless.

**Trigger for revisiting:** enabling `systemd-oomd`. Per-surface scopes stop
being bookkeeping the moment something cgroup-aware is choosing victims; the
memory limit still would not follow.

Full context: `docs/ghostty-vs-wezterm-2026-09-03.md`, Addendum 1 "Open" and
Addendum 2.
