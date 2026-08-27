# Okular integration — the multi-document rework and related measurements (2026-07 – 2026-08)

Dated record, opened 2026-07-26, annotated through 2026-08-13; moved verbatim
from the root `CLAUDE.md` on 2026-08-26 (context-policy Stage 2). The
operative halves live in `bin/CLAUDE.md` (the `okular-forward` /
`okular-inverse` wrappers and their coupling) and `okular/CLAUDE.md` (the
stowed `okularpartrc`, what is deliberately excluded, and the re-verify
checks); this file is the investigation record.

## Several documents open at once — reworked 2026-07-26

The forward wrapper used to end in `exec okular --unique …`. That is why only one PDF was ever viewable: `--unique` makes the running instance **replace** its current document on every call, so compiling a second deck evicted the first. It also bypasses "Open new files in tabs" entirely, which is why toggling that preference appeared to do nothing.

Okular offers only two CLI behaviours and **both are wrong** for a VimTeX loop spanning more than one document:

| invocation | behaviour | failure |
|------------|-----------|---------|
| `okular --unique <pdf>` | reuses one window, replaces the document | deck B evicts deck A |
| `okular <pdf>` | honours the tabs preference, but has **no already-open check** | every forward search into the *same* doc appends *another* tab (measured 1 → 2 → 3) |

So the already-open check is done in the wrapper, over D-Bus. The enabling fact: **each open tab exports its own object** — `/okular`, `/okular2`, `/okular3`, … on service `org.kde.okular-<pid>` — and each answers `currentDocument()`. Calling `openDocument()` on the object that already holds the PDF performs the SyncTeX jump *inside that tab*, creating nothing; `tryRaise()` on `/okularshell` brings the window forward. Only genuinely-unopened documents fall through to the CLI.

Note the service name depends on launch flags: a `--unique` instance claims the well-known name `org.kde.okular`, a normal one registers `org.kde.okular-<pid>`. The wrapper matches both, so a stray `--unique` instance from an older session is still found. A per-document `flock` in `$XDG_RUNTIME_DIR` closes the startup race (two searches fired at a still-launching document would otherwise both decide it is absent). Detection costs ~70 ms.

**Tabs vs. separate windows is not hardcoded** — the wrapper is mode-agnostic and both were tested. Flip it in Okular: Settings → Configure Okular → General → "Open new files in tabs" (`okularpartrc`, `[General] ShellOpenFileInTabs`). Toggle it *through the GUI*, not by editing the file, since Okular rewrites `okularpartrc` on exit and would clobber a hand edit. It governs only where *newly opened* documents land; already-open ones do not rearrange, so close Okular and let the next forward search reopen them.

**Measured limitation, tabs mode:** a forward search into a *background* tab lands on the correct page but does **not** switch to that tab — you get no visible feedback until you switch, at which point it is already in the right place. Confirmed by triggering the exported `file_close` action over D-Bus and seeing which document vanished. There is no clean fix: Okular exports only 11 actions and none is tab-related (it *has* `activateNextTab` / `Switch to Tab %1` internally, just not on the bus); the one call that does activate a tab (`shell.openDocument`) always appends a new one, and `file_close` only closes the *active* tab, so the stale duplicate cannot be cleaned up. Key injection is out too — Okular here is a native Wayland client (`libqwayland.so`, not `libqxcb.so`), so `xdotool` cannot reach it, and `wtype` needs `zwp_virtual_keyboard_v1`, which GNOME does not implement. **Separate-windows mode is the likely fix if the silent jump ever grates, but it is unconfirmed.** There, each document gets its own process and so its own `/okularshell`, and `tryRaise()` was verified to succeed and to target the right window — but whether GNOME actually *raises* it was never tested. Doubt it: the wrapper passes an empty activation token (`tryRaise s ""`), and Wayland focus-stealing prevention will generally refuse to activate without a valid `xdg-activation-v1` token, marking the window as demanding attention instead. GNOME exposes no setting to relax this, and its `Introspect.ActivateWindow` D-Bus route is access-denied. **Settled under Sway on 2026-08-13 — and the answer closes the question rather than fixing it.** The hoped-for knob was sway's `focus_on_window_activation`, on the theory that sway would honour what GNOME refused. It does not apply: sway's **default is `urgent`**, so any activation request that arrives gets flagged urgent — and a recording of sway's `window`/`workspace` event stream across a real forward search into an off-screen Okular showed **zero `urgent=True` events**, alongside no focus change. The request is not being refused by the compositor; it is not reaching it at all. So the knob governs a request that never arrives, and setting it would change nothing.

What *does* work, verified the same day: **the SyncTeX jump itself is fine.** With Okular parked on page 10 and the real wrapper invoked for line 1, the page moved to 1 and the wrapper exited 0. Only `tryRaise` silently no-ops.

**Verdict: deliberately not fixed.** The failure does not occur in the way this machine is actually used (Okular sits beside Neovim on one workspace, so the jump is visible and no raise is needed); it only shows up when Okular is hidden. And every fix that would work costs more than the defect: `swaymsg '[app_id="org.kde.okular"] focus'` in the wrapper *would* raise it reliably — sway focusing its own window needs no activation token — but in the side-by-side layout that pulls keyboard focus out of Neovim on every `\lv`, trading a silent success for a disruptive one. A conditional variant (raise only when Okular is on another workspace) is ~8 lines and permanently couples a compositor-agnostic wrapper to sway, to buy a case that does not arise. If the silent jump ever does grate, the cheaper answer is feedback rather than focus — `notify-send` from the wrapper, which is now non-intrusive since mako auto-dismisses after 5s.

## Where `okular-inverse` resolves from — measured, 2026-07-26

Okular finds it via the PATH of whatever launched it, and only one of the two cases works:

- **Launched by VimTeX** (the normal path): inherits the interactive shell's PATH, so `~/bin/okular-inverse` resolves and inverse search works.
- **Launched from the desktop** (app grid, Files, `xdg-open`): inherits the session PATH, which is `/usr/local/bin:/usr/bin` — `gnome-shell`'s actual environ, matching `systemctl --user show-environment`. `okular-inverse` is not found and inverse search silently does nothing.

Neither `~/bin` nor `~/.local/bin` is on that session PATH; both come only from `20-path.sh`, which runs for interactive shells only. So this is a property of how Okular is launched, not of where the script lives — verified by resolving the old `~/.local/bin` location against the same session PATH, which also fails. Moving these scripts into the repo changed nothing either way.

If inverse search from a desktop-launched Okular is ever wanted, the fix is a `~/.config/environment.d/*.conf` adding both directories (`PATH=$HOME/bin:$HOME/.local/bin:$PATH` — expansion confirmed working). Deliberately **not** done: it would give PATH a second source of truth that does not reproduce `20-path.sh`'s TeX-Live-first ordering, so a GUI process and a terminal process could disagree about which `pdflatex` wins mid-`tl-newyear`. Only add it against a concrete failure.

## The stowed `okularpartrc` under KConfig's replace-and-rename — tested 2026-07-26

**`okularpartrc` is the only stowed file that the *application itself* rewrites** — everything else in the repo is written only by an editor. That was the open risk when the package was added, since KConfig saves by atomic replace, which could swap the symlink for a real file and silently un-stow it. **Tested over two write cycles on 2026-07-26 and it survives**, but be precise about the mechanism: KConfig *does* replace-and-rename — the target file's inode changes on each write — it just resolves the symlink first and replaces the file inside the repo rather than clobbering the link in `~/.config`. The link stayed intact, both paths kept reporting the same inode *as each other*, the changed key appeared in the repo file, and every other key was preserved. Toggling a setting back removed its key entirely rather than writing `=false`, so the file returned byte-identical to its prior state.

To re-verify at any time: `[ "$(stat -Lc%i ~/.config/okularpartrc)" = "$(stat -c%i ~/Desktop/configs/okular/okularpartrc)" ]` should hold, and `~/.config/okularpartrc` should still be a symlink.

The practical consequence of replace-and-rename: don't assume anything holding an open file descriptor on the repo copy will see updates, and don't be surprised that `git` reports a whole-file change.

Two consequences. First, changing an Okular preference now dirties the repo, and `gpushall` will commit it — expected, and it only happens on a deliberate change, since this file carries no session state. Second, if Okular settings ever *do* stop syncing after a KDE upgrade, check `ls -l ~/.config/okularpartrc` before anything else; if it is no longer a symlink, move the file back into `okular/` and restow.

**Pulling a change to this file while Okular is running is safe** — tested 2026-07-26 by writing a new key underneath a live Okular and quitting it. KConfig writes back only the keys it changed *that session*, so it merges rather than overwriting, and the pulled value survives. The one caveat is the running process, not the file: it keeps its old in-memory value until restarted, so a pulled preference does not take effect in an already-open Okular.
