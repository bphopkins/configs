# CLAUDE.md — okular package

Charter for `okular/`: a single stowed file, `okularpartrc`, targeted at
`~/.config` itself — the package ships one file that lives directly there,
which does not put `~/.config` under stow's control generally.

**What is stowed and why:** `okularpartrc` carries durable preference only —
the `ExternalEditorCommand` inverse-search wiring (coupled to
`bin/okular-inverse`; see `bin/CLAUDE.md`), the hand-built
`QuickAnnotationTools` toolbar (highlighters 1/2/3, underline 4, insert-text
5, notes 6/7), and `ShellOpenFileInTabs=true`. No paths, no window geometry,
no resolution-keyed values.

**It is the only stowed file the application itself rewrites — and it
survives.** KConfig saves by replace-and-rename but resolves the symlink
first, so the rewrite lands on the repo file and the live link stays intact
(tested over two write cycles, 2026-07-26; mechanism and test detail in
`docs/okular-multidoc-2026-07.md`). Consequences: a preference change dirties
the repo and `gpushall` commits it — expected, it only happens on deliberate
change; `git` reports a whole-file change — normal for replace-and-rename;
and don't expect a process holding an open fd on the repo copy to see
updates. If Okular settings ever stop syncing after a KDE upgrade, check
first whether the live path is still a symlink:

```bash
[ "$(stat -Lc%i ~/.config/okularpartrc)" = "$(stat -c%i ~/Desktop/configs/okular/okularpartrc)" ]
```

If it has become a real file, move it back into `okular/` and restow.

**Change preferences through the GUI, never by hand-editing the live file** —
Okular rewrites `okularpartrc` on exit and would clobber a hand edit. (Note
this is the *opposite* of the repo-wide `sed -i` pitfall: most tools break
the symlink; KConfig is the exception that follows it.) Pulling a changed
`okularpartrc` under a running Okular is safe — KConfig merges per-key — but
the running process keeps its in-memory values until restarted.

**Deliberately excluded, guarded by `.gitignore` (don't adopt either):**
`okularrc` — window/session state plus a `[Recent Files]` list rewritten
every session, which would churn a commit a day, collide on every rebase,
and publish refereeing and teaching PDF names to a public remote — and
`~/.local/share/okular/docdata/` — ~13MB of per-document state keyed to the
unsynced `readings/` library.
