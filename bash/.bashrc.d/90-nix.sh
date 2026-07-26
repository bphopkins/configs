# 90-nix.sh
# Load the Nix profile so its PATH and env exports are available everywhere.
#
# Nix is NOT installed on either machine at present. This is kept deliberately,
# ready for Carnap development: Carnap builds via nix, and having the loader
# already in place means installing nix is the only step. The guard makes it a
# no-op until then, so there is nothing to clean up either way.
[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ] && . "$HOME/.nix-profile/etc/profile.d/nix.sh"
