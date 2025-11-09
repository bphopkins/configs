
## 1) Install Stow & prepare the repo

```bash
sudo dnf install -y stow
mkdir -p ~/Desktop/configs/{bash,sway,waybar}
cd ~/Desktop/configs
git init
```

---

## 2) Move the existing files into the repo (from where they are now)

> This temporarily removes the live files for a minute; we’ll stow them back right after.

```bash
# Bash (currently in ~)
[ -f ~/.bashrc ]        && mv ~/.bashrc        ~/Desktop/configs/bash/.bashrc
[ -f ~/.bash_profile ]  && mv ~/.bash_profile  ~/Desktop/configs/bash/.bash_profile

# Sway (currently in ~/.config/sway)
mkdir -p ~/.config/sway
[ -f ~/.config/sway/config ]       && mv ~/.config/sway/config       ~/Desktop/configs/sway/config
[ -f ~/.config/sway/config.save ]  && mv ~/.config/sway/config.save  ~/Desktop/configs/sway/config.save

# Waybar (currently in ~/.config/waybar)
mkdir -p ~/.config/waybar
[ -f ~/.config/waybar/config ]     && mv ~/.config/waybar/config     ~/Desktop/configs/waybar/config
[ -f ~/.config/waybar/style.css ]  && mv ~/.config/waybar/style.css  ~/Desktop/configs/waybar/style.css
```

---

## 3) Commit the seed state

```bash
cd ~/Desktop/configs
git add -A
git commit -m "Seed configs: bash (.bashrc, .bash_profile); sway (config, config.save); waybar (config, style.css)"
```

---

## 4) Dry-run Stow (see exactly which symlinks will be created)

```bash
cd ~/Desktop/configs

# Bash links go to $HOME
stow -nvt ~ bash

# Sway & Waybar link into their specific config dirs
stow -nvt ~/.config/sway   sway
stow -nvt ~/.config/waybar waybar
```

If the output shows the right link paths, proceed.

---

## 5) Create the symlinks (real run)

```bash
stow -vt ~               bash
stow -vt ~/.config/sway  sway
stow -vt ~/.config/waybar waybar
```

---

## 6) Verify

```bash
ls -l ~/.bashrc ~/.bash_profile
ls -l ~/.config/sway/config ~/.config/sway/config.save 2>/dev/null || true
ls -l ~/.config/waybar/config ~/.config/waybar/style.css 2>/dev/null || true
```

You should see arrows (`->`) pointing into `~/Desktop/configs/...`.

---

## 7) Reload (no reboot)

```bash
# Bash
[ -f ~/.bashrc ] && source ~/.bashrc

# Sway & Waybar
swaymsg reload
pkill -SIGUSR2 waybar 2>/dev/null || true
```

---

## 8) Notes & common tweaks

* **Per-target stowing** keeps your repo clean:

  * `bash/` is stowed to `~` → creates `~/.bashrc`, `~/.bash_profile` symlinks.
  * `sway/` is stowed to `~/.config/sway` → creates `config`, `config.save` symlinks there.
  * `waybar/` is stowed to `~/.config/waybar` → creates `config`, `style.css` symlinks there.
* **If Stow reports a conflict** (e.g., a real file already exists), either back it up and remove it, or adopt it:

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

That’s it. You now have exactly the structure you asked for, with clean symlinks back into the right places.
