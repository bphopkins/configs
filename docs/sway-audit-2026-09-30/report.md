# Sway desktop suite: audit report, 2026-09-30

A dated record. The decisions this report put to him were taken the same day
and are recorded with their reasons in `DECISIONS.md` under 2026-09-30, where
the open remainder is listed too; the fixes marked "on your go" below were
applied that evening. The workers' raw output (every finding, verdict and
probe) is not in this repo.

The battery: 14 reviewers, one per dimension, each followed by a skeptic that
re-derived every finding from the man page, the installed source or a caged
nested sway, then listed what the reviewer missed. 28 workers, all Opus 5.5 at
xhigh, 2 h 11 min, 9.95 M tokens, 2,878 tool calls. 152 findings; the skeptics
confirmed 112, confirmed 40 in part (claim right, fix or effect corrected),
refuted none, and added 43 of their own. Both the live session and the repo
were untouched throughout: every proposed change below is still a proposal.

Raw material (the session's scratchpad, not in this repo): every finding,
verdict and correction as JSON, per-dimension digests, and the workers'
probes, test configs and measurement logs.

## 1. Method caveats, stated once

- A Unix socket path holds 107 bytes and sway truncates longer ones silently.
  My brief gave every worker a longer path, so until 14:55 all nested sways
  bound one socket and could answer each other's commands. A worker caught
  it (R12); the brief was corrected; every nested-sway measurement taken
  before the fix was graded "inferred" and re-measured by its skeptic on a
  private socket with an identity check. Nothing in this report rests on a
  pre-fix nested measurement. The live session was never reachable that way.
- Your spend limit paused the API for a minute at 15:18. Five workers died
  mid-run and were restarted from scratch by the harness (the failure-paths
  reviewer and the skeptics for R01, R04, R05, R06). Their results are whole;
  the cost was five repeated runs.
- One permission prompt (an `rm -f ""` probe inside R13's own scratch dir) was
  denied by you; the worker retried another way. Nothing was lost.
- "Confirmed" means the skeptic reproduced the claim itself; "in part" means
  the claim held but the proposed change or an effect needed correcting, and
  the corrected form is what appears below.

## 2. The findings that matter most

1. **The power button powers the laptop off at one press under sway.** logind's
   HandlePowerKey=poweroff applies because nothing holds the handle-power-key
   inhibitor that gnome-settings-daemon holds under GNOME (where your setting
   is 'nothing' on both machines). Found independently by five dimensions,
   confirmed. One exec line in sway/config holds the inhibitor for exactly
   the session's life. Decision D1: nothing, or the Poweroff/Reboot nag.
2. **Every chord repeats while held.** After 600 ms sway re-runs a binding
   every 40 ms unless it carries --no-repeat, and none here does. A held
   $mod+q closes window after window; a held $mod+Shift+3 sends window after
   window; a held Print takes 25 shots a second; every toggle flickers and
   lands at random. Objective fix: --no-repeat on the one-shot bindings, with
   the rule stated in the header. Taps are unchanged.
3. **$mod+q after $mod+a closes the whole selection, unprompted**, and a is the
   key under q. On the laptop's usual shape (windows straight on the
   workspace) $mod+a selects the workspace, so $mod+q then closes every
   window on it. Measured. Decision D2.
4. **Your borders have been 2 px, never 3.** The trailing comment on
   `default_border pixel 3` is passed to the command as extra words, and
   sway then keeps its 2-px default. It has been so since the line was first
   committed (2025-11-09). `sway --validate` and the suite both pass it. The
   white split cue was therefore 2 px too. Decision D3: 3 px as designed, or
   write down the 2 px you have looked at.
5. **Tap-and-drag lock is stuck on.** sway 1.11 alone forces libinput's
   enabled_sticky drag lock, so a tap-drag stays held until another tap
   (fixed upstream in 1.12; Fedora ships 1.11). GNOME has it off. One line.
6. **Right-click on the touchpad works differently from GNOME.** Under sway
   the pad uses corner button areas (bottom-right = right click); under GNOME
   a two-finger press is a right click. Decision D6.
7. **Brightness-down reaches 0.** The journal shows you overshooting into 0
   and pressing straight back six times; once it sat at 0 for 15 minutes.
   brightnessctl also drives an LED on a machine with no backlight unless
   the class is pinned. Objective fix with a floor; decision D27 on the floor.
8. **Volume-up has no ceiling.** pactl's relative +5% walks past 100 % into
   software gain; GNOME and Waybar's own scroll stop at 100. wpctl with
   -l 1.0 is the canonical form. Objective.
9. **The lock has three real holes, and its documented one is false.** A bad
   swaylock key does not stop the lock (it truncates the look); what does
   fail open is swayidle dying (the lid then suspends unlocked, silently),
   the GNOME lock habit Super+l meaning focus-right here, and the docked lid
   (an external display attached: the lid neither suspends nor locks and the
   closed panel stays lit). Also: nothing answers logind's Lock signal, so
   `loginctl lock-session` does nothing under sway. Fixes: a `lock` handler
   on swayidle (objective), a gauge and restore line in the charter
   (objective), GNOME honouring Super+Ctrl+l too (D20), the lid pair
   (long-term, section 6).
10. **The eDP-1 page-flip errors are a known i915 race**, confirmed against
    the wlroots and i915 trackers: with max_render_time off sway commits the
    next frame before the kernel has closed the previous commit's record of
    the switched-off cursor plane, and the frame is dropped. One line keyed to
    eDP-1 (inert on bigfed) composites 10 ms before the refresh. D18.
11. **Resize mode is invisible and a trap.** Nothing on screen shows it, $mod+r
    does not leave it, and inside it hjkl, the arrows, Return and every $mod
    chord are dead or repurposed. Objective: a `sway/mode` pill in the bar
    and `$mod+r` bound inside the mode to leave.
12. **The suite has vacuous checks.** The urgent-colour check greps anywhere
    in a file (ring-wrong-color can drift and pass); the swayidle check
    passes when the line is deleted; the binding-body check passes vacuously
    when the nested sway dies; the strip that protects against the 2026-08-13
    incident misses exec_always and non-/etc includes and still spawns
    swaybg and an X display; the suite runs uncaged (TODO 26). All objective.
13. **Under sway, images open in Brave or GIMP and fonts in FontForge**: GNOME's
    default-app list applies only when the desktop name contains GNOME; 34 of
    237 defaults differ. One symlink per machine restores them under your
    own choices. Objective (outside the repo; one command).
14. **$mod+Shift+x does nothing while a Text Editor window exists** (single
    instance; needs --new-window as GNOME's key had). Objective.

## 3. Objective fixes: applied together on your go

No decision needed beyond a go; each line names its fedxps effect. bigfed
effects are the same unless stated. Anything you strike, say so by number.

### sway/config
- F1 --no-repeat on: $mod+Escape and $mod+Shift+Escape, $mod+Ctrl+l, $mod+w,
  the launchers (Return, Shift+Return, b, c, d, f, x, Shift+x), $mod+q,
  $mod+Shift+f, $mod+Shift+space, $mod+space, $mod+Tab, $mod+Shift+1..0,
  $mod+Shift+minus, $mod+minus, $mod+Shift+v/b/s, $mod+Ctrl+r, the carry-to-
  monitor chords, the two mute keys, $mod+m, the Print chords, $mod+r; the
  rule in the header. fedxps: a held chord fires once. Keeps repeating:
  focus, move, walks, volume, brightness, resize-mode keys.
- F2 Trailing comments moved onto their own lines at the two border lines and
  the two touchpad lines (with D3's width); a suite check that no config line
  carries a trailing comment. fedxps: new windows get the decided width.
- F3 `drag_lock disabled` in the touchpad block. fedxps: a tap-drag ends at
  the lift, as under GNOME. bigfed: none.
- F4 `client.focused_tab_title $accent $accent #ffffff`: a tab holding a split
  stays blue while focus is inside it (today it turns grey). fedxps: only
  inside such a fold.
- F5 swayidle gains `lock 'swaylock -f'`: `loginctl lock-session` and logind's
  Lock signal lock the screen. Nothing sends Lock unasked. The suite's pinned
  swayidle string is updated in the same change.
- F6 `$mod+Shift+x exec gnome-text-editor --new-window`. fedxps: the key opens
  a window every time.
- F7 `bindsym $mod+r mode "default"` inside the resize mode, so $mod+r toggles
  out as well as in; the suite's duplicate check becomes mode-aware.
- F8 Volume on wpctl: mute and mic-mute toggles, lower, and raise with
  `-l 1.0`. fedxps: raise stops at 100 %; a level already above 100 % comes
  down to 100 on the next raise. bigfed: the same on its default sink
  (wpctl ships with WirePlumber; the suite's binary check confirms it).
- F9 Brightness keys: `brightnessctl -q -c backlight`, down with a floor
  (D27). fedxps: the panel never reaches 0; each press stops writing four
  journal lines. bigfed: a key would fail cleanly instead of moving an LED if
  brightnessctl were installed; TODO 28 closes by installing it there or by
  the suite skipping it where /sys/class/backlight is empty (D27 names which).
- F10 The two Escape nags become toggles: `pkill -x swaynag || swaynag ...`.
  fedxps: a second press closes the nag; nags never stack.
- F11 `bindsym --inhibited $mod+Escape ...` twin: a way out when a VM viewer
  or remote-desktop client holds a shortcuts inhibitor (GNOME's is
  Super+Escape). Inert unless an inhibitor is active. Cheap insurance.
- F12 $mod+m reports its state: a 3-second low-urgency notification
  'Touchpad: disabled/enabled' (measured body; a reload also re-enables the
  pad, said in the comment). fedxps: each press shows the state. bigfed:
  'Touchpad: absent' (or the line can stay silent there; say if you prefer).
- F13 Screenshots: the clipboard variant captures to a temporary file and
  copies only after grim succeeds (today a grim failure after a good
  selection wipes the clipboard, silently); every capture shows a 3-second
  notification naming the file; slurp's selection outline takes the accent
  (`-c 0088FF`); a focused-window capture on Alt+Print (the Print family
  clause; captures the window without its border, or the whole container
  after $mod+a). Folder per D12.
- F14 Comment and header corrections: sway does not respawn a dead Waybar
  (it comes back with $mod+Ctrl+c; a reload replaces rather than duplicates);
  swaybar_command takes no arguments (a diagnostic 'waybar -l debug' there
  means no bar, silently); bar hiding is dead because Waybar's ipc option is
  off, not because it ignores the protocol; nm-applet is exec'd because
  nothing runs XDG autostart under sway (the target never starts on this
  packaging); h/l wrap inside a whole-workspace fold; the mouse chords and
  $mod+space named in the header; 'the one key where this file and GNOME
  part' dropped (they part on a dozen); the terminal comparison is closed;
  the 'Caution when editing' paragraph explains the two rewrite passes (load
  un-escapes backslashes, and $variables are replaced at load and at every
  press, so '$$' is a trap); the reload note says a broken reload applies
  the rest and raises sway's red nag whose first button exits the session.

### swaylock/config
- F15 `text-clear-color=ffffff`: 'Cleared' is drawn black on black today,
  including after the 10-s silent wipe of a half-typed password.
- F16 `indicator-caps-lock` plus highlight colours (ffffff, 000000): five of
  the six caps-lock keys have never applied; with it, Caps Lock turns the
  ring orange as the comment promises.
- F17 `ignore-empty-password`: an empty Enter no longer costs 2 s of
  'Verifying', a red 'Wrong' and a failed-attempt count.
- F18 Comments: the black matches nothing now that folds paint the accent
  and grey; an unknown key truncates the config at that line and locks anyway
  (the charter's 'no lock at all' is false); the one config line that means no
  lock is `version`, which the suite now refuses.

### wofi
- F19 `layer=overlay`: the menu opens visibly over a fullscreen window (today
  it opens beneath one and still swallows the keyboard).
- F20 The selected-row wash uses `@accent` (the one-word forest swap would
  have missed it); the border comment stops citing the vanished underline;
  height=460 is noted as inert while lines=12 is set. D8 for matching/sort.

### Waybar
- F21 Battery: tinted by charge state (your item 1; pair A first, judged on
  screen), the `+` dropped; warning and critical scoped to discharging (today
  a laptop plugged in at 8 % keeps the urgent fill); the tooltip uses
  `{timeTo}` ('Empty in 3 h 5 min', 'Full in 40 min', 'Plugged' at the 80 %
  cap, where today it reads '()'); the notification texts say 'at 20 percent
  or less'. bigfed: none (no battery).
- F22 `sway/mode` pill, urgent fill, last on the left: 'resize' shows while
  the mode holds the keys. The bar stays 24 px.
- F23 Hover artefacts: Adwaita-dark's button:hover text-shadow and inset
  box-shadow show through on the filled pills (measured: 28-30 changed
  pixels); and its 500 ms flat-button transition makes a clicked workspace
  fill half a second late. Both zeroed in the sheet.
- F24 Dead `#workspaces button.active` selector removed (never set under
  sway/workspaces); clock and backlight tooltips off; `min-brightness: 1` on
  the backlight scroll; font-size pinned per D15.
- F25 Tray `reverse-direction: true` (your item 2, the cheap half): the Wi-Fi
  icon is rightmost at login; it flips only after a stylesheet reload until
  the next login. Waybar's code makes a fixed order impossible (section 5).

### bin/sway-split and tests
- F26 sway-split leaves floating windows alone (today the split keys wrap a
  floating window invisibly, with no marker and no cancel, and the next
  window opens floating inside it; hiding a wrapped scratchpad window then
  takes the newcomer with it); `set -u -o pipefail` so the watcher exits
  when sway is unreachable instead of exiting 0 silently. Suite: 43 checks.
- F27 tests/desktop/run.sh: caged (tests/cage.sh; TODO 26's desktop slice);
  the test copy strips exec_always and every include and prepends
  `swaynag_command -`, `swaybg_command -`, `xwayland disable` (today it
  spawns a real swaybg, an image-loader sandbox and an X display); leaks read
  from the cgroup; a nested sway that fails to start fails the run; the
  binding-body check fails when the nested sway stops answering; the wiring
  checks pin the drawn keys (client.urgent, ring-wrong-color, the exact
  swayidle line, the two bare lock sites); the binary check resolves $term2,
  script arguments and sh -c bodies; the duplicate check sorts modifiers and
  respects modes; a SWAYSOCK over 107 bytes is refused; mako's own parser
  validates mako/config (a bad value stops mako starting at the next login,
  which the key check cannot see); wofi's selectors are checked against
  wofi(7); swaylock values and trailing spaces are checked; the MSI
  identifier in sway/config and waybar/config is held equal; bindgesture and
  bindswitch lines are included in the body check; repeat_rate must be
  digits. About 40 checks.

### Documentation
- F28 Charters, card, trackers and record (annotate, never rewrite): the
  items in F14 and F18 plus: the nested-sway recipe in sway/CLAUDE.md caged,
  on a short private socket, with the identity check and all six spawn
  points stripped; a 'Locked out: the way back' section in swaylock/CLAUDE.md
  (a red screen means swaylock died while locked; on fedxps a lid cycle
  recovers it, else the console); a recovery table for the once-started
  processes (swayidle, nm-applet, swaybg, Waybar, assign-cgroups.py) with
  paste-ready `swaymsg exec` lines; the CSS-error account corrected (Waybar
  does log the error, on stdout under gdm-wayland-session); Waybar 0.15.0's
  stray battery `puts` noted as the journal's main steady-state source;
  reload_style_on_change noted as inert through stow's relative link; a
  configs/CLAUDE.md pitfall that a stow package targeting
  ~/.config/systemd/user is silently ignored by systemd (relative directory
  symlinks); the README card's marker colour; TODO 30 gains the $mod+x check;
  TODO 26/28 updated; DECISIONS annotations (the 2-px border since 2025-11;
  $mod+v moved to Shift; the Ctrl+t decline's overturned reasons; adelotype's
  record moved private; 'ink 20 px' is the box arithmetic, ink measures
  21-23; the charging colour returns as a tint); environment.d's comment
  says the login shell is GNOME's.

### Outside the repo, one command per machine (your hand, or mine with a go)
- F29 `ln -s /usr/share/applications/gnome-mimeapps.list ~/.local/share/applications/sway-mimeapps.list`
  (finding 13). Recorded as a setup bullet in sway/CLAUDE.md.

## 4. Decisions

Reply by number. "Take your recommendations" accepts every (R) option.

- D1 Power button under sway. (a) Inhibitor only: the button does nothing,
  GNOME parity. (b) (R) Inhibitor plus `bindsym XF86PowerOff exec swaynag
  ...` reusing the Poweroff/Reboot nag: the button asks. Either ends the
  one-press poweroff on both machines and closes that half of TODO 27.
- D2 $mod+q on a selection. (a) (R) Guard: kill only when the focused node is
  a window (a measured exec body, about 10 ms); after $mod+a nothing closes
  until focus is back on a window. (b) Keep sway's kill-the-selection and say
  so on the card.
- D3 Borders. (a) (R) 3 px, as the file says: new windows and the white cue
  thicken by 1 px after the reload; open windows keep 2 px until reopened.
  (b) `pixel 2`: the file states what is drawn.
- D4 Per-machine layer. (a) (R) Adopt now: `include hosts/$(uname -n).conf`
  after every setting, sway/hosts/fedxps.conf (empty header) and
  bigfed.conf, tracked in the sway package, one `stow-all` per machine, the
  suite validating each layer inlined and checking this machine's is linked.
  Measured end to end (wordexp with command substitution; a missing layer is
  silent; the relative path fails safe in test copies). (b) Record the
  design; build it when D5 first needs it.
- D5 bigfed under sway, idle. GNOME there locks and blanks at 15 min. (a) (R)
  Parity in bigfed's layer: a swayidle timer (lock, then displays off at
  900 s) paired with `inhibit_idle fullscreen`; fedxps keeps no timer, and
  the suite's no-timeout pin keeps binding fedxps. (b) Displays off only.
  (c) Nothing: bigfed's screens stay on and it never locks by itself. Also:
  does bigfed's keyboard have a sleep key (`systemctl is-enabled
  suspend.target` there: 'masked' settles it)?
- D6 Touchpad right-click. (a) (R) `click_method clickfinger`, middle
  emulation dropped: two fingers press = right, three = middle, as GNOME.
  (b) Keep button areas (bottom-right corner = right). Tell me how you
  right-click today under GNOME if unsure.
- D7 Key repeat. (a) (R) `repeat_delay 500`, `repeat_rate 33`, GNOME's values
  (mutter's 30 ms interval is 33 per second). (b) Keep sway's 600/25.
- D8 wofi. Matching: (a) (R) `multi-contains` (every word must appear; the
  named app ranks first; 'gimp' still finds GIMP; typos with dropped letters
  stop matching); (b) keep fuzzy (measured: 'files' ranks Neovim first, and
  Enter runs it). Order of the empty list: (c) (R) `sort_order=alphabetical`,
  stable and the same on both machines; (d) keep most-launched first.
- D9 Window activation. (a) urgent (today: the workspace chip turns orange,
  you go yourself); (b) (R) smart, i3's default: focus if the window is on
  screen, else orange; (c) focus, GNOME's: always jump.
- D10 Three-finger swipes. (a) (R) `bindgesture swipe:3:left workspace
  next_on_output` and right/prev, matching GNOME's direction. (b) None.
- D11 Media keys. If the XPS F-row and the Keychron carry play/next/previous
  and you use them: three --locked playerctl lines (playerctl on bigfed too).
  Otherwise nothing. (R): tell me whether the keys exist.
- D12 Screenshots. Folder: (a) (R) join GNOME's ~/Pictures/Screenshots;
  (b) stay loose in ~/Pictures. Layout: (c) (R) keep Print=whole screen to
  file, Shift+Print=region to clipboard; (d) swap to GNOME's meaning
  (Print interactive region, Shift immediate).
- D13 Notifications. Key: (a) (R) `$mod+n exec makoctl dismiss`; (b) the
  toggle that dismisses while any shows and otherwise restores the last one.
  Placement: (c) (R) keep top-right; (d) top-centre, GNOME's place (on the
  Samsung top-right is about 55 cm right of centre). Fullscreen: (e) (R)
  keep overlay (a battery warning shows over a film); (f) layer=top, GNOME's
  silence. Icons: (g) (R) keep; (h) icons=0, text only.
- D14 TODO 29, the session PATH. (a) (R) A tracked sway/wayland-session.desktop
  with `Exec=bash -l -c 'exec /usr/bin/sway'`, installed once per machine by
  `sudo install -D -m 0644 ...` to /usr/local/share/wayland-sessions/, plus
  one `exec dbus-update-activation-environment --systemd PATH` line so
  D-Bus-activated apps see it too. GDM offers no user-level hook (its only
  one is the declined environment.d PATH). A root-owned file, against your
  'never system files' preference, so your call. (b) Leave TODO 29 open.
- D15 Waybar font size. (a) (R) Pin 11 pt in the sheet: the bar's 24 px stops
  depending on GNOME's interface-font setting on each machine. (b) Keep
  following GNOME's setting, and say so in the sheet.
- D16 Tray order beyond F25. The structural fix I described earlier
  (Waybar's network module plus an icon-less nm-applet) is not available:
  nm-applet 1.36 turns its tray icon on by itself on any non-X11 display.
  The remaining structural route is to make the 802.1x network's password
  system-owned (`802-1x.password-flags 0`, stored root-readable by
  NetworkManager) so nm-applet is no longer needed as a secret agent, then
  drop it and show Wi-Fi state in the network module with `nmtui` on click.
  (a) (R) Not now: F25 plus a note. (b) Study the password change.
- D17 Battery tint pair: A (#ffb3b3 / #b3ffb3, clearly tinted) or B (#ffd6d6 /
  #d6ffd6, fainter). (R) A first; switch on sight.
- D18 Page-flip. (a) (R) `output eDP-1 max_render_time 10`, on trial: I count
  the errors per day before and after. (b) Leave; journal noise only unless
  you have seen a hitch or a late character in Ghostty.
- D19 VRR on bigfed. The sway lines set adaptive_sync on; bigfed's record says
  VRR is off after two amdgpu hangs pending a controlled re-trial. (a) You
  re-enabled it deliberately: the records get annotated. (b) (R until you
  say) Drop `adaptive_sync on` from both lines: a fixed 60 Hz, no VRR
  exposure.
- D20 GNOME-side parity, per machine (dconf, outside the repo; your hand or
  mine with a go): Super+Return and Super+Shift+Return for the terminals (your
  stated intent), Super+Ctrl+l added to GNOME's lock (keeping Super+l during
  the change-over), and the Files keys: GNOME has d=~/Desktop and f=home,
  sway has f=~/Desktop and d=menu. (R) yes to the first two; you choose the
  Files pair.
- D21 Zulip: `exec flatpak run org.zulip.Zulip` at sway login (GNOME
  autostarts it; sway runs no autostart), or start it by hand as now.
- D22 Only if you do these under sway: mount an internal drive from Files or
  run pkexec tools (then a polkit agent, mate-polkit); use USB sticks and
  want automount (udiskie); notice Okular looking different from GNOME (then
  `QT_QPA_PLATFORMTHEME=gtk3` in environment.d). Default: none.
- D23 Documentation batch (F14, F18, F28): a blanket go to edit the charters,
  comments, card, trackers and record as listed, or item by item.
- D24 sway/config narrative (R07-22, measured: 155 directives, 351 comment
  lines, about 64 narrative). (a) Keep as is. (b) Trim to verdict, date,
  pointer. (c) (R) Keep, but give every present-tense claim about something
  outside the file a date or pointer (the six drifts found were all of that
  kind), and tell the lid-hole story once.
- D25 Accent pin: the suite pins #0088FF in all five files as it pins the
  urgent colour, so a swap to forest is a deliberate five-file change. (R)
  yes.
- D26 Tab strip mouse: `bindsym button2 kill` on a title closes that tab, the
  browser gesture (measured). (R) yes, cheap and fits the folds.
- D27 Brightness floor. (a) (R) `--min-value=75` (5 %, keeps the 5 % grid).
  (b) 15 (1 %, GNOME's floor on this panel). (c) Keep 0 reachable as a hand
  blank. And TODO 28: install brightnessctl on bigfed (keeps the suite
  machine-agnostic) or skip it there where /sys/class/backlight is empty.
- D28 Workspace-level folds forget their split (a column unfolds as a row;
  a lone window keeps a row-of-one wrapper that lights the beside marker).
  (a) (R) Live with it, comment says so, one $mod+Ctrl+r restores the
  column. (b) A `fold` verb in sway-split that remembers the split (a script
  path on $mod+Shift+s, more suite).
- D29 Resize step. (a) (R) keep 10 px. (b) 5 ppt: about 96 px per press on
  fedxps, 256 on the Samsung.
- D30 Held over for a rofi trial and item 4: nothing to decide now.

## 5. Your four additions

1. Battery tint: F21, D17. Waybar's classes are charging, discharging, full
   and, when the adapter is online at the 80 % cap, `plugged`; the `+` used
   to vanish exactly there.
2. Tray order: cause found in Waybar 0.15.0's source (newest-first list,
   replayed at every style reload, appended live). F25 fixes the login case;
   no config value pins it; D16 for the structural route.
3. rofi: Fedora 44 ships rofi 2.0.0 with the Wayland backend merged (Sept
   2025; a startup flicker is a known limitation). Everything wofi does maps
   one to one; the trial config is drafted (drafted in the session's
   scratchpad). Install with `sudo dnf install rofi` when ready; the trial
   binding is $mod+Shift+d at runtime (a second launcher on d takes Shift,
   by the header's third clause).
4. swaylock, swayidle, the official pieces: F5, F15-F18, D1, D5, the lockout
   recovery section, and section 6's lid pair.

## 6. Long-term robustness (your answer: not urgent)

- The docked lid: `bindswitch --reload --locked lid:on output eDP-1 disable`
  and lid:off enable, inert on bigfed; cost on the undocked path is a
  disable/enable of the panel around every suspend. With HandleLidSwitchDocked
  =ignore a docked lid close also neither suspends nor locks; a logind
  drop-in (machine-local, sudo) plus F5's lock handler would lock it.
- Presenting from sway: no mirroring exists; wl-mirror is the tool; a display
  attached at login lands LEFT (x=0) and takes workspace 1, a hotplugged one
  lands right where the up/down monitor chords cannot reach it. Recorded for
  the design session that adopts it.
- fedxps at bigfed's desk: the serial-keyed lines would apply to it too (all
  ten workspaces pinned to the desk monitors).

## 7. Checked and sound (a selection of the 251 entries)

The lock chain's -w/-f pairing, InhibitDelayMaxSec margin (0.2 s measured),
PAM (faildelay 2 s, no faillock); every non-exec binding body parses; the
move keys' `split none` prefix in every state; the walks and the carry
chains, including emptying a workspace; monitor lines inert at start and at
reload; workspace pins fall back to the focused output; the client.* tuples;
the swaynag flags; the screenshot cancel guard against slurp 1.5; the
GRIM_DEFAULT_DIR finding; the wofi toggle; mako's timeouts and activation;
the battery events; the output exclusion by identifier; `.modules-right >
widget > *`; layer top versus fullscreen; Waybar's memory is flat (70 MB);
the sway-split watcher's process structure and stop paths; both suites pass
twice; the mutation claims re-run; the record's annotations intact; every
bindsym on the README card; assign-cgroups' scopes; the portal Inhibit=none
is right to keep; kanshi not wanted; xkb parity (none set on either side).

## 8. Workers

Every worker: the workflow's default subagent, Opus 5.5, effort xhigh, read-
only against the live session, confined to its scratch directory. Reviewers
(R) and their skeptics (V) by dimension:

| dim | task |
|---|---|
| R01/V01 | sway/config directives and binding bodies against sway 1.11 |
| R02/V02 | session chain: GDM, sway-systemd, portals, D-Bus, PATH (TODO 29) |
| R03/V03 | power, lid, lock, suspend: the fail-closed audit |
| R04/V04 | Waybar 0.15: config, stylesheet, modules, the bar as a process |
| R05/V05 | mako, wofi, swaylock semantics beyond key validity |
| R06/V06 | bin/sway-split and the two suites |
| R07/V07 | documentation drift, cross-file wiring, the public boundary |
| R08/V08 | the i3/sway idiom against his grammar |
| R09/V09 | binding policy, ergonomics, GNOME consistency |
| R10/V10 | input: keyboard and touchpad versus GNOME |
| R11/V11 | outputs, rendering, the page-flip errors |
| R12/V12 | one config, two machines: the per-machine mechanism |
| R13/V13 | screenshots, clipboard, volume, brightness, media keys |
| R14/V14 | failure paths and recovery |

Five were restarted by the harness after the 15:18 spend-limit pause: R14,
V01, V04, V05, V06.

## 9. Where this lives

Filed here, `docs/sway-audit-2026-09-30/`, as the campaign's dated record;
the decisions and the open remainder are in `DECISIONS.md` and `TODO.md`.
