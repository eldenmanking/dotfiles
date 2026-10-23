# Feature: xclip on SteamOS, copied out of the arch distrobox. The distrobox is kept; --distrobox --uninstall
# removes it.

# Install xclip to ~/.local/bin by copying it out of the arch distrobox (created if missing), since the SteamOS
# rootfs is read-only.
#
# @machine any
# @os steamos
# @gui desktop
feature_steamos_xclip() {
  local name="$DISTROBOX_NAME"

  if command -v xclip &>/dev/null; then
    info "xclip already available: $(command -v xclip)"
    return
  fi
  if ! command -v distrobox &>/dev/null; then
    warn "distrobox command not found, skipping xclip setup."
    return
  fi

  if distrobox_exists "$name"; then
    info "Reusing distrobox '$name'"
  else
    info "Creating distrobox '$name' from $DISTROBOX_IMAGE..."
    run distrobox create --name "$name" --image "$DISTROBOX_IMAGE" --yes
  fi

  info "Installing xclip in '$name' and copying it to $LOCAL_BIN..."
  run_tty distrobox enter "$name" -- bash -c "
    sudo pacman -Sy --noconfirm --needed xclip &&
    mkdir -p '$LOCAL_BIN' &&
    cp /usr/bin/xclip '$LOCAL_BIN/xclip'
  "

  if ! $DRY_RUN && ldd "$LOCAL_BIN/xclip" | grep -q "not found"; then
    warn "xclip is missing shared libraries on this host (see 'ldd $LOCAL_BIN/xclip')."
  fi
}

# Remove the copied xclip binary. The distrobox is left to uninstall_feature_distrobox.
uninstall_feature_steamos_xclip() {
  if [[ ! -e "$LOCAL_BIN/xclip" ]]; then
    info "$LOCAL_BIN/xclip does not exist"
    return
  fi
  info "Removing $LOCAL_BIN/xclip..."
  run rm -f "$LOCAL_BIN/xclip"
}
