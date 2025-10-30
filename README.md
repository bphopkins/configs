# configs

Personal, cross‑machine configuration notes and quick references. This single **README** collects concise cheat‑sheets for each config I keep in this repo.

- [Conventions & Notation](#conventions--notation)
- [Emacs Config — Quick Reference](#emacs-config--quick-reference)
- [Hyprland Config — Quick Reference](#hyprland-config--quick-reference)
- [Tips](#tips)

---

## Conventions & Notation

- `C-` = **Ctrl**, `M-` = **Alt/Meta**, `RET` = **Enter/Return**, `SPC` = **Spacebar**
- In the tables below, *custom* means bound in my config (not an Emacs default).

---

## Emacs Config — Quick Reference

> A compact, skimmable index of the keybinds I actually use day‑to‑day. Many have alternatives; when in doubt, hit `C-g` to cancel and `M-x` to run a command by name.

### Files & Buffers

| Keys        | Action                                 |
|-------------|----------------------------------------|
| `C-x C-f`   | Open / find file                       |
| `C-x C-s`   | Save current buffer                    |
| `C-x C-c`   | Quit Emacs                             |
| `C-x b`     | Switch buffer by name                  |
| `C-x h`     | Select whole buffer                    |

### Window Management

| Keys        | Action                                              |
|-------------|-----------------------------------------------------|
| `C-x 2`     | Split window **horizontally** (top/bottom)          |
| `C-x 3`     | Split window **vertically** (left/right)            |
| `C-x o`     | Other window                                        |
| `C-x 1`     | Delete **other** windows                            |
| `C-x 0`     | Delete **this** window                              |

### Editing & Text

| Keys        | Action                                  |
|-------------|-----------------------------------------|
| `C-y`       | Yank (paste)                            |
| `M-w`       | Copy (save to kill ring)                |
| `C-w`       | Cut (kill region)                       |
| `C-SPC`     | Set mark / start selection              |
| `C-g`       | Cancel / abort                          |
| `C-M-\`    | Indent region                           |
| `RET`       | Newline                                 |

### Help & Introspection

| Keys / M-x                 | Action                                |
|---------------------------|----------------------------------------|
| `C-h e`                   | Messages buffer                        |
| `C-h k`                   | Describe key                           |
| `M-x describe-variable`   | Show variable documentation/value      |
| `M-x describe-font`       | List available fonts                   |
| `M-x emacs-version`       | Show Emacs version                     |

### LaTeX / AUCTeX (Compilation & View)

| Keys       | Action                                               |
|------------|------------------------------------------------------|
| `F5`       | Compile (TeX-command-run-all)                        |
| `C-RET`    | Compile (alternate binding)                          |
| `F6`       | View/sync PDF in Okular                              |
| `C-c C-e`  | Insert LaTeX environment                             |

### LaTeX Preview (preview-latex)

| Keys                 | Action                         |
|----------------------|--------------------------------|
| `C-c C-p C-d`        | Preview **entire document**    |
| `C-c C-p C-c C-d`    | **Clear** all previews         |
| `C-c C-p C-p`        | Toggle preview at point        |
| `C-c C-p C-r`        | Preview region                 |
| `C-c C-p C-s`        | Preview section                |
| `C-c C-p C-e`        | Preview environment            |
| `C-c C-p C-c C-b`    | **Clear** previews in buffer   |

### Completion

| Keys         | Action                       |
|--------------|------------------------------|
| `M-TAB`      | Complete at point            |
| `C-M-i`      | Complete at point (alt)      |
| `ESC TAB`    | Complete at point (alt)      |
| `TAB`        | Expand snippet (YASnippet)   |

### Projects (`project.el`)

| Keys        | Action                                   |
|-------------|------------------------------------------|
| `C-x p p`   | Switch project                            |
| `C-x p f`   | Find file in project                      |
| `C-x p d`   | Dired at project root                     |
| `C-x p b`   | Switch buffer in project                  |
| `C-x p s`   | Search across project files               |
| `C-x p r`   | Query‑replace across project files        |

### Git / Magit

| Keys / In-Buffer Context | Action                                        |
|--------------------------|-----------------------------------------------|
| `M-x magit-status`       | Open Magit status                             |
| **In Status**            |                                               |
| `S`                      | Stage **all** changes                         |
| `s`                      | Stage file at point                           |
| `u`                      | Unstage file at point                         |
| `c c`                    | Commit (press `c` twice)                      |
| `P p`                    | Push                                          |
| `g`                      | Refresh                                       |
| `q`                      | Quit status buffer                            |
| **In Commit Msg**        |                                               |
| `C-c C-c`                | Finalize commit                               |
| **Custom shortcuts**     |                                               |
| `C-c g s`                | Sync repo (stage, commit, push) *(custom)*    |
| `C-c g p`                | Pull *(custom)*                               |
| `C-c g S`                | Sync **all** repos in `~/Desktop/` *(custom)* |
| `C-c g g`                | `magit-status` *(custom)*                     |

### Display & Appearance

| Keys         | Action                                  |
|--------------|-----------------------------------------|
| `F8`         | Toggle line numbers *(custom)*          |
| `C-c n`      | Toggle line numbers *(custom)*          |
| `C-x C-+`    | Increase text size                      |
| `C-x C--`    | Decrease text size                      |
| `C-x C-0`    | Reset text size                         |
| `M-x load-theme` | Choose color theme                  |

### Config & Evaluation

| Keys / M-x      | Action                    |
|-----------------|---------------------------|
| `M-x eval-buffer` | Reload entire `init.el` |
| `M-x eval-region` | Eval selected Elisp     |

### Shells inside Emacs

| M-x command  | Action                 |
|--------------|------------------------|
| `shell`      | Basic shell            |
| `eshell`     | Emacs-native shell     |
| `term`       | Terminal emulator      |
| `ansi-term`  | ANSI terminal emulator |

### Escape / Cancel & Running Commands

| Keys         | Action                                        |
|--------------|-----------------------------------------------|
| `C-g`        | Cancel / keyboard-quit                        |
| `F9`         | Keyboard escape quit *(custom panic button)*  |
| `ESC ESC ESC`| Alternative escape (press ESC three times)    |
| `M-x`        | Execute command by name                       |

### Common Gotcha

- `C-\` toggles **input method** (it is *not* `indent-region`). Use **`C-M-\`** for `indent-region`.

### System Clipboard Pasting

| Gesture            | Action                           |
|--------------------|----------------------------------|
| `Shift-Insert`     | Paste from system clipboard      |
| `Ctrl-Shift-V`     | Paste from system clipboard      |
| Middle‑click       | Paste at mouse position (X11)    |

---

## Hyprland Config — Quick Reference

> Placeholder scaffold. Add the binds you actually use from `~/.config/hypr/hyprland.conf` so this section mirrors the Emacs one. Suggested groupings:

### Window & Focus
- _Fill in_: e.g., `SUPER + Q` — close window; `SUPER + O` — focus other, etc.

### Workspaces
- _Fill in_: e.g., `SUPER + 1..0` — switch; `SUPER + SHIFT + 1..0` — move to ws.

### Launchers
- _Fill in_: e.g., `SUPER + SPACE` — wofi/rofi; `SUPER + ENTER` — terminal.

### Screenshots & Media
- _Fill in_: e.g., `Print` — screenshot; `SUPER + P` — output profile.

> Tip: You can auto‑generate this section by grepping binds:
>
> ```bash
> grep -E '^bind\s*=' ~/.config/hypr/hyprland.conf | sed 's/^bind *= *//'
> ```

---

## Tips

- **Forget a chord?** `C-g` to bail out, then `M-x` the command by name.
- Prefer **project.el** for cross‑project ops (`C-x p ...`).
- Keep this README short and skimmable; link out to full docs when needed.
