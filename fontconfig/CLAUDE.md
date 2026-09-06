# CLAUDE.md — fontconfig package

Charter for `fontconfig/conf.d/09-texlive-fonts.conf`, stowed to
`~/.config/fontconfig`. Its one job is to make TeX Live's font tree visible to
GUI applications: 212 families before, 1,309 after.

- **Nothing is copied.** fontconfig reads the fonts where TeX Live already put
  them, under `/usr/local/texlive/2026/texmf-dist/fonts/`. There is no second
  copy on disk and no `~/.local/share/fonts` involvement.
- **The TeX Live year is pinned, and is the only line needing maintenance.**
  `bash/.bashrc.d/20-path.sh` discovers the year deliberately; fontconfig
  cannot, because its `<dir>` elements take no globs and listing several years
  at once would expose two releases' fonts simultaneously — both 2025 and 2026
  are installed on each machine, so that would mean ~2,250 duplicate families.
  `tl-newyear switch` checks this file's pinned year and prints the `sed` to
  bump it, because a missing `<dir>` is ignored silently: the failure is fonts
  quietly vanishing from menus, never an error.
- **Type1 is excluded on purpose**, unlike TeX Live's own shipped
  `texmf-var/fonts/conf/texlive-fontconfig.conf`, which includes it. Those
  7,628 `.pfb` files carry TeX's OT1/T1 encodings rather than Unicode, so a GUI
  application renders the wrong glyph for most of the keyboard.

## The two rejectfont blocks

Both are snapshots of what TeX Live 2026 ships. Staleness after an update is
benign in one direction only: new fonts appear unfiltered, nothing breaks and
nothing disappears.

- **Duplicates (22 globs)** suppress TeX Live's copies of families Fedora also
  packages — Latin Modern, Noto, DejaVu, Montserrat, JetBrains Mono, Source
  Code Pro, Cantarell, Font Awesome, STIX and others. Without them each family
  is listed twice and may resolve to the TeX Live copy, which is same-version
  or older; Fedora's DejaVu is the newer of the two. Note that `texlive-lm` and
  `mnsymbol` are *Fedora* packages installing to `/usr/share/fonts/` — the
  RPM TeX Live tree at `/usr/share/texlive/` is otherwise inert, since
  kpathsea's search path never mentions it.
- **Symbol fonts (38 globs)** suppress 246 families with no language coverage
  at all: `drm` dozenal digits, GregorioTeX chant, lilyglyphs, chess, Braille,
  icon sets, printer's flowers. Verified to drop zero language-bearing faces.
  The heuristic is imperfect in the other direction: TeX math fonts such as
  `drmmi` and `drmsy` do declare coverage and still reach the menus. Delete the
  block to get all 1,555 families back.

## Verifying

```bash
fc-list : family | tr ',' '\n' | sed 's/^ *//' | sort -u | wc -l   # 1309
fc-match -f '%{file}\n' "Latin Modern Roman"   # must be /usr/share/fonts/lm/...
for g in serif sans-serif monospace system-ui emoji cursive fantasy; do
  fc-match -f "$g -> %{family}\n" "$g"; done   # must be unchanged by this file
```

The generic aliases are the thing to watch: adding ~2,900 fonts must not move
`serif`, `sans-serif` or `monospace`. Run `fc-cache -f` after any edit.

## Not covered

Flatpak applications cannot see these fonts. The sandbox bind-mounts
`/usr/share/fonts` and `~/.local/share/fonts` but not `/usr/local`, so the
files are out of reach wherever this config sits. Of the installed Flatpaks
only OBS has `host` access; none is an application where fonts get chosen.
