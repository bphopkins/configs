# Storing and Syncing Configuration Files Across Machines

Below are instructions to (1) put various dotfiles and configuration directories into a GitHub repository from a primary machine, and (2) sync those onto a secondary machine. Once set up, syncing these across machines can become a simple part of your workflow, making working with complex configurations across multiple machines no big deal. 

I include specific instructions for my personal configuration files for ease in the future. These instructions only apply to Linux distributions, and in particular only to Fedora Linux. There's no reason it couldn't work essentially the same way on other distributions, but sometimes configuration files can show up in different places on different distributions. 


## (0) My Current Syncing Workflow

As soon as I boot my computer -- whichever I'm on -- I run the following custom `bash` commands in order:
```bash
gpullall           # Pulls from all my everyday repositories  
source .bashrc     # Only if necessary, but it's mostly harmless
stow-all           # Only if files were added or deleted, but it's harmless
```
And when I finish for the day I run:
```bash
gpushall
```
I might as well have renamed my pull command `gmorning` and my push command `gnight`, but I don't only ever run them in the morning and night. The idea is just that, whenever I am done working on one machine, I give myself the option to start working on any other machine whenever I want to do more work.


## (1) From Your Primary Machine

Note: These instructions do not completely cover all the directories and files in the repository. They were written at a certain stage in this process and I don't care to fill in all the blanks.

### 1. Install Stow & prepare the repo

I would personally begin by creating the `configs` repo on GitHub with a readme file, and then cloning it onto my desktop. My `.bashrc` file includes defined commands to push and pull all at once, to which I refer below. Different workflows might suggest initializing the repo at this step, as well as doing other Git things at other steps.

```bash
sudo dnf install -y stow
cd ~/Desktop
git clone git@github.com:bphopkins/configs.git
mkdir -p "$HOME/Desktop/configs/{alacritty,bash,nvim,sway,waybar,wezterm}"
```



### 2. Move the existing files into the repo (from where they are now)

Note: This temporarily removes the live files from their source locations for a minute; we’ll stow them back right after. They will be stored in memory in the meantime, so there shouldn't be a problem, although, for example, WezTerm might prompt you or temporarily lose its configuration. Nothing catastrophic.

```bash
# Good to move into Home directory
cd ~

## Single-session variables for ~/Desktop/configs and timestamp for backups
CFG="$HOME/Desktop/configs"
ts=$(date +%Y%m%d-%H%M%S)

# Alacritty: move *all* files from ~/.config/alacritty to ~/Desktop/configs/alacritty
if [ -d "$HOME/.config/alacritty" ]; then
  rsync -a --exclude='.git' -- "$HOME/.config/alacritty/" "$CFG/alacritty/"
  mv "$HOME/.config/alacritty" "$HOME/.config/alacritty.backup.$ts"
  mkdir -p "$HOME/.config/alacritty"
else
  echo "MISSING: ~/.config/alacritty (nothing to import)"
fi

# BASH: direct moves of the two files from ~ to ~/Desktop/configs/bash
[ -f "$HOME/.bashrc" ]       && mv -iv -- "$HOME/.bashrc"       "$CFG/bash/.bashrc"       || echo "MISSING: ~/.bashrc"
[ -f "$HOME/.bash_profile" ] && mv -iv -- "$HOME/.bash_profile" "$CFG/bash/.bash_profile" || echo "MISSING: ~/.bash_profile"

# NVIM: move *all* files from ~/.config/nvim to ~/Desktop/configs/nvim
if [ -d "$HOME/.config/nvim" ]; then
  rsync -a --exclude='.git' -- "$HOME/.config/nvim/" "$CFG/nvim/"
  mv "$HOME/.config/nvim" "$HOME/.config/nvim.backup.$ts"
  mkdir -p "$HOME/.config/nvim"
else
  echo "MISSING: ~/.config/nvim (nothing to import)"
fi

# SWAY: move *all* files from ~/.config/sway to ~/Desktop/configs/sway
if [ -d "$HOME/.config/sway" ]; then
  rsync -a --exclude='.git' -- "$HOME/.config/sway/" "$CFG/sway/"
  mv "$HOME/.config/sway" "$HOME/.config/sway.backup.$ts"
  mkdir -p "$HOME/.config/sway"
else
  echo "MISSING: ~/.config/sway (nothing to import)"
fi

# WAYBAR: move *all* files from ~/.config/waybar to ~/Desktop/configs/waybar
if [ -d "$HOME/.config/waybar" ]; then
  rsync -a --exclude='.git' -- "$HOME/.config/waybar/" "$CFG/waybar/"
  mv "$HOME/.config/waybar" "$HOME/.config/waybar.backup.$ts"
  mkdir -p "$HOME/.config/waybar"
else
  echo "MISSING: ~/.config/waybar (nothing to import)"
fi

# WEZTERM (legacy in ~): direct move of ~/.wezterm.lua to ~/Desktop/configs/wezterm/.wezterm.lua
[ -f "$HOME/.wezterm.lua" ] && mv -iv -- "$HOME/.wezterm.lua" "$CFG/wezterm/.wezterm.lua" || echo "MISSING: ~/.wezterm.lua"

```
It may be worth it at this point to verify that, e.g., your new `nvim` directory respects the structure of the original:
```bash
diff -rq "$HOME/.config/nvim.backup.$ts" "$CFG/nvim"   # expect no differences
```
If that one looks good, then the others probably do too, but you can do the same for each.



### 3. Commit the seed state

It's worth syncing to remote at this point since the directory is set up. Your workflow might involve `git add` and `git commit`, but I use a custom `bash` command. See my `.bashrc` file to see how the command works:

```bash
gpushall     # automatically stage, commit, and push all to origin
```



### 4. Dry-run Stow 

This simulates the action, reporting back if `stow` sees anything funny about creating the symlinks, and telling us exactly which symlinks will be created.

```bash
# Easier to run in ~/Desktop/configs
cd ~/Desktop/configs

# Bash and WezTerm links go to $HOME
stow -nvt ~ bash
stow -nvt ~ wezterm

# Sway & Waybar link into their specific config dirs
stow -nvt ~/.config/alacritty alacritty
stow -nvt ~/.config/nvim nvim
stow -nvt ~/.config/sway sway
stow -nvt ~/.config/waybar waybar
```

If the output shows the right link paths, proceed. 



### 5. Create the symlinks (real run)

Still in `~/Desktop/configs`
```bash
stow -vt ~/.config/alacritty alacritty
stow -vt ~ bash
stow -vt ~ wezterm
stow -vt ~/.config/nvim nvim
stow -vt ~/.config/sway sway
stow -vt ~/.config/waybar waybar
```



### 6. Verify

I provide only a few examples of how to verify:

```bash
ls -l ~/.bashrc ~/.bash_profile
ls -l ~/.config/sway/config ~/.config/sway/config.save 2>/dev/null || true
ls -l ~/.config/waybar/config ~/.config/waybar/style.css 2>/dev/null || true
```

You should see arrows (`->`) pointing into `~/Desktop/configs/...`.



### 7. Reload (no reboot)

```bash
# Bash
[ -f ~/.bashrc ] && source ~/.bashrc

# Sway & Waybar
swaymsg reload
pkill -SIGUSR2 waybar 2>/dev/null || true
```

But honestly, why not just reboot?


### 8. Notes & common tweaks

- **Updating:**
  - Edits to files already linked need **no** action, but **new files/paths** do. Just restow the package to create the new symlinks, e.g.:
  ```bash
  cd ~/Desktop/configs
  stow -nRv -t ~ bash
  stow -Rv  -t ~ bash
  ```

- **If Stow reports a conflict** (e.g., a real file already exists), either back it up and remove it, or adopt it:
  ```bash
  cd ~/Desktop/configs
  stow --adopt -vt ~ bash
  stow --adopt -vt ~/.config/sway sway
  stow --adopt -vt ~/.config/waybar waybar
  git add -A && git commit -m "Adopt local files"  
  ```

- **Undo** any package later:
  ```bash
  cd ~/Desktop/configs
  stow -Dvt ~ bash
  stow -Dvt ~/.config/sway sway
  stow -Dvt ~/.config/waybar waybar
  ```


## (2) Syncing from Another Machine

It's really as simple as cloning the repo on your Desktop, clearing your dotfiles and emptying your configuration directories in `~/.config`, creating empty directories for your configurations to `stow` to, and creating the symlinks.

It's also worth noting, that every time you update `.bashrc` or `.bash_profile`, you should run:
```bash
source ~/.bashrc
```
I have made the mistake before of messing up `.bashrc`, and it's not worth it.

It's also worth noting that usually when you update your terminal's configuration, you need to reload it with something like `Ctrl+Shift+R`.
