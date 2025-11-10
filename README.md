# Storing and Syncing Configuration Files Across Machines

Below are instructions to (1) put various dotfiles and configuration directories into a GitHub repository from a primary machine, and (2) sync those onto a secondary machine. Once set up, syncing these across machines can become a simple part of your workflow, making working with complex configurations across multiple machines no big deal. 

I include specific instructions for my personal configuration files for ease in the future. These instructions only apply to Linux distributions, and in particular only to Fedora Linux. There's no reason it couldn't work essentially the same way on other distributions, but sometimes configuration files can show up in different places. 


## (1) Pushing to GitHub from Primary Machine

### 1. Install Stow & prepare the repo

I would personally begin by creating the `configs` repo on GitHub with a readme file, and then cloning it onto my desktop. My `.bashrc` file includes defined commands to push and pull all at once, to which I refer below. 

```bash
sudo dnf install -y stow
cd ~/Desktop
git clone git@github.com:bphopkins/configs.git
mkdir -p "$HOME/Desktop/configs/{bash,nvim,sway,waybar,wezterm}"
```

---

### 2. Move the existing files into the repo (from where they are now)

Note: This temporarily removes the live files for a minute; we’ll stow them back right after. They will be stored in memory in the meantime, so there shouldn't be a problem, although, for example, WezTerm might temporarily lose its configuration. Nothing catastrophic, though.

```bash
# Bash (currently in ~)

## Single-session variables for ~/Desktop/configs and timestamp for backups
CFG="$HOME/Desktop/configs"
ts=$(date +%Y%m%d-%H%M%S)

### BASH: direct moves of the two files from ~ -> ~/Desktop/configs/bash
[ -f "$HOME/.bashrc" ]       && mv -iv -- "$HOME/.bashrc"       "$CFG/bash/.bashrc"       || echo "MISSING: ~/.bashrc"
[ -f "$HOME/.bash_profile" ] && mv -iv -- "$HOME/.bash_profile" "$CFG/bash/.bash_profile" || echo "MISSING: ~/.bash_profile"

### NVIM: move *all* files from ~/.config/nvim -> ~/Desktop/configs/nvim
if [ -d "$HOME/.config/nvim" ]; then
  rsync -a --exclude='.git' -- "$HOME/.config/nvim/" "$CFG/nvim/"
  mv "$HOME/.config/nvim" "$HOME/.config/nvim.backup.$ts"
  mkdir -p "$HOME/.config/nvim"
else
  echo "MISSING: ~/.config/nvim (nothing to import)"
fi

### SWAY: move *all* files from ~/.config/sway -> ~/Desktop/configs/sway
if [ -d "$HOME/.config/sway" ]; then
  rsync -a --exclude='.git' -- "$HOME/.config/sway/" "$CFG/sway/"
  mv "$HOME/.config/sway" "$HOME/.config/sway.backup.$ts"
  mkdir -p "$HOME/.config/sway"
else
  echo "MISSING: ~/.config/sway (nothing to import)"
fi

### WAYBAR: move *all* files from ~/.config/waybar -> ~/Desktop/configs/waybar
if [ -d "$HOME/.config/waybar" ]; then
  rsync -a --exclude='.git' -- "$HOME/.config/waybar/" "$CFG/waybar/"
  mv "$HOME/.config/waybar" "$HOME/.config/waybar.backup.$ts"
  mkdir -p "$HOME/.config/waybar"
else
  echo "MISSING: ~/.config/waybar (nothing to import)"
fi

### WEZTERM (legacy in ~): direct move of ~/.wezterm.lua -> ~/Desktop/configs/wezterm/.wezterm.lua
[ -f "$HOME/.wezterm.lua" ] && mv -iv -- "$HOME/.wezterm.lua" "$CFG/wezterm/.wezterm.lua" || echo "MISSING: ~/.wezterm.lua"

```
It may be worth it at this point to verify that, e.g., your new `nvim` directory respects the structure of the original:
```bash
# bash
diff -rq "$HOME/.config/nvim.backup.$ts" "$CFG/nvim"   # expect no differences
```


---

### 3. Commit the seed state

It's worth it at this point since the directory is set up. See my `.bashrc` file to see how the command works:

```bash
# bash
gpushall
```

---

### 4. Dry-run Stow (see exactly which symlinks will be created)

```bash
# bash (easier to run in ~/Desktop/configs)
cd ~/Desktop/configs

# Bash and WezTerm links go to $HOME
stow -nvt ~ bash
stow -nvt ~ wezterm

# Sway & Waybar link into their specific config dirs
stow -nvt ~/.config/nvim   nvim
stow -nvt ~/.config/sway   sway
stow -nvt ~/.config/waybar waybar
```

If the output shows the right link paths, proceed.

---

### 5. Create the symlinks (real run)

```bash
stow -vt ~ bash
stow -vt ~ wezterm
stow -vt ~/.config/nvim nvim
stow -vt ~/.config/sway sway
stow -vt ~/.config/waybar waybar
```

---

### 6. Verify

```bash
ls -l ~/.bashrc ~/.bash_profile
ls -l ~/.config/sway/config ~/.config/sway/config.save 2>/dev/null || true
ls -l ~/.config/waybar/config ~/.config/waybar/style.css 2>/dev/null || true
```

You should see arrows (`->`) pointing into `~/Desktop/configs/...`.

---

### 7. Reload (no reboot)

```bash
# Bash
[ -f ~/.bashrc ] && source ~/.bashrc

# Sway & Waybar
swaymsg reload
pkill -SIGUSR2 waybar 2>/dev/null || true
```

---

### 8. Notes & common tweaks

- **Per-target stowing** keeps your repo clean:
  * `bash/` is stowed to `~` → creates `~/.bashrc`, `~/.bash_profile` symlinks.
  * `sway/` is stowed to `~/.config/sway` → creates `config`, `config.save` symlinks there.
  * `waybar/` is stowed to `~/.config/waybar` → creates `config`, `style.css` symlinks there.

- **If Stow reports a conflict** (e.g., a real file already exists), either back it up and remove it, or adopt it:

  ```bash
  stow --adopt -vt ~               bash
  stow --adopt -vt ~/.config/sway  sway
  stow --adopt -vt ~/.config/waybar waybar
  git add -A && git commit -m "Adopt local files"
  ```
* **Undo** any package later:

  ```bash
  stow -Dvt ~               bash
  stow -Dvt ~/.config/sway  sway
  stow -Dvt ~/.config/waybar waybar
  ```


## (2) Syncing from Another Machine
