# Feature: make on SteamOS, copied out of the arch distrobox. The distrobox is kept; --distrobox --uninstall
# removes it.

# Install make to ~/.local/bin by copying it out of the arch distrobox (created if missing), since the SteamOS
# rootfs is read-only.
#
# @machine any
# @os steamos
# @gui any
feature_steamos_make() {
  local name="$DISTROBOX_NAME"

  if command -v make &>/dev/null; then
    info "make already available: $(command -v make)"
    return
  fi
  if ! command -v distrobox &>/dev/null; then
    warn "distrobox command not found, skipping make setup."
    return
  fi

  copy_binary_from_distrobox make "$name" make
}

# Remove the copied make binary. The distrobox is left to uninstall_feature_distrobox.
uninstall_feature_steamos_make() {
  if [[ ! -e "$LOCAL_BIN/make" ]]; then
    info "$LOCAL_BIN/make does not exist"
    return
  fi
  info "Removing $LOCAL_BIN/make..."
  run rm -f "$LOCAL_BIN/make"
}
