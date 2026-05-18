# ClamAV scanning helpers.
#
# Subcommands:
#   clam update    sudo freshclam — refresh virus signatures.
#   clam home      Scan ~/ as the user; log to ~/clam-scan-home-<ts>.log.
#   clam full      Sudo system scan from /; log to ~/clam-scan-full-<ts>.log.
#                  Excludes /sys, /proc, /dev, /run, /var/lib/clamav. Hours-long.
#
# Setup (one-time): sudo dnf install -y clamav clamav-update

clam() {
  local cmd="$1"
  local ts
  ts="$(date +%Y%m%d-%H%M)"

  case "$cmd" in
    update)
      sudo freshclam
      ;;
    home)
      clamscan -ri --detect-pua=yes "$HOME" 2>&1 \
        | tee "$HOME/clam-scan-home-$ts.log"
      ;;
    full)
      sudo clamscan -ri --detect-pua=yes \
        --exclude-dir='^/sys' \
        --exclude-dir='^/proc' \
        --exclude-dir='^/dev' \
        --exclude-dir='^/run' \
        --exclude-dir='^/var/lib/clamav' \
        / 2>&1 \
        | tee "$HOME/clam-scan-full-$ts.log"
      ;;
    ""|help|-h|--help)
      cat <<'EOF'
ClamAV scanning helpers.

Usage:
  clam update    Refresh virus signatures (sudo freshclam).
  clam home      Scan ~/ as your user. Log: ~/clam-scan-home-<ts>.log.
  clam full      Comprehensive sudo scan from /. Log: ~/clam-scan-full-<ts>.log.
                 Excludes virtual filesystems and the signature DB itself.
                 Expect 1-3 hours.

Setup once: sudo dnf install -y clamav clamav-update
Run `clam update` before scanning if signatures may be stale.
EOF
      ;;
    *)
      echo "clam: unknown subcommand '$cmd' (try 'clam help')" >&2
      return 1
      ;;
  esac
}
