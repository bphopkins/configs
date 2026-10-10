# bigfed's half of the git configuration (fedxps.inc explains how a machine
# selects its file: the link ~/.config/git/host.inc for git itself, the
# hostname for the sync commands). bigfed is the writer: it alone commits
# and pushes every repository in ~/Desktop, and it keeps git's defaults.
# None of fedxps.inc's reader settings belong here: core.checkStat=minimal
# would hide an edit arriving in the same second at the same size, and
# GIT_OPTIONAL_LOCKS=0 makes gpushall's `add -A` re-stamp pack files after a
# stat-only arrival (org/machines/transport-2026-10/design-revisions.md, C).
# Built 2026-10-10, pilot step 3a; the link on bigfed is made by hand there.

[gsync]
	role = writer

[maintenance]
	# bigfed-1 (decision 6, 2026-10-09): git's automatic maintenance stays
	# on and runs in the foreground, so a commit that triggers a repack
	# returns only when the repack is done. gpushall then never leaves a
	# detached `git maintenance` behind that a power-off could cut short,
	# and the hub receives the new pack whole.
	autoDetach = false
