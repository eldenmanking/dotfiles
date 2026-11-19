# Feature: make on SteamOS, copied out of the arch distrobox. The distrobox is kept; --distrobox --uninstall
# removes it.

# Install make to ~/.local/bin by copying it out of the arch distrobox (created if missing), since the SteamOS
# rootfs is read-only.
#
# @machine any
# @os steamos
# @gui any
# @requires distrobox
feature_steamos_make() {
  install_distrobox_binary make
}

# Remove the copied make binary. The distrobox is left to uninstall_feature_distrobox.
uninstall_feature_steamos_make() {
  uninstall_distrobox_binary make
}
