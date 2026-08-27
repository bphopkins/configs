# Claude Code configuration linkage — verified behaviors (2026-08)

Dated record, true as of 2026-08-20; moved verbatim from the root `CLAUDE.md`
on 2026-08-26 (context-policy Stage 2). The mechanism summary lives in
`bin/CLAUDE.md`; layout and deployment in `org/claude-config/README.md`; the
permission measurement (and the built-in read-only command list) in
`org/claude-config/permission-measurement.md`. This file records the verified
behaviors and the experiments that established them.

## It maintains itself

Two hooks in `settings.json`, both living in `org/claude-config/hooks/`:

- **`SessionEnd`** runs `claude-link --auto`. Anything the session created that the
  shared copy lacks — a memory scope for a directory used for the first time, a new
  repo's permission file — is absorbed and linked, ready for the next `gpushall`.
  `--auto` is deliberately narrow: it acts **only** where nothing could conflict,
  refuses to write into a repo that is mid-rebase, prints nothing, and logs to
  `~/.claude/claude-link-auto.log`. Anything needing a decision waits for `--adopt`.
  Measured 191 ms on bigfed, 23 ms of that the `~/Desktop` scan (849 directories).
- **`SessionStart`** reports the machine name and warns if `CLAUDE.md` or
  `settings.json` has stopped resolving into `org/claude-config`, or if memory scopes
  remain unadopted. No `python3` dependency, sets its own `PATH`, escapes its output,
  15 ms.

  **The two output channels are not interchangeable, and getting this wrong makes the
  check useless.** `additionalContext` is documented in the binary as *"Text injected
  into model context"* — the user never sees it. `systemMessage` is *"Display a message
  to the user"*. The health check emitted only `additionalContext` until 2026-08-20, so
  a broken link warned the assistant and nobody else. Warnings now go to both.

**A deleted shared file leaves a dangling link on the other machine, and the link
passes cannot see it** — they iterate `org/claude-config`, so a link whose target is
gone is never visited. It matters beyond untidiness: a dangling path still fails an
`O_NOFOLLOW` write, so it keeps blocking "don't ask again" even though the file it
pointed at was deliberately removed. `claude-link` sweeps these, but only links that
point *into* the shared config — foreign symlinks are never touched. Hit on 2026-08-20
when a curation pass deleted seven emptied permission files on one machine.

**Ephemeral scopes are excluded, and this was a real bug.** Claude creates a project
scope for whatever cwd a session runs in — including the per-session scratchpad under
`/tmp/claude-1000/…`. `--auto` harvested one into the repo on 2026-08-20, and after it
was cleaned up by hand it recurred the same day. `claude-link` now skips any scope whose
mangled name begins `-tmp-`, `-var-tmp-`, `-run-`, `-dev-shm-` or `-private-tmp-`, in
both the harvest and the link pass. Without the guard, six checks in `tests/claude`
fail.

**Conditional rules key on `paths:`, not `globs:`** — and getting it wrong fails
*silently*. `globs` is only the internal field name; a rule file that uses it loads
unconditionally with no error at all. Verified live against 2.1.238: with `paths:`, a
`.txt` read leaves a LaTeX rule out and a `.tex` read pulls it in, deterministically
across four runs. Patterns are gitignore-style, matched against the path relative to the
project root. One consequence worth designing around: a conditional rule fires on **file
access**, so a session that runs `latexmk` without first reading a `.tex` never loads it
— anything that must always bind belongs in an unconditional rule file regardless.

**Verifying the hooks actually fire is not obvious, because a healthy run is
indistinguishable from no run at all** — `SessionEnd` is silent by contract and
`SessionStart` emits nothing when everything resolves. Both were confirmed live on
2026-08-20, and these are the two checks to repeat if a Claude update ever makes them
look inert:

- **`SessionEnd`**: open a session, close it, and check that
  `~/.claude/claude-link-auto.log` gained a `--- <timestamp> <host> auto ---` entry.
  Three quick open/close cycles produced exactly three entries.
- **`SessionStart`**: break one link on purpose — `rm ~/.claude/CLAUDE.md` and put a
  plain file there — then open a session. The `systemMessage` should appear in the UI,
  not merely in the model's context. Restore with `claude-link --apply`. Do **not**
  infer this one from `SessionEnd` working: they are separate entries, and a healthy
  `SessionStart` is silent, so a malformed one fails invisibly.

A third trigger lives outside Claude entirely: **`_gsync_pull_hints` in
`50-git-sync.sh` runs `claude-link --auto` when a pull or rebase changes
`claude-config/`**, and says so on the same `[HINT]` channel as the `configs:` hints.
It fires for `gpullall`, `gpull org`, `gpushall` and `gpush org` alike, because both
per-repo helpers call it. This closes an edge case the SessionEnd hook cannot: a memory
scope pulled from the other machine had nothing linking it until some session happened
to end, so working in that scope first would create a real directory and a conflict.
The `|| true` on that call is load-bearing — `claude-link` exits 1 when it makes
changes, which under `set -e` would abort the pull.

Together these close both directions: local work is harvested up, and a scope pulled
from the other machine is linked down at the next session start. The steady state is
`gpullall` … work … `gpushall`, with no Claude-specific command at all.

## The lists are frozen once linked — measured, not inferred

A repo's `.claude/settings.local.json`, once it is a symlink into `org/claude-config`,
**can no longer be written**. Claude Code's settings writer opens with `O_NOFOLLOW`
unless `allowSymlink` is set, and that flag is set only for `~/.claude/settings.json` —
never for a repo's local file. So "Yes, and don't ask again" silently fails to persist
in any linked repo.

Verified 2026-08-20 by controlled experiment, after three earlier attempts failed on
test design rather than on the mechanism:

| repo | symlinked | same command, same prompt choice | grant persisted |
|---|---|---|---|
| `LogiKEy` | no | `curl …` → "don't ask again for: curl *" | **yes** |
| `opuscula` | yes | identical | **no** |

Both transcripts show the command running, so approval happened in both cases; only
the write differed. The control is what makes it a result — an earlier run without one
produced "no grant" for the mundane reason that the wrong prompt option had been
chosen.

Three traps that made this hard to test, each worth knowing on its own:

- **A built-in read-only command list is auto-allowed in every permission mode.** The
  list, and what it does to the coverage figures, is in
  `org/claude-config/permission-measurement.md` — kept in one place because two copies
  would drift.
- **A command with no side effect at all runs freely** regardless of mode — `uname -a`
  is not on that list and still never prompts.
- **Not every prompt yields a rule.** `touch /tmp/x` offers "grant access to /tmp",
  which is a session-scoped sandbox grant and persists nowhere. Only a command-shaped
  prompt — "Yes, and don't ask again for: `curl *`" — writes to `permissions.allow`.
  Note that Claude Code proposes the **wildcard** itself, which is how broad grants
  like `Bash(git *)` and `Bash(scp *)` accumulated.

Consequence: the seven repos whose permission file was deleted in the 2026-08-20
curation are the only ones where a grant can still land — and each stops accepting
them the moment `SessionEnd` harvests the first one and links it.

## The deny block, and what it does not reach

`settings.json` carries `permissions.deny: ["Bash(git commit:*)", "Bash(git push:*)"]`.
Only those two, deliberately: auto mode's own `Git Destructive` soft-deny already
covers force-push, branch deletion and history rewrite, and its `Git Push Destination`
**allow** rule is why an ordinary push needed denying — the classifier permits what
CLAUDE.md forbids, and an instruction is not a machine guard.

Verified live 2026-08-20: `git status --short` runs unprompted, `git commit --dry-run`
and `git push --dry-run` are both refused as *"blocked by the permission layer"*, and
the assistant declined in both cases to reshape the command to dodge the matcher —
the classifier is separately told to catch exactly that circumvention.

Two limits worth knowing. It is a **hard block, not a prompt**: asking for a commit
explicitly does not get one, and the escape hatch in `CLAUDE.md` is therefore
aspirational — undo is deleting the two lines. And matching is **prefix-based**, so
`git -C <path> commit` does not match `Bash(git commit:*)`. Denying `Bash(git -C:*)`
would fix that but would also block `git -C … status`, which is explicitly allowed, so
the gap is left open and `CLAUDE.md` remains the backstop for intent.
