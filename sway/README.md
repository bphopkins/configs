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
| `$mod+a` | focus the parent container (select the whole column or fold) |
| `$mod+z` | focus back down to the child |
| `$mod+1` … `$mod+0` | go to workspace 1–10 |
| `$mod+Tab` | bounce to the previously focused workspace |
| `$mod+space` | swap focus between the tiling and floating layers |
| `$mod+minus` | show the scratchpad (cycles if several; press again to re-hide) |
| `$mod+Return` | terminal (Ghostty) |
| `$mod+d` | app menu (rofi); again to close it |
| `$mod+b` | Brave |
| `$mod+c` | Chrome |
| `$mod+f` | Nautilus at `~/Desktop` |
| `$mod+x` | adelotype, the typeface scratchpad (`~/Desktop/adelotype`) |
| `$mod+w` | toggle Waybar |
| `$mod+m` | toggle the touchpad (a notification says which way) |
| `$mod+n` | dismiss the newest notification |
| `$mod+q` | close the focused window, and only a window: with a column, fold or workspace selected it does nothing *(promoted window verb)* |
| `$mod+r` | enter resize mode; again to leave *(promoted window verb; keys below)* |

Mouse: `$mod`+left-drag moves a window, `$mod`+right-drag resizes — tiled
windows included. In a fold's strip: click a title to focus it, middle-click
it to close that window, scroll across the strip to step through the tabs,
drag a title to move that window. Touchpad: a three-finger swipe walks the
workspaces (left brings in the next one).

Held keys: every toggle, launcher and window verb fires once however long the
chord is held; motions, walks, volume, brightness and resize keys repeat.

## `$mod+Shift` — the focused window

| chord | does |
|---|---|
| `$mod+Shift+h/j/k/l`, arrows | move the window left / down / up / right (an orthogonal move restacks the layout; a pending `$mod+Shift+v`/`b` split is dropped) |
| `$mod+Shift+1` … `0` | send the window to workspace 1–10 |
| `$mod+Shift+minus` | stash the window in the scratchpad |
| `$mod+Shift+space` | toggle the window between tiling and floating |
| `$mod+Shift+f` | toggle the window fullscreen |
| `$mod+Shift+v` | the next window opens below this one; again to cancel; from beside, flips (↓ below on an orange block in the bar, and an orange bottom edge, while set; floating windows are left alone) |
| `$mod+Shift+b` | the next window opens beside this one; again to cancel; from below, flips (→ beside on an orange block in the bar, and an orange right edge, while set) |
| `$mod+Shift+s` | fold the windows here into tabs, one showing at a time; again to unfold |

## `$mod+Ctrl` — the enclosures, and the session

| chord | does |
|---|---|
| `$mod+Ctrl+r` | rotate the container around the window: a row becomes a column, and back; also unfolds tabs to the split they came from |
| `$mod+Ctrl+l` | lock the screen (swaylock) |
| `$mod+Ctrl+c` | reload this config |

## `$mod+$alt` — the workspaces, as the monitors stand

| chord | does |
|---|---|
| `$mod+$alt+h/l`, Left/Right | walk to the previous / next existing workspace on this monitor |
| `$mod+$alt+Shift+h/l`, Left/Right | the same walk, carrying the focused window |
| `$mod+$alt+k/j`, Up/Down | focus the monitor above / below |
| `$mod+$alt+Shift+k/j`, Up/Down | carry the focused window (or a selected column) there |

On bigfed, workspaces 1–5 live on the Samsung and 6–0 on the MSI above it.

## Key families — they override the tiers on their own key

**Escape: leaving, graded by weight**

| chord | does |
|---|---|
| `$mod+Escape` | exit sway (ends the Wayland session) — confirmation nag; pressed again, closes it. While a window holds the keyboard (a VM viewer, a remote desktop), takes the keys back instead |
| `$mod+Shift+Escape` | machine off — nag offers Poweroff and Reboot; again closes it |

**Print: capture**

| chord | does |
|---|---|
| `Print` | whole screen → file in `~/Pictures/Screenshots`, with a notification |
| `Shift+Print` | pick a region (blue outline) → clipboard (Esc cancels harmlessly) |
| `$mod+Print` | pick a region → file in `~/Pictures/Screenshots` |
| `$alt+Print` | the focused window (or a selected column or fold) → file |

**XF86: hardware — these keep working on the lock screen**

| chord | does |
|---|---|
| `XF86AudioMute`, `XF86AudioMicMute` | mute output / microphone |
| `XF86AudioLowerVolume`, `XF86AudioRaiseVolume` | volume -5% / +5%, never past 100% |
| `XF86MonBrightnessDown`, `XF86MonBrightnessUp` | brightness -5% / +5%; 0 switches the panel off, a press up brings it back |
| the power button | the Poweroff/Reboot nag (not on the lock screen) |

**Second launchers: Shift means the other one**

| chord | does |
|---|---|
| `$mod+Shift+Return` | WezTerm (`$mod+Return` is Ghostty) |
| `$mod+Shift+x` | GNOME Text Editor (`$mod+x` is adelotype) |
| `$mod+Shift+d` | wofi, the former menu (`$mod+d` is rofi); again to close it |

## Resize mode — enter with `$mod+r`

| key | does |
|---|---|
| `h`, `Left` | shrink width 10px |
| `j`, `Down` | grow height 10px |
| `k`, `Up` | shrink height 10px |
| `l`, `Right` | grow width 10px |
| `Return`, `Escape`, `$mod+r` | back to normal mode |
