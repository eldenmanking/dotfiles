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

  info "Installing xclip in '$container'..."
  run_tty distrobox enter "$container" -- sudo pacman -S --needed --noconfirm xclip

  run mkdir -pv "$LOCAL_BIN"
  info "Exporting xclip to $LOCAL_BIN..."
  run distrobox enter "$container" -- distrobox-export --bin /usr/bin/xclip --export-path "$LOCAL_BIN"
}
