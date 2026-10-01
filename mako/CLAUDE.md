# CLAUDE.md — mako package

Charter for `mako/config`, stowed to `~/.config/mako`.

- **`default-timeout=5000` is the whole point**: mako's own default is `0` —
  notifications never expire (why the NetworkManager "Connection Established"
  popup used to sit until clicked). **`ignore-timeout=1` beside it is not
  redundant** — `default-timeout` applies only when the sender expresses no
  preference, so an application asking to persist forever
  (`expire_timeout=0`) would still win without it. The `[urgency=critical]`
  section gives persistence back where it belongs (`default-timeout=0`), with
  a `#d08770` border — one of the four coupled urgent-colour sites
  (`sway/CLAUDE.md`).
- mako is **D-Bus activated** (`fr.emersion.mako.service`) — it starts on the
  first notification. There is no `exec` line in `sway/config`; don't add
  one.
- It does **not** watch its config: apply changes with `makoctl reload`
  (exit 0 means accepted; on a parse failure mako keeps the old config and
  makoctl exits 1). ⚠ **A bad value stops mako starting** at the next login
  — a colour without its `#`, a timeout with a unit, a misspelt criteria
  header — and the only symptom is that no notification ever appears, the
  critical battery warning included. The key check cannot see that;
  `tests/desktop/run.sh` runs mako's own parser on a copy since 2026-09-30.
- `$mod+n` dismisses the newest notification (`makoctl dismiss`; 2026-09-30),
  the keyboard's way to a critical one that otherwise waits for a click.

Keys and values are validated by `tests/desktop/run.sh` (caged) — run it
after edits.
