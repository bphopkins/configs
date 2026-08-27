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
  (exit 0 means accepted).

Keys are validated against the installed man page by `tests/desktop/run.sh` —
run it after edits.
