# TODO(andywang): add comment

# --- Install xclip ---
feature_steamos_xclip() {
  local container="tmp-arch"

  if command -v xclip &>/dev/null; then
    info "xclip already available: $(command -v xclip)"
    return
  fi
  if ! command -v distrobox &>/dev/null; then
    warn "distrobox command not found, skipping xclip setup."
    return
  fi

  if distrobox list 2>/dev/null | grep -qw "$container"; then
    info "distrobox '$container' already exists"
  else
    info "Creating distrobox '$container'..."
    run distrobox create -Y -n "$container" -i archlinux:latest
  fi

  info "Installing xclip in '$container' and copying it to $LOCAL_BIN..."
  run_tty distrobox enter "$container" -- bash -c "
    sudo pacman -Sy --noconfirm --needed xclip &&
    mkdir -p '$LOCAL_BIN' &&
    cp /usr/bin/xclip '$LOCAL_BIN/xclip'
  "

  info "Removing distrobox '$container'..."
  run distrobox rm -f "$container"

  if ! $DRY_RUN && ldd "$LOCAL_BIN/xclip" | grep -q "not found"; then
    warn "xclip is missing shared libraries on this host (see 'ldd $LOCAL_BIN/xclip')."
  fi
}
