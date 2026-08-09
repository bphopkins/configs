#!/usr/bin/env bash
# Live fire drill for the disk maintenance pair (bash/.bashrc.d/85-disk.sh):
# an end-to-end run of the REAL disk-check and disk-fix -- real btrfs, real
# balance, real scrub -- against a throwaway filesystem, with a checksum
# manifest proving no byte of data changed. This is the test the hermetic
# suite (run.sh) cannot perform, because mounting needs root.
#
# What it does, in order:
#   1. creates a 4G image under ~/.cache (disk-backed on purpose -- /tmp is
#      tmpfs), mkfs.btrfs, loop-mounts it (sudo)
#   2. writes ~2.4G of random data, deletes two files in three -- leaving
#      data chunks ~1/3 full, exactly the slack a -dusage=50 balance exists
#      to reclaim -- and records an md5 manifest of the survivors
#   3. shields the machine's real filesystems: their scrubs are pre-recorded
#      as fresh in a temporary DISK_STATE_DIR, and their headroom is real
#      (nothing due), so disk-fix has no reason to touch them -- asserted,
#      not assumed, in step 5
#   4. runs the real disk-check: a 4G filesystem can never reach 16G
#      unallocated, so the drill fs trips the crit verdict by construction
#   5. runs the real disk-fix: expects the announced plan to name ONLY the
#      drill mount, a real balance (verified by watching the drill fs's
#      data chunk allocation shrink in sysfs), the module's honest
#      "genuinely filling" FAIL (correct on a tiny fs -- and proof disk-fix
#      does not escalate when the filter can't win), and a clean recorded
#      scrub
#   6. verifies every checksum, unmounts, deletes everything it made
#
# Costs ~3.5G of writes to the underlying drive (the data + the balance) and
# a couple of minutes. Run it in an interactive terminal (sudo will prompt):
#   bash ~/Desktop/configs/tests/disk/live-drill.sh
# Last line follows the tests convention: "passed: N  failed: M".
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODULE="$CFG_ROOT/bash/.bashrc.d/85-disk.sh"

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }
silently() { "$@" >/dev/null 2>&1; }

WORK="$(mktemp -d "$HOME/.cache/disk-drill.XXXXXX")"
IMG="$WORK/fs.img"
MNT="$WORK/mnt"
STATE="$WORK/state"
mkdir -p "$MNT" "$STATE"

cleanup() {
  sudo umount "$MNT" 2>/dev/null || :
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "== drill filesystem: 4G loop-mounted btrfs under $WORK"
truncate -s 4G "$IMG"
mkfs.btrfs -q "$IMG" || { echo "mkfs.btrfs failed"; exit 1; }
sudo mount -o loop "$IMG" "$MNT" || { echo "mount failed (sudo?)"; exit 1; }
sudo chown "$USER" "$MNT"

echo "== writing ~2.4G of random data, deleting 2 in 3 to create chunk slack"
for i in $(seq 1 24); do
  dd if=/dev/urandom of="$MNT/f$i" bs=1M count=100 status=none
done
sync
for i in $(seq 1 24); do
  (( i % 3 == 0 )) || rm "$MNT/f$i"
done
sync
(cd "$MNT" && md5sum f*) > "$WORK/manifest"
check "drill data in place, manifest recorded" [ -s "$WORK/manifest" ]

export DISK_STATE_DIR="$STATE"
# shellcheck source=/dev/null
source "$MODULE"

DRILL_UUID="$(findmnt -no UUID "$MNT")"
check "drill fs has a uuid" [ -n "$DRILL_UUID" ]

# Shield the real filesystems: fresh scrub records for every mounted btrfs
# except the drill fs. Their chunk headroom is real and (presumably) fine;
# step 5 asserts disk-fix names nothing but the drill mount either way.
while IFS=$'\t' read -r uuid _; do
  [[ "$uuid" == "$DRILL_UUID" ]] && continue
  date -Iseconds > "$STATE/scrub-$uuid"
done < <(_disk_btrfs_list)

echo "== real disk-check (expect crit verdicts for $MNT)"
rc=0; out="$(disk-check)" || rc=$?
printf '%s\n' "$out"
check "check: drill fs trips the crit verdict"  contains "$out" "btrfs $MNT: unallocated down to"
check "check: exit 1 (attention)"               [ "$rc" = 1 ]

data_total_before="$(cat "/sys/fs/btrfs/$DRILL_UUID/allocation/data/disk_total")"

echo "== real disk-fix (expect: balance + scrub on the drill fs ONLY)"
rc=0; out="$(disk-fix)" || rc=$?
printf '%s\n' "$out"
check "fix: plan names the drill mount"         contains "$out" "due: filtered data balance on $MNT"
check "fix: exactly two due lines (drill only)" [ "$(grep -c '^due:' <<<"$out")" = 2 ]
check "fix: no plan line names a real fs"       lacks "$out" "on / ("
check "fix: no balance touched /"               lacks "$out" "balancing / ("
check "fix: no scrub touched /"                 lacks "$out" "scrubbing / ("
check "fix: honest FAIL on a fs balance cannot fix" contains "$out" "genuinely filling"
check "fix: exit 1 (the honest FAIL, not an error)" [ "$rc" = 1 ]
check "fix: scrub ran clean and was recorded"   contains "$out" "btrfs $MNT: scrub clean -- recorded"
check "fix: scrub date parseable"               silently date -d "$(cat "$STATE/scrub-$DRILL_UUID")" +%s
data_total_after="$(cat "/sys/fs/btrfs/$DRILL_UUID/allocation/data/disk_total")"
echo "   data chunks: $((data_total_before / 1048576))M -> $((data_total_after / 1048576))M"
check "fix: the balance really reclaimed chunks" [ "$data_total_after" -lt "$((data_total_before - 1073741824))" ]

echo "== data integrity after balance + scrub"
if (cd "$MNT" && md5sum -c "$WORK/manifest" >/dev/null 2>&1); then
  check "every checksum identical" true
else
  check "every checksum identical" false
fi

echo "passed: $pass  failed: $fail"
(( fail == 0 ))
