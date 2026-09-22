# 90-nix.sh
# Load the Nix profile so its PATH and env exports are available everywhere.
#
# Load-bearing on bigfed, not a placeholder: nix has been installed there since
# 2025-03-05, there is no nix line in ~/.bash_profile, and this file is the only
# thing putting nix on PATH. bigfed is where Carnap is built. Sourcing it also
# sets NIX_SSL_CERT_FILE, without which nix's bundled curl cannot verify TLS
# against cache.nixos.org and substituter fetches fail.
#
# The guard makes it an inert no-op where nix is absent, so one file is correct
# on every machine: fedxps gains a working nix the moment one is installed, with
# no config change; nousowl (nix removed 2026-08-17, deliberately not a build
# box) simply skips it.
#
# Corrected 2026-08-17. This comment previously read "Nix is NOT installed on
# either machine at present", which was false the day it was written
# (2026-07-26) -- nix had been on bigfed for 17 months. It was written from
# fedxps, where nix genuinely is absent, and generalised without checking the
# other machine.
#
# NIX_PROFILES guard added 2026-09-21. Upstream's nix.sh is not idempotent: it
# ends in a bare `export PATH="$NIX_LINK/bin:$PATH"` with no check, and also
# prepends to MANPATH and appends two entries to XDG_DATA_DIRS. Re-sourcing it
# in a nested shell therefore grows all three without bound -- measured at 2, 3
# and 4 copies of the nix bin directory at nesting depths 1, 2 and 3. The
# duplicate-guard discipline in 20-path.sh cannot reach it, because the growth
# happens inside a vendor file this module only sources.
#
# NIX_PROFILES is the right sentinel because nix.sh exports it unconditionally
# alongside everything else it sets, so it is present exactly when the setup has
# already run and has been inherited. Guarding the *source* rather than
# deduplicating afterwards fixes all three variables with one check.
if [ -z "${NIX_PROFILES:-}" ] && [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi
