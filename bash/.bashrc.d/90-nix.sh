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
[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ] && . "$HOME/.nix-profile/etc/profile.d/nix.sh"
