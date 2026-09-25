# CLAUDE.md — fontconfig package

Charter for `fontconfig/conf.d/09-texlive-fonts.conf`, stowed to
`~/.config/fontconfig`. Its one job is to make TeX Live's font tree visible to
GUI applications: 212 families before, 1,398 after, measured 2026-09-06.

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
- **No `--` inside a comment.** The file is XML, and a double hyphen in a
  comment is a parse error. fontconfig then drops the whole file with one
  line on stderr, and the TeX Live tree vanishes from every application
  started afterwards while `fc-match` keeps answering from Fedora's own
  fonts, so nothing looks wrong. Made and caught within one session,
  2026-09-23. After any edit here, `fc-match monospace` must print nothing
  on stderr, and `fc-list --format '%{file}\n' | grep -c '^/usr/local/texlive'`
  must still give the figure under Verifying.

## The three rejectfont blocks

The first two are snapshots of what TeX Live 2026 ships. Staleness after an
update is benign in one direction only: new fonts appear unfiltered, nothing
breaks and nothing disappears. The third is a guard, not a snapshot.

- **Duplicates (25 globs)** suppress TeX Live's copies of families Fedora also
  packages — Latin Modern, Noto, DejaVu, Montserrat, JetBrains Mono, Source
  Code Pro, Cantarell, Font Awesome, STIX and others. Without them each family
  is listed twice and may resolve to the TeX Live copy, which is same-version
  or older; Fedora's DejaVu is the newer of the two. The premise is that those
  Fedora packages stay installed: on fedxps `dejavu-sans-fonts` had arrived only
  as a Thunderbird dependency and left with it on 2026-09-07, leaving no DejaVu
  at all until it was reinstalled by name — a family in this list must be
  user-installed (`dnf mark user`), never a dependency. Measured 2026-09-07
  and again 2026-09-25: the premise fails for part of several directories on
  both machines — DejaVu Serif, Montserrat Alternates, Open Sans Condensed,
  STIX Math, the RIT set and Noto's weights outside Regular to Bold have no
  other source anywhere, and on fedxps neither do Latin Modern Math and
  MnSymbol. `TODO.md` item 12 has the family list and the options.
  Note that `texlive-lm` and `mnsymbol` are *Fedora* packages installing to
  `/usr/share/fonts/` — the RPM TeX Live tree at `/usr/share/texlive/` is
  otherwise inert, since kpathsea's search path never mentions it.
- **Symbol fonts (38 globs)** suppress 246 families with no language coverage
  at all: `drm` dozenal digits, GregorioTeX chant, lilyglyphs, chess, Braille,
  icon sets, printer's flowers. Verified to drop zero language-bearing faces.
  The heuristic is imperfect in the other direction: TeX math fonts such as
  `drmmi` and `drmsy` do declare coverage and still reach the menus. Delete the
  block to get all 1,555 families back.
- **Web-font wrappers (2 globs, added 2026-09-23)** reject every `.woff` and
  `.woff2` under any `<dir>`: 42 files in `gentium-sil` and `logix`, each a
  wrapper around a face the same directory ships as `.ttf` or `.otf`, so the
  menus lose nothing. The block exists because of what another program's
  scanner made of them. Chrome and Brave each carry a copy of fontconfig
  inside the browser binary, beside the system library they also link (the
  library's internal strings are in both binaries and not in Ghostty, an
  ordinary client), and Chrome's became newer than Fedora's with the update to 154 on
  2026-09-22. At its first start the next morning it rewrote every cache
  under `~/.cache/fontconfig` in its own format, version 12 with
  compatibility symlinks for versions 9 to 11, where Fedora's 2.17.0 writes
  real version-9 files, and its entries for the 42 wrappers carried no
  family. fontconfig scores a font that lacks the requested element as a
  perfect match, so every request, `sans-serif` included, resolved to
  `Gentium-Bold.woff`, and every fresh Ghostty died at surface creation with
  `FontconfigNoMatch` while the running process, which had loaded its fonts
  at 08:59, kept opening windows. The rule neutralised the bad cache in place
  before `fc-cache -f` replaced it. What Chrome's scanner does with a WOFF
  was not pursued; the record is `DECISIONS.md`, 2026-09-23.

## Verifying

```bash
# LC_ALL=C is load-bearing: under en_US collation `sort -u` merges families
# that differ only in case or accent, undercounting by ~14.
fc-list : family | tr ',' '\n' | sed 's/^ *//' | LC_ALL=C sort -u | wc -l
fc-list --format '%{file}\n' | grep -c '^/usr/local/texlive'   # 2275
for g in serif sans-serif monospace system-ui emoji cursive fantasy; do
  fc-match -f "$g -> %{family}\n" "$g"; done   # must be unchanged by this file
```

The total family count is **not** comparable between machines — it includes
system fonts, and the two differ there (fedxps has a
hand-placed Latin Modern in `~/.local/share/fonts`; bigfed has the `texlive-lm`
and `jetbrains-mono-fonts` RPMs). Compare **2,275 faces under
`/usr/local/texlive`** instead: that is what this file controls. The two
machines agree on it only once both carry the same globs — on 2026-09-06 they
read 2,351 apiece, then bigfed dropped to 2,317 when the Anonymous Pro,
Atkinson Mono and IBM Plex Mono globs were added, and fedxps followed on its
next sync; then bigfed to 2,275 with the wrapper block of 2026-09-23, fedxps
following at its next sync. A one-sided figure means the config has not
travelled yet.

The generic aliases are the thing to watch: adding ~2,900 fonts must not move
`serif`, `sans-serif` or `monospace`.

`fc-cache -f` is **not** the follow-up to an edit here, despite the reflex.
`selectfont` rules are applied when an application loads fontconfig, not baked
into the directory cache: measured 2026-09-06, adding a `rejectfont` glob took
a sandbox from 28 faces to 14 with the cache untouched, and running `fc-cache`
afterwards changed nothing. The cache is about font *files* — so it matters
when the pinned `<dir>` moves under `tl-newyear`, or when fonts are installed
or removed, and not otherwise. What a rule edit does need is the applications
restarted, since each reads fontconfig only at startup; a GUI still listing a
family twice after a pull has simply not been reopened.

The one case where `fc-cache -f` *is* the remedy is the 2026-09-23 incident
under block three: a cache rewritten by another program's fontconfig. Its
signature is `fc-match` resolving every request to one file, and
`~/.cache/fontconfig` holding `cache-12` files with `cache-9` symlinks where
Fedora's library writes real `cache-9` files. The rebuild takes five seconds
and touches nothing else.

## Not covered

Flatpak applications cannot see these fonts. The sandbox bind-mounts
`/usr/share/fonts` and `~/.local/share/fonts` but not `/usr/local`, so the
files are out of reach wherever this config sits. Of the installed Flatpaks
only OBS has `host` access; none is an application where fonts get chosen.
