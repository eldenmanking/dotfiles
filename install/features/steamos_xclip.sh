# Feature: xclip on SteamOS, copied out of the arch distrobox. The distrobox is kept; --distrobox --uninstall
# removes it.

# Install xclip to ~/.local/bin by copying it out of the arch distrobox (created if missing), since the SteamOS
# rootfs is read-only.
#
# @machine any
# @os steamos
# @gui desktop
feature_steamos_xclip() {
  install_distrobox_binary xclip
}

# Remove the copied xclip binary. The distrobox is left to uninstall_feature_distrobox.
uninstall_feature_steamos_xclip() {
  uninstall_distrobox_binary xclip
}
