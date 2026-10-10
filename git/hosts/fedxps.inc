# fedxps's half of the git configuration: what differs between the two
# machines (org/machines/transport-2026-10: rules.md fedxps-1 and fedxps-2;
# built 2026-10-10, pilot step 3a). Its twin is bigfed.inc; both are tracked.
# Which file a machine reads is decided by the machine itself, two ways:
#
#   - every git process reads this file through the [include] at the end of
#     ../config, which names the machine-local link ~/.config/git/host.inc,
#     made by hand at bootstrap (README section 5):
#         ln -s ../../Desktop/configs/git/hosts/fedxps.inc ~/.config/git/host.inc
#     Git ignores a missing include silently, so without the link fedxps
#     runs unguarded, and `git config --show-origin core.checkStat` is the
#     check: it names host.inc here and nothing on bigfed;
#   - 50-git-sync.sh and 10-env.sh read hosts/$(uname -n).inc by hostname,
#     independent of the link, so a rebuilt fedxps refuses to pull or push
#     before its link exists, and a machine with no host file here is a
#     writer -- what anyone else using this repo gets.
#
# fedxps is the reader: Syncthing carries each repository, .git included,
# between the machines, and bigfed alone commits and pushes. Everything below
# keeps fedxps's own git from writing .git on a copy Syncthing delivered. The
# battery of 2026-10-09 measured it on a 46-operation matrix and on a real
# Claude session; its reports are under org/machines/transport-2026-10/.

[gsync]
	# The role the sync commands read. Absent, this machine is a writer; any
	# value but `writer` makes it a reader, so a typo fails on the safe side.
	# A reader's gpull, gpush, gpullall and gpushall refuse before any git
	# command runs in a repository, and gstatall -f fetches nothing.
	#
	# The pilot first (pilot.md): nousowl becomes a Syncthing folder of its
	# own at the seeding, 3c. Its step 1 converges nousowl by git one last
	# time and THEN arms the key below, so it stays a comment until that
	# chat uncomments it, then logs out and in on fedxps: the sync commands
	# read this file at every run, but 10-env.sh's export reaches only the
	# shells and sessions started after it. From then on fedxps's sync
	# commands leave nousowl alone and still carry the other twelve by git.
	# readerRepo repeats for more than one repository; its value is a name
	# under ~/Desktop, and a value that names no directory is warned about
	# and refuses nothing.
	#readerRepo = nousowl
	# At the cutover (5a) readerRepo leaves and fedxps reads every repository:
	#role = reader

# The incidental-write guard (fedxps-1). Plain `git status` and `git diff`
# rewrite .git/index on a copy whose files carry new inodes, as Syncthing's
# do, and that write races bigfed's own index through the hub.
[core]
	# Compare an entry's size and whole-second mtime only, never the inode,
	# uid, gid, sub-second times or ctime: Syncthing's copy keeps contents
	# and mtimes and gives every file a new inode. This is also what keeps
	# reads fast here (status 0.01 s against 0.16 s without it, on 4,766
	# entries). On bigfed it would hide a same-second, same-size edit, so it
	# stays off there.
	checkStat = minimal
	# Inert in git 2.56, whose `minimal` already ignores ctime; kept so the
	# guard stays whole if git's code comes to match its manual.
	trustctime = false
[diff]
	# Every `git diff` form refreshes the index after a stat-only change
	# (a touch, an unchanged save) unless this is off. GIT_OPTIONAL_LOCKS=0,
	# exported by bash/.bashrc.d/10-env.sh on a reader, does the same for
	# `git status`; it has no config form.
	autoRefreshIndex = false
# No automatic maintenance on the reader: a gc here would be a second writer
# of .git, racing bigfed's packs. bigfed runs it, in the foreground.
[gc]
	auto = 0
[maintenance]
	auto = false
