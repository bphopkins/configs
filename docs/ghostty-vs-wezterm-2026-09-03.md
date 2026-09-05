# Ghostty against WezTerm — measured on fedxps, 2026-09-03

Dated record; the title names the date the campaign opened, not the file's whole
span — addenda are dated in place below. Prompted by an impression that Ghostty
"feels slightly faster",
taken after the Ghostty stow package was written as a deliberate transcription
of `~/.wezterm.lua` (`ghostty/config`, which carries the settings themselves).

**Verdict, as both ship: the impression is right and understates it.** Ghostty
drains plain output ~2.2–2.6x faster, attribute-heavy output ~1.4–1.5x faster,
and answers a cursor-position query ~37x faster. Process contention, grid size,
frame-rate caps and the graphics stack were each checked and excluded.

**But the latency half of that is one WezTerm default, and it is a one-line
fix.** `mux_output_parser_coalesce_delay_ms` defaults to 3. Setting it to 0
takes WezTerm's round trip from 3588 µs to **137 µs** — against Ghostty's 90 —
closing a 37x gap to about 1.5x, at no measurable throughput cost. The
throughput half is compute and survives: no setting reaches it.

Scope: fedxps, GNOME/Wayland, Mesa GL, 1920x1080@59.934. Ghostty 1.3.1-4.fc44
(RPM), WezTerm nightly 20260901_002820_4fbd6b8e. One machine, one session; not
re-run on bigfed.

## Numbers

Harness: 200000 plain ASCII lines and 60000 lines carrying SGR colour plus
bold/faint/italic, one fixed deterministic corpus so both terminals consume
identical bytes; best of three; plus 300 `CSI 6n` round trips in raw mode.

| run | cells | plain 200k | sgr 60k | cursor round-trip |
|---|---|---|---|---|
| Ghostty, first pass | 4940 | 366 ms | 201 ms | — |
| Ghostty, second pass | 4940 | 433 ms | 219 ms | 95 µs |
| WezTerm, shared GUI process | 4512 | 947 ms | 325 ms | 3585 µs |
| WezTerm, `--always-new-process` | 4000 | 935 ms | 310 ms | 3540 µs |

Per line: Ghostty 1.83–2.17 µs plain and 3.35–3.65 µs with attributes; WezTerm
4.67 µs and 5.17 µs.

## Excluded explanations

- **Process contention.** WezTerm runs every window in one GUI process, so the
  first WezTerm run shared pid 6041 with a live Claude Code TUI. Re-running
  under `wezterm start --always-new-process` in a separate pid moved plain by
  1.3%, sgr by 4.6% and the round trip by 1.3%. Contention explains none of it.
- **Grid size.** Every WezTerm run drew *fewer* cells than Ghostty — 4512 and
  4000 against 4940, the last 19% fewer — and lost anyway. The confound runs
  the wrong way throughout.
- **Line wrapping.** Longest corpus lines are 62 and 38 visible columns, under
  every grid measured, so no run paid a wrap cost another avoided.
- **Frame-rate cap.** WezTerm's `max_fps` defaults to 60 and the panel reports
  59.934 Hz as its only mode. No headroom was being lost.
- **Graphics stack.** WezTerm runs OpenGL here, not the WebGpu its recent
  versions default to: the live `wezterm-gui` maps `libEGL_mesa`, `libEGL`,
  `libgallium` and no `libvulkan`. Forcing `front_end="WebGpu"` in a fresh
  process **did** engage — that process additionally mapped `libvulkan` and
  `libvulkan_intel`, and `wezterm.gui.enumerate_gpus()` ranks the Intel HD 630
  Vulkan adapter above the llvmpipe CPU one, so hardware Vulkan was selected
  and not a software fallback. It changed nothing measurable: 939 ms / 334 ms /
  3566 µs against a same-session OpenGL control at 953 ms / 334 ms / 3555 µs.
  The renderer is not the bottleneck, and this is the strongest of the four
  exclusions because the alternative was proven to be running.

## The multiplexer explanation, withdrawn

An earlier draft of this file attributed the gap to WezTerm routing local pane
*data* through its multiplexer, citing `wezterm_mux_server_impl::local >
writing pdu data buffer` from the journal. Read in context, that line is the
existing GUI instance failing to write a **spawn response** back to a `wezterm
start` client that had already disconnected — window-creation RPC, not per-byte
terminal output. WezTerm does model local panes in a `Mux`, but in-process, and
nothing measured here puts PDU serialisation on the data path. The claim outran
its evidence and is withdrawn.

What remains true is narrower: `wezterm cli list` can address a live local
pane, so some such layer exists. Whether it costs anything per byte was never
tested.

Ghostty's io_uring event loop was offered as a second mechanism when this was
first written and is **withdrawn**. Ghostty's own documentation for
`async-backend` states that its benchmarks found no statistically significant
difference between `io_uring` and `epoll` in memory, CPU or latency. The
vendor's published position contradicts the mechanism, so it is not one.

Two Ghostty knobs were checked as possible further gains and rejected:
`window-vsync`, which its documentation says is "only supported currently on
macOS"; and `async-backend`, for the reason just given.

## Where the time actually goes

The harness samples the terminal process's own `utime + stime` around each
phase, which separates work from waiting — the two have identical wall clocks.

| phase | WezTerm | Ghostty |
|---|---|---|
| plain flood | 4020 ms cpu / 2847 ms wall = 141% | 2300 ms cpu / 1440 ms wall = 159% |
| sgr flood | 1410 / 1018 = 138% | 1070 / 681 = 157% |
| 300 round trips | 130 / 1087 = **11%** | 20 / 32 = **62%** |

**There are two bottlenecks here, not one.**

- **Throughput is compute.** Both terminals are CPU-bound and both use more
  than one core. WezTerm burns 4020 ms of CPU where Ghostty burns 2300 ms for
  the same 600000 lines — 1.75x more CPU per byte, 6.7 µs against 3.83 µs per
  line. What that extra work consists of was not identified.
- **Latency is waiting.** WezTerm computes roughly 0.43 ms per reply but takes
  3.6 ms of wall clock, so about 3.2 ms of every round trip is spent not
  running. Ghostty runs at 62% CPU and answers in 0.09 ms. The 37x gap is not
  37x more work; it is a wait that Ghostty does not have.

Typing latency is the wait, not the work. That is why the impression which
prompted this investigation was about feel rather than throughput, and why the
throughput figures alone would have under-predicted it.

Sampling `/proc/<pid>/task/*/wchan` across a 3000-iteration round-trip loop
showed the process almost wholly blocked: `futex_do_wait` on several threads,
and one `wezterm-gui` thread in `hrtimer_nanosleep` — a deliberate timed sleep
— in every sample. That pointed at a timer, and the timer has since been named.

## What WezTerm is waiting on: `mux_output_parser_coalesce_delay_ms`

`wezterm --config <name>=1 ls-fonts` rejects an unknown field by name ("`x` is
not a valid Config field"), which makes it an oracle for probing the config
vocabulary without opening a window. Probing turned up
**`mux_output_parser_coalesce_delay_ms`** — a deliberate delay in the *output
parser*, which is precisely the path a `CSI 6n` reply must traverse.

Established by intervention, three fresh processes, same harness:

| `mux_output_parser_coalesce_delay_ms` | round trip | dsr CPU/wall | plain |
|---|---|---|---|
| unset (control) | 3555–3606 µs | 11% | 935–953 ms |
| `3` | 3588 µs | 12% | 955 ms |
| `0` | **137 µs** | **86%** | 936 ms |

Three findings follow.

1. **The default is 3.** Setting it explicitly to 3 reproduces the control to
   within noise; the option is the whole of the wait.
2. **Zero collapses the latency 26x**, from 3588 µs to 137 µs, and the CPU
   share during the round-trip phase rises from 12% to 86% — the process stops
   waiting and starts working. Ghostty answers in 90 µs, so this closes a 37x
   gap to roughly 1.5x.
3. **It buys nothing here.** Throughput is unchanged: 936 ms against 955 ms
   plain, 324 against 321 sgr, and CPU burned is flat at ~4.1 s either way. On
   this workload the coalescing is pure latency cost.

3 ms of delay plus the 137 µs floor predicts 3.14 ms; 3.59 ms was measured, so
the timer behaves as somewhat more than its nominal value — scheduling and
timer granularity, not investigated further.

The option is named for the **mux**, and that is likely where it earns its
keep: coalescing output arriving over a network from an ssh or tls domain. For
a local pane it is a tax. Not tested against a remote domain, so the case for
the default is untested rather than disproven.

## Why the default is 3, and what zero costs

Wez Furlong's own account: WezTerm deliberately delays escape-sequence
processing to get better batching and less tearing with *non-synchronized*
output, adding up to 3 ms after each read so that a TUI's screen update
coalesces into a single frame. The delay is not carelessness. It is a
**heuristic stand-in for a frame boundary the application never declared** —
the terminal waits a moment to see whether more of the same redraw is coming.

Which raises the question of why WezTerm has to guess when Ghostty does not.
Measured here, the asymmetry is in what each terminal advertises:

| | TERM | `Sync` terminfo capability |
|---|---|---|
| Ghostty | `xterm-ghostty` | `Sync=\E[?2026%?%p1%{1}%-%tl%eh%;` |
| WezTerm | `xterm-256color` | **absent** |

WezTerm ships a `wezterm` terminfo entry that does carry `Sync`, but the
Fedora RPM installs **no terminfo at all** — nothing under `/usr/share/terminfo`
and nothing in `rpm -ql`. So `config.term = "wezterm"` would name an entry this
machine does not have, and is not the fix.

The saving grace is that the good TUIs do not consult terminfo for this. They
ask. `nvim` emits `CSI ? 2026 $ p` (DECRQM) during startup — confirmed by
capturing a bare `nvim -u NONE +q` through a pty — and enables synchronized
output only on an affirmative answer. Both terminals answer affirmatively:

| mode | WezTerm | Ghostty |
|---|---|---|
| 2026 synchronized output | `?2026;2$y` — supported | `?2026;2$y` — supported |
| 2027 grapheme clustering | `?2027;3$y` | `?2027;1$y` |
| 2031 colour-scheme notify | `?2031;0$y` — not recognised | `?2031;2$y` — supported |

So for nvim the coalescing is redundant: nvim declares its frame boundaries
explicitly and WezTerm honours them. **What zero costs is the blanket over
programs that never ask** — anything writing escape sequences without
negotiating 2026 loses the inferred frame boundary and may tear. `1` is the
middle setting if one ever turns up.

Untested: whether the coalescing earns its keep for a *remote* mux domain,
which is what the option is named for. Batching output arriving over ssh or
tls in small packets is a different case from a local pty and may well justify
the default there. A local `unix_domains` pane would test it without a network.

## Can WezTerm be made as fast? Tuned comparison, idle machine

Re-run with the machine handed over and untouched, so these supersede the
earlier figures where noted. WezTerm tuned means
`mux_output_parser_coalesce_delay_ms = 0` and
`mux_output_parser_buffer_size = 1048576`.

**`mux_output_parser_buffer_size` is worth 13%** — two reps each, 200000 lines:

| buffer | plain | | buffer | plain |
|---|---|---|---|---|
| 16 KiB | 1057, 1058 ms | | 1 MiB | **851, 838 ms** |
| default | 968, 973 ms | | 4 MiB | 867, 889 ms |
| 128 KiB | 955, 938 ms | | Ghostty | 446, 400 ms |

The default sits near 128 KiB, 1 MiB is the floor and 4 MiB is past it. It does
not close the gap — tuned WezTerm 844 ms against Ghostty 423 ms is still 2.0x —
it only stops giving away the part that was configuration rather than compute.

**Where the crossover actually is.** Three reps each, 40000 lines of varied
text, 60 visible columns, varying only the number of SGR changes per line:

| SGR/line | WezTerm (3 reps, ms) | Ghostty (3 reps, ms) | median ratio |
|---|---|---|---|
| 0 | 110, 151, 159 | 84, 84, 90 | 1.80x Ghostty |
| 4 | 167, 187, 216 | 145, 152, 172 | 1.23x Ghostty |
| 8 | 223, 226, 236 | 185, 191, 208 | 1.18x Ghostty |
| 16 | 324, 333, 346 | 248, 254, 282 | 1.31x Ghostty |
| 24 | 388, 393, 425 | 354, 382, 394 | 1.03x — tie |
| 32 | 415, 417, 444 | 397, 404, 439 | 1.03x — tie |
| 48 | 551, 575, 579 | 565, 578, 588 | 0.99x — tie |
| 64 | 659, 708, 710 | 712, 714, 751 | 0.99x — tie |

**WezTerm never wins.** The gap closes to a tie by 24 SGR changes per line and
stays flat to 64 — it does not invert. The earlier linear model predicting
WezTerm 1.49x ahead at d=64 was wrong; the curves converge, they do not cross.

Caveat on the d=0 row: it runs first in the sweep and absorbs the terminal's
warm-up, which is why WezTerm's spread there (110–159) is far wider than
anywhere else. The 2.0x figure from the longer 12.6 MB term-bench flood is the
better estimate for sparse text.

**Where real work sits on that curve**, measured on this machine:

| workload | SGR per line |
|---|---|
| `ls --color` (multi-column) | 0.0 |
| `ls --color -la` | 1.7 |
| `git log --oneline --color` | 2.0 |
| `git diff --color` | 2.2 |
| `grep --color` | 11.6 |
| **nvim repaint (treesitter)** | **≥37** |

Everything typed at a shell is sparse and sits where Ghostty leads. Only nvim
is dense enough to reach the tie — and a full nvim repaint is ~75 KB, under a
millisecond either way. **The dense workloads are small and the big workloads
are sparse**, so the crossover is real but lands where the absolute times no
longer matter.

## Method faults found and fixed

Four in the harness (above) and three more in the sweep, all of which produced
plausible numbers that meant nothing:

5. The sweep used `LINES` as a variable. Bash had already set it to the
   terminal height (40), so the derived µs/line column was off by 1000x. The
   `ms` column was unaffected.
6. The first sweep corpus was 60 repeated `x` characters. That is a degenerate
   single-glyph case, and it disagreed with term-bench's ratio on the same
   terminals in the same session. Regenerated with varied text.
7. The contention metric counts all non-terminal CPU, which includes `cat`
   producing the corpus. It is usable as a relative signal across runs of the
   same shape, not as an absolute idleness measure.

Thermal throttling was checked and excluded: counters at zero, package 51 °C,
cores at 3.4–3.8 GHz against a 3.8 GHz max, on a machine whose own records flag
aging thermal paste.

## An inversion worth keeping

Ghostty's lead narrows from ~2.4x to ~1.5x once attributes are involved,
because the marginal cost of the SGR corpus over the plain one is **+1.5 µs per
line for Ghostty against +0.49 µs for WezTerm**. Ghostty pays roughly three
times more per attribute change and still wins on the total, because its
baseline per-line cost is about 2.5x lower. Heavily-coloured output is where
the gap is narrowest; a workload of nothing but SGR churn is where WezTerm
would come closest.

## Where WezTerm wins outright: terminfo over ssh

Added the same day but measured **from bigfed against nousowl**, not on fedxps,
so none of the numbers above are affected. Not a performance finding — a
capability one, and so far the only place where WezTerm is better as it ships.

The `Sync` table above reads as an argument for naming your own terminfo entry:
Ghostty advertises `xterm-ghostty` and gets `Sync` for free, WezTerm advertises
`xterm-256color` and has to infer frame boundaries instead. Over ssh the same
decision runs the other way, because `$TERM` travels and the terminfo database
does not.

Measured on `nousowl`, one binary, two names:

| `$TERM` | `htop` |
|---|---|
| `xterm-ghostty` | `ncurses: cannot initialize terminal type ($TERM="xterm-ghostty"); exiting`, exit 1 |
| `xterm-256color` | runs — exit 124, killed by a 2 s `timeout` |

**The obvious repair does not work, for a reason worth recording.** The entry
declares three names — `infocmp -1 xterm-ghostty` opens
`xterm-ghostty|ghostty|Ghostty` — but no package ships more than one of them,
and the two that ship it disagree about which:

| package | terminfo file it installs | resolves |
|---|---|---|
| `ghostty` | `/usr/share/terminfo/x/xterm-ghostty` | `xterm-ghostty` only; `ghostty` is MISSING even on bigfed |
| `ncurses-term` | `/usr/share/terminfo/g/ghostty` | `ghostty` only; one hit in a 2774-file list |

So `dnf install ncurses-term` on nousowl would install the right entry under
the wrong name, and `term = ghostty` in `ghostty/config` would fix the remote
by breaking the local. Neither box can be made to work by choosing a name;
something has to be installed.

WezTerm never has the problem, and `.wezterm.lua` shows that is a decision
rather than luck — `config.term = "wezterm"` is rejected there precisely
because the Fedora RPM ships no terminfo, so WezTerm reports a name every host
already knows. It buys remote compatibility with the local `Sync` capability,
which is the same trade `mux_output_parser_coalesce_delay_ms` exists to paper
over. One decision, two consequences, and the section above weighed only one.

Ghostty's answer, which WezTerm has no counterpart to, is two
`shell-integration-features`: `ssh-env` rewrites `TERM` to `xterm-256color` on
ssh, and `ssh-terminfo` installs the real entry on the remote with `infocmp`
and `tic`, cached per host. Both were off — the resolved list was
`no-cursor,no-sudo,title,no-ssh-env,no-ssh-terminfo,path`. Enabled together
they are not a compromise between each other: the man page specifies that
Ghostty installs its terminfo and uses `xterm-ghostty`, falling back to
`xterm-256color` only where the install failed. WezTerm's behaviour becomes the
floor and full capability the ceiling, which makes `ssh-env` alone strictly
dominated. `tic` and `infocmp` are both present on nousowl. Turned on in
`ghostty/config`.

**Verified the same day.** `GHOSTTY_SHELL_FEATURES` is read at shell startup,
so the check needs a new window rather than a config reload. In one: `ssh
nousowl`, `echo $TERM` answers `xterm-ghostty`, and `ghostty +ssh-cache` lists
`bph@192.168.0.223` — the cache keys on the resolved address, not on the
`~/.ssh/config` alias. What settles it is the contrast on one binary and one
machine: `htop` under `TERM=xterm-ghostty` exited 1 on `cannot initialize
terminal type` before, and after runs to the same 2 s `timeout` that killed it
in the working case.

`tic` then does what neither packager did — it installed **both** names:

```
3854  ~/.terminfo/x/xterm-ghostty
3854  ~/.terminfo/g/ghostty        (hard link; 4.0K for the pair)
```

It writes one file per alias in the entry's name list, so the split in the
table above is a choice each packager made and not a constraint terminfo
imposes. The result inverts: **nousowl, which has no Ghostty installed, now
resolves both `xterm-ghostty` and `ghostty`; bigfed, which does, still resolves
only the first.**

One consequence outside this repo. `/home/bph` on nousowl went 248K → 252K,
and `nousowl/CLAUDE.md` describes it as holding "shell config and `.ssh`,
nothing else" — there is now a `.terminfo` as well.

## What was not measured

The round trip times the terminal's parse-and-respond loop, which shares
machinery with the keystroke path but runs the other direction and excludes
compositor presentation. It is not input-to-photon latency; that needs hardware
not available here. The 37x is far too large to be an artefact of the proxy,
but no absolute typing-latency figure follows from it. Each `CSI 6n` iteration
also opens `/dev/tty` twice, a constant that inflates both sides equally and so
understates the ratio rather than flattering it.

## Harness

`term-bench` and `sgr-sweep`, kept in `tests/term-bench/` with a README
naming every trap below; corpora regenerate on demand and are not committed.
Two bugs
were found in it before the numbers above were taken, both of which would have
produced a confident wrong answer:

1. `$(throughput …)` captured `cat` into a pipe, so the first version timed
   pipe throughput and never rendered to the screen. It reported both terminals
   as identically fast.
2. `dsr_us=$(dsr)` piped stdout, so the function's `[[ -t 1 ]]` guard was false
   on a perfectly good terminal and the latency test silently reported "no tty"
   in both runs. The guard now probes `/dev/tty` directly and the function sets
   a global rather than being captured.
3. Terminal identity was read from `GHOSTTY_*` / `WEZTERM_PANE` environment
   variables, which children inherit. A WezTerm launched from a Ghostty window
   reported itself as Ghostty. Identity now comes from walking the process tree
   to the owning `wezterm-gui` / `ghostty` process, which cannot be inherited.
4. The renderer libraries were sampled from `/proc/<pid>/maps` at startup, when
   the terminal has already spawned the shell but not yet finished bringing up
   its GPU context — so the field read empty and was mislabelled "unreadable".
   It is now sampled at both ends of the run, and the start sample is reliably
   empty, which is what exposed the ordering.

Anything measuring a terminal must reach the terminal. A capture that makes the
measurement quiet and plausible is the failure mode to watch for here.

## Addendum, 2026-09-05: the configuration surface, and two corrections

Same machine, **sway rather than GNOME** — everything above was taken under
GNOME/Wayland and none of it is re-run here. This addendum is configuration
only: no number above is revised and nothing below was timed.

Prompted by a survey of what Ghostty exposes that the transcription never
touches — 613 config keys, about 190 distinct options, against the 13 areas
`ghostty/config` sets — read from `ghostty +show-config --default --docs` on
1.3.1-4.fc44. The audit that followed asked the narrower question: is anything
in `.wezterm.lua`, custom *or* default, missing on the Ghostty side.

### Correction 1: WezTerm does not spawn a process per window

`ghostty/config`'s Window section justifies `--gtk-single-instance=false` partly
on the claim that "WezTerm reaches both behaviours the same way, by spawning a
process per window". It does not:

```
$ wezterm start --help
  --always-new-process
      If enabled, don't try to ask an existing wezterm GUI instance to
      start the command. ...
```

The flag exists to *opt out* of instance reuse, so reuse is the default. WezTerm
locates the running GUI through a per-display socket symlink —
`/run/user/1000/wezterm/wayland-wayland-1-org.wezfurlong.wezterm -> gui-sock-<pid>`
— a unix socket where Ghostty uses a D-Bus name, the same architecture either
way. And `sway/config` carried bare `set $term wezterm` from 2025-11-09 to
2026-09-03, so that was the path in use throughout.

**This file already knew.** The process-contention exclusion above opens
"WezTerm runs every window in one GUI process", and the numbers table carries an
`--always-new-process` row. The correct fact was recorded here on the day; the
config comment written the same day contradicts it.

What actually differs is cwd *resolution*, not process topology. WezTerm's
documented order for a non-initial window is OSC 7 → process-group-leader cwd →
`default_cwd` → home; Ghostty's `window-inherit-working-directory` consults the
last-focused surface in the process, which an external invocation also sees, so
`working-directory` never gets a turn after the first window. Whether a WezTerm
window requested from *outside* has a "current pane" to resolve against is not
addressed by its documentation and **was not tested**. The test: open a Ghostty
window somewhere other than `~/Desktop`, launch `wezterm` from the sway binding,
run `pwd`.

The fix itself is unaffected — on Ghostty the flag demonstrably produces the
wanted behaviour, and `busctl --user status com.mitchellh.ghostty` confirms the
mechanism, the running process owning no well-known name so that a second
invocation has nothing to hand off to. Note also that `gtk-single-instance`
defaults to `detect`, which disables single-instance if *any* CLI argument is
present: `--title=foo` would have worked by accident.

### Correction 2: four settings without a counterpart, not two

The header says two. `font_rules` Half and `check_for_updates` are named;
`mux_output_parser_coalesce_delay_ms` and `mux_output_parser_buffer_size` appear
nowhere in `ghostty/config`. The omission is defensible — those two are repairs
to WezTerm defects rather than expressions of preference, and Ghostty has no
defect to repair — but the count is wrong as written.

### Unstated default divergences

Neither file sets these and the two defaults disagree. WezTerm values are from
wezterm.org and **were not measured here**; Ghostty values from
`+show-config --default`.

| | WezTerm | Ghostty | disposition |
|---|---|---|---|
| `window_padding` | `1cell` L/R, `0.5cell` T/B | 2 points | left; preferred as found |
| `hide_mouse_cursor_when_typing` | `true` | `false` | **matched to WezTerm** |
| `enable_scroll_bar` | `false` | `system` | left; see GTK below |
| `automatically_reload_config` | `true` | none | unavailable |
| `selection_word_boundary` | `` \t\n{}[]()"'` `` | adds `:;,<>$\|│` | left; Ghostty's judged better |
| `audible_bell` | `SystemBeep` | `no-audio` | left; nominal only |
| cursor blink rate | 800 ms | no knob | immaterial |

The padding row is the largest visible divergence in a file that claims
like-for-like, and it is the one row not verified locally — worth an eyeball
before it is relied on. The bell row is nominal in both directions: WezTerm's
own docs say `SystemBeep` produces no audio on Wayland, while Ghostty's
`attention` default already decorates the sway window with the urgent border and
`audio` with `bell-audio-path` has worked on GTK since 1.2.0. The word-boundary
row was judged in Ghostty's favour for this workload: breaking at `:` means
double-clicking `main.tex:412:` from latexmk or grep grabs the path alone.

**Auto-reload is unavailable and upstream says so.** `man ghostty`: "We plan to
auto-reload in the future, but Ghostty isn't capable of this yet." No
signal-based reload is documented either — zero hits for `SIGUSR`/`SIGHUP` —
which also rules out a file watcher, because a watcher would have nothing to
call. `ctrl+shift+,` is the whole of it. Untested: whether a single-instance
Ghostty exposes a reload action over `org.gtk.Actions` on its D-Bus name.

### Where WezTerm wins outright, second entry: copy mode

`ctrl+shift+x` enters a modal, vim-keyed scrollback navigation and selection
mode. **Ghostty has no equivalent and one cannot be built.** The mechanism
ships — `activate_key_table`, `adjust_selection`, the `scroll_*` family — but
`+list-actions --docs` on `adjust_selection` reads "This does not create a new
selection, and does nothing when there currently isn't one." No action begins a
selection from the keyboard, so the key tables have nothing to act on.

Also absent, comparing `wezterm --config-file /dev/null show-keys` against
`ghostty +list-actions`: `QuickSelect` (hint labels over URLs and paths,
`ctrl+shift+space`), `CharSelect` (Unicode picker, `ctrl+shift+u`), and Lua
config with event hooks, which Ghostty declines by design. Search is covered on
both sides, as are `clear_screen`, `move_tab`, `paste_from_selection` and link
opening.

Two substitutes, neither equivalent: `write_scrollback_file:paste` hands the
buffer to Neovim, a larger toolset at the cost of leaving the terminal; and
tmux's own copy-mode would restore the capability inside Ghostty, which is one
argument for learning tmux directly.

### Where Ghostty wins: the Nerd Font cut

Neovim's tabline icons render better in Ghostty, and the tab bar has nothing to
do with it — those glyphs are drawn by Neovim in ordinary cells. The two
terminals fall back to **different cuts of the same font**:

| | face for U+F00D | evidence |
|---|---|---|
| WezTerm | `Symbols Nerd Font Mono` | `ls-fonts`: `<built-in>`, `x_adv=12.5 cells=1` |
| Ghostty | `Symbols Nerd Font` | `+show-face --cp=0xf00d` |

Mono constrains every glyph to one monospace cell; the plain cut keeps natural
proportions. Both are compiled into the binaries — neither RPM ships a font file
and `fc-match "Symbols Nerd Font"` falls through to Noto Sans.

Tunable by `adjust-icon-height` on the Ghostty side (Powerline and box-drawing
glyphs excluded, since Ghostty draws those itself) and by `font_with_fallback`
plus per-font `scale` on WezTerm's. **Not** interchangeable: each binary embeds
only its own cut and no Nerd Font is installed system-wide, so a swap needs a
package first. Checked and clear — waybar, wofi and mako use no private-use-area
glyphs, so nothing outside a terminal depends on the gap.

### Where WezTerm wins on aesthetics, accepted deliberately

One design decision, two visible consequences. **WezTerm draws its own tab
bar** — hence `use_fancy_tab_bar`, and a retro mode one terminal row tall in the
configured font. **Ghostty delegates to GTK**: `gtk-wide-tabs`,
`gtk-tabs-location`, `gtk-toolbar-style`, and `gtk-custom-css` to style the
result. The tab bar is a libadwaita widget sized by GTK metrics rather than by
the 12pt cell, and `scrollbar = system` defers to the GTK setting outright.

So "the GTK stuff interferes with the aesthetics" is a single observation about
one decision, surfacing in the two places that decision is visible. The ceiling
is structural: CSS can shrink the bar, nothing can make it grid-aligned.

Levers identified and not taken: `gtk-wide-tabs = false`,
`window-show-tab-bar = never`, `scrollbar = never`, `gtk-custom-css` (node names
via `env GTK_DEBUG=interactive ghostty`). `gtk-titlebar-style = tabs` is moot
under `window-decoration = none`, the same trap `ghostty/config` already records
for `gtk-titlebar`. **Left as shipped, deliberately**: tabs are used
occasionally and the scrollbar is wanted, so the GTK integration is kept as part
of the experiment rather than styled away.

### Changed in the repo

- `ghostty/config` — new `# --- Mouse ---` section carrying
  `mouse-hide-while-typing = true`, the first setting here whose WezTerm
  counterpart is a default rather than a `.wezterm.lua` line.
- `bash/.bashrc.d/30-prompt.sh` — `PROMPT_HIGHLIGHT=1`. Not a terminal finding,
  but it surfaced here: Fedora's `bash-color-prompt` gates bold on
  `[ "$DESKTOP_SESSION" = "gnome" ]`, so the prompt came out bold under GNOME on
  bigfed and plain under sway on fedxps from a package default rather than a
  choice. The module carries the mechanism.

### Open

- **Whether `linux-cgroup = always` is worth ~100 ms per window.** Measured:
  under `--gtk-single-instance=true` the shell sat in
  `app-ghostty-surface-transient-13234.scope`, a per-surface scope Ghostty
  creates; under the sway launcher's `=false` it shares
  `app-com.mitchellh.ghostty-17355.scope` with the GUI process itself, because
  `linux-cgroup` defaults to `single-instance` and so stops applying. Whether
  that matters, given one surface per window already in its own process and
  scope, is unsettled.
- The WezTerm cwd test named under Correction 1.
- Ghostty's notification volume under GNOME. `app-notifications` is the lever;
  a machine-local layer would need `config-file = ?config.local`, since
  `ghostty/config` is synced and only bigfed runs GNOME.

## Addendum 2, 2026-09-05: the real workload, and what it overturns

Ghostty 1.3.1-4.fc44 unchanged; **WezTerm now 20260905_153129_092dcf70**, not the
20260901 build the numbers at the top were taken against. fedxps, sway. Every
figure below is a fresh measurement; none of the originals are adjusted in place.

Two conclusions from the original campaign do not survive, and one prediction
made in Addendum 1 was tested and failed.

### The grid is finally controlled

The instruction "keep this equal across runs" was never actually met: sway sizes
the window and the two terminals derive different cell counts from the same
pixels, so a term-bench pass had Ghostty at 63x52 against WezTerm at 100x40 —
WezTerm drawing 22% more cells, the confound running the *opposite* way to the
original campaign's. Both are now pinned to **1200x700 px = 100x40 cells** with
live sway float rules; the procedure is in `tests/term-bench/README.md`.

Getting there exposed a measurement bug worth naming: the grid is not stable
when the shell starts, because the WM resizes the window afterwards. Every grid
figure read at t=0 — including some above — was read at the wrong moment. The
harnesses now wait for three consecutive identical readings. Trap 8.

Trap 1 also bit a second time, in the new `repaint-bench`, where `rows=$(run …)`
put `cat` down a pipe and swallowed 1.6 GB of corpus into a shell variable. The
timing helpers now set a global.

### Every measurement above is scroll-shaped. The real workload is not.

`cat`-ing a corpus appends lines and scrolls them off. nvim does none of that:
alternate screen, cursor addressing, cells overwritten in place, frames wrapped
in DEC mode 2026. So a real session was **recorded** rather than simulated —
nvim over a 572-line chapter, 80 forced repaints, captured through a pty tee
that forwards stdin so the DECRQM probes still reach the terminal and are
answered. The capture is representative: **75676 SGR sequences, 24040
truecolour, zero palette, 174 synchronized-output markers.** Replayed as a
115 MiB alternate-screen corpus of 8700 frames, three rounds interleaved:

| | wall | terminal CPU | per frame |
|---|---|---|---|
| **Ghostty** | **3841 ms** | **5200 ms** | **0.44 ms** |
| WezTerm | 8953 ms | 10100 ms | 1.03 ms |

**2.33x wall, 1.94x CPU**, spread under 1.5% across rounds.

**This inverts the synthetic result.** `color-sweep` says Ghostty costs 1.34–1.50x
*more* CPU at 64 SGR changes per line. Real nvim — denser than that, and fully
truecolour — has it costing half. A synthetic attribute density does not predict
repaint-shaped work, and the crossover table above should not be read as
describing nvim, which is the workload it was invoked to explain.

### The sparse-text headline is a cold-cache figure

| plain 12.6 MiB, 100x40 | Ghostty | WezTerm |
|---|---|---|
| cold, first rep ever | 520 ms | 858 ms |
| best of 3, still early | 416 ms | 878 ms |
| best of 3, after the 115 MiB repaint corpus | **376 ms** | **334 ms** |

Warm, **WezTerm is slightly ahead**. The 2.0–2.6x at the top of this file is a
cold-start measurement. Three reps of the plain corpus do not warm WezTerm —
only the large varied workload does, which points at allocator free-list warmth
rather than a glyph cache. Trap 9.

Alternate-screen versus normal-screen flooding barely differs for either
terminal, so scrollback storage is not a significant cost for either.

### Latency under load: the best explanation yet for "feels faster"

Every round-trip figure above was taken on an idle terminal. Under sustained
output, measured over a fixed window with timeouts counted separately:

| | idle | under load | trips serviced in 6 s |
|---|---|---|---|
| Ghostty | 76 us | **~25 ms** | 217 |
| WezTerm | 91 us | **~211 ms** | 30 |

**1.2x idle, 8.6x under load.** A fifth of a second to answer while output is
streaming is squarely the difference between "laggy" and "fine", and it matches
the impression that prompted this whole investigation far better than any
throughput number does. A first attempt reported 1.4 s for WezTerm and was
discarded: it was saturating its own 2 s read timeout, conflating "no reply"
with "slow reply". Trap 11.

### Configurability: closed empirically

All five LRU cache knobs at 16x their defaults (`shape_cache_size`,
`line_state_cache_size`, `line_quad_cache_size`, `line_to_ele_shape_cache_size`
at 1024; `glyph_cache_image_cache_size` at 256), on the repaint workload:

| WezTerm | repaint wall | repaint CPU | RSS after |
|---|---|---|---|
| default | 8953 ms | 10100 ms | 143 MB |
| caches 16x | 8713 ms | 9865 ms | **594 MB** |

**+2.7% for 450 MB of RAM.** The caches are not the bottleneck. Together with
the config enumeration in Addendum 1, WezTerm cannot be configured out of the
repaint gap — now measured rather than inferred.

### Memory, with scrollback eliminated

The repaint corpus runs entirely in the alternate screen, so nothing accumulates
in scrollback and the two capping policies stop confounding the comparison:

- Ghostty grows **+2–4 MB**
- WezTerm grows **+38–48 MB**

Tenfold, on identical input, with storage policy ruled out.

### The Addendum 1 truecolour prediction, withdrawn

Addendum 1 predicted from source that truecolour would cost WezTerm
disproportionately, because `SmallColor` is only `{Default, PaletteIndex}` and
truecolour must spill to `Box<FatAttributes>`. The `idx`-versus-`true` arms of
`color-sweep` hold attribute-change count constant at 2.56M and test exactly
that:

- WezTerm 1005 → 1510 ms = **+505 ms**
- Ghostty 1510 → 2025 ms = **+515 ms**

Indistinguishable. The extra cost of truecolour is the longer escape sequence on
both sides, not the allocation. The spill is real in the source and undetectable
at this resolution; the prediction is **withdrawn**. What the source reading did
get right was the *shape* of the scroll-shaped curve and the fact that it
crosses — which then turned out not to describe the real workload anyway.

### Where the comparison actually stands

Ghostty is substantially the better fit here, but for reasons this campaign had
not identified until now. The advantage is **repaints** (2.3x) and
**responsiveness while output streams** (8.6x). It is *not* raw flooding, where
the two are equal once warm, and it is not the crossover story.

New instruments in `tests/term-bench/`: `capture-nvim`, `ptytee.py`,
`repaint-bench`, `latency-bench`, `color-sweep`, `gen-color-corpora.py`.

## Addendum 3, 2026-09-05: bigfed, and two predictions refuted

The scope line at the top said "one machine, one session; not re-run on bigfed."
It has now been re-run on bigfed, driven over ssh from fedxps into the live
GNOME session. **Nothing was written outside `/tmp` on bigfed and all its repos
were verified clean before and after.**

What is controlled: **identical software** — Ghostty 1.3.1-4.fc44 and WezTerm
20260905_153129_092dcf70 on both, neovim 0.12.5 on both, `configs` at the same
HEAD (`bfc7647`, clean). **Identical input** — `completeness.tex` md5
`82896f20…` on both; the two nvim captures agree within 0.5% on bytes, SGR
count, truecolour count and cursor positionings. **Identical grid** — 100x40.

| | fedxps | bigfed |
|---|---|---|
| CPU | i7-7700HQ, 4C/8T, **6 MiB L3** | Ryzen 7 3800X, 8C/16T, **32 MiB L3** |
| GPU | Intel HD 630 | Radeon RX 5700 XT (Navi 10) |
| RAM | 15 GiB | 31 GiB |
| Session | sway / wlroots | GNOME / Mutter |

**The confound to keep in view: hardware and desktop environment are perfectly
correlated here.** Nothing below separates "Zen 2 with a discrete GPU" from
"Mutter rather than wlroots". Doing so would need sway on bigfed or GNOME on
fedxps, and neither was attempted.

One incidental relief: the grid control that had to be engineered with
`swaymsg` float rules on fedxps is **free on GNOME**. With no tiling WM
overriding them, both terminals simply open at the size their configs request,
and both landed on 100x40 unprompted.

### The results

Repaint corpus, 8800 frames, three rounds interleaved, medians:

| | fedxps wall | bigfed wall | fedxps CPU | bigfed CPU |
|---|---|---|---|---|
| Ghostty | 3841 ms | 1983 ms | 5200 ms | 3050 ms |
| WezTerm | 8953 ms | 5651 ms | 10100 ms | 6360 ms |
| **ratio** | **2.33x** | **2.85x** | **1.94x** | **2.09x** |

Latency, two rounds:

| | fedxps | bigfed |
|---|---|---|
| idle, Ghostty / WezTerm | 76 / 91 us | 47 / 46 us |
| under load, Ghostty / WezTerm | 25 / 211 ms | **7.4 / 145 ms** |
| **ratio under load** | **8.6x** | **19.7x** |
| trips serviced in 6 s | 217 / 30 | 662 / 44 |

### Refuted: the L3 hypothesis

Addendum 2 identified the mechanism as a memory-footprint difference — 8-byte
packed cells against `TeenyString` plus inline `CellAttributes` — and it was
predicted here that bigfed's much larger L3 might blunt it, since a working set
that thrashes 6 MiB may fit in 32 MiB.

**It does not.** The gap is *wider* on bigfed, in both wall (2.33x → 2.85x) and
CPU (1.94x → 2.09x). Whatever WezTerm's extra cost consists of, a 5.3x larger
last-level cache does not absorb it. The prediction is withdrawn.

### Refuted, and backwards: the grid-size hypothesis

It was also predicted that a much larger grid would *dilute* Ghostty's lead,
on the reasoning that per-frame render work scales with cells while per-byte
parse work does not, so the GPU side would come to dominate. Both terminals
honour explicit cell counts, so this was tested directly at **300x60 = 18000
cells, 4.5x the 4000 above**, with a corpus re-captured at that grid:

| per frame | 4000 cells | 18000 cells | growth |
|---|---|---|---|
| Ghostty | 0.225 ms | 0.312 ms | **1.39x** |
| WezTerm | 0.642 ms | 1.874 ms | **2.92x** |

At the large grid the ratio is **6.0x wall and 4.2x CPU**, against 2.85x and
2.09x at the small one. The prediction was not merely wrong but inverted:
**Ghostty absorbs 4.5x the cells for 1.39x the cost, WezTerm needs 2.92x.**
Render cost never takes over, because the cost was never on the GPU — it is
per-cell work in the terminal, which is exactly where the cell representation
decides the outcome. On a large display with large windows, Ghostty's advantage
grows.

### WezTerm does not use the extra cores

CPU-versus-wall during the plain flood, from `term-bench`:

| | fedxps | bigfed |
|---|---|---|
| Ghostty | 167% | **189%** |
| WezTerm | 131% | **129%** |

Ghostty spreads further when given twice the cores; WezTerm does not move. That
is most of why the wall-clock ratio widens more than the CPU ratio does.

### What held on both machines

- **Repaints favour Ghostty substantially** — the Addendum 2 headline, confirmed
  on different hardware and a different compositor.
- **Warm plain throughput is a tie, tilting to WezTerm**: 376 vs 334 ms on
  fedxps, 225 vs 190 ms on bigfed.
- **The cold/warm effect is real and larger on bigfed.** WezTerm improves
  2.6x → 3.4x between its first flood and one after the repaint corpus; Ghostty
  1.4x → 1.03x. A single cold flood measures warm-up, not steady state,
  and it measures it worse on the faster machine.
- **The memory ratio.** Through the repaint corpus alone, with scrollback
  eliminated: Ghostty +5.7 MB against WezTerm +50 MB at 100x40, and +40 MB
  against +92 MB at 300x60.

### Verdict

The comparison is portable, and every difference between the machines moved in
the same direction: **on the faster, wider, more parallel machine Ghostty's
advantage is larger, not smaller** — 2.85x rather than 2.33x on repaints, 6.0x
at a full-size window, 19.7x rather than 8.6x on latency under load. The two
mechanisms proposed for why bigfed might narrow it were both tested and both
failed.
