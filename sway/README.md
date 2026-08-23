# Sway bindings — quick reference

Every active binding in `config`, grouped by the binding grammar (adopted
2026-08-22): **the modifier names what the action acts on.** The full statement
of the law lives at the top of `config`; this file is the lookup card.
Hand-maintained as a best-effort courtesy: `config` is authoritative and this
file may lag it — the test suite deliberately does not check the two against
each other.

Named `README.md` on purpose: stow's default ignore list covers `README.*`, so
this file is never symlinked into `~/.config/sway/` and adding it needed no
restow.

`$mod` = Super. `$alt` = Alt. Every motion takes both vim keys and arrow keys.
Escape and Print chords are listed with their key families at the end, not in
the tier tables.

## `$mod` — you: attention, instruments, summoning

| chord | does |
|---|---|
| `$mod+h/j/k/l`, arrows | move focus left / down / up / right |
| `$mod+1` … `$mod+0` | go to workspace 1–10 |
| `$mod+Tab` | bounce to the previously focused workspace |
| `$mod+space` | swap focus between the tiling and floating layers |
| `$mod+minus` | show the scratchpad (cycles if several; press again to re-hide) |
| `$mod+Return`, `$mod+t` | terminal (WezTerm) |
| `$mod+a` | app menu (wofi) |
| `$mod+b` | Brave |
| `$mod+c` | Chrome |
| `$mod+d` | Nautilus at `~/Desktop` |
| `$mod+f` | Nautilus |
| `$mod+x` | text editor (GNOME Text Editor) |
| `$mod+w` | toggle Waybar |
| `$mod+m` | toggle the touchpad |
| `$mod+q` | close the focused window *(promoted window verb)* |
| `$mod+r` | enter resize mode *(promoted window verb; keys below)* |

Mouse: `$mod`+left-drag moves a window, `$mod`+right-drag resizes — tiled
windows included.

## `$mod+Shift` — the focused window

| chord | does |
|---|---|
| `$mod+Shift+h/j/k/l`, arrows | move the window left / down / up / right (an orthogonal move restacks the layout) |
| `$mod+Shift+1` … `0` | send the window to workspace 1–10 |
| `$mod+Shift+minus` | stash the window in the scratchpad |
| `$mod+Shift+space` | toggle the window between tiling and floating |
| `$mod+Shift+f` | toggle the window fullscreen |

## `$mod+Ctrl` — the session

| chord | does |
|---|---|
| `$mod+Ctrl+l` | lock the screen (swaylock) |
| `$mod+Ctrl+c` | reload this config |

## `$mod+$alt` — the workspace row

| chord | does |
|---|---|
| `$mod+$alt+h/l`, Left/Right | walk to the previous / next existing workspace |
| `$mod+$alt+Shift+h/l`, Left/Right | the same walk, carrying the focused window |

## Key families — they override the tiers on their own key

**Escape: leaving, graded by weight**

| chord | does |
|---|---|
| `$mod+Escape` | exit sway (ends the Wayland session) — confirmation nag |
| `$mod+Shift+Escape` | machine off — nag offers Poweroff and Reboot |

**Print: capture**

| chord | does |
|---|---|
| `Print` | whole screen → file in `~/Pictures` |
| `Shift+Print` | pick a region → clipboard (Esc cancels harmlessly) |
| `$mod+Print` | pick a region → file in `~/Pictures` |

**XF86: hardware — these keep working on the lock screen**

| chord | does |
|---|---|
| `XF86AudioMute`, `XF86AudioMicMute` | mute output / microphone |
| `XF86AudioLowerVolume`, `XF86AudioRaiseVolume` | volume -5% / +5% |
| `XF86MonBrightnessDown`, `XF86MonBrightnessUp` | brightness -5% / +5% |

## Resize mode — enter with `$mod+r`

| key | does |
|---|---|
| `h`, `Left` | shrink width 10px |
| `j`, `Down` | grow height 10px |
| `k`, `Up` | shrink height 10px |
| `l`, `Right` | grow width 10px |
| `Return`, `Escape` | back to normal mode |
