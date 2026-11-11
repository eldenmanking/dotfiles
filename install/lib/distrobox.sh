# Distrobox helpers shared by the distrobox, steamos_xclip and steamos_make features.

DISTROBOX_NAME="arch"
DISTROBOX_IMAGE="archlinux:latest"

# Return 0 if a distrobox named $1 exists. Matches the NAME column exactly, so
# 'arch' doesn't match e.g. 'tmp-arch'.
distrobox_exists() {
  distrobox list --no-color 2>/dev/null \
    | awk -F'|' -v name="$1" 'NR > 1 { gsub(/^ +| +$/, "", $2); if ($2 == name) found = 1 } END { exit !found }'
}

# Install package $1 in the distrobox named $2 (created from $DISTROBOX_IMAGE if missing) and copy its
# /usr/bin/$3 binary to $LOCAL_BIN, since the SteamOS rootfs is read-only. Warns if the copy is missing
# shared libraries on this host.
copy_binary_from_distrobox() {
  local package="$1" name="$2" binary="$3"

  if distrobox_exists "$name"; then
    info "Reusing distrobox '$name'"
  else
    info "Creating distrobox '$name' from $DISTROBOX_IMAGE..."
    run distrobox create --name "$name" --image "$DISTROBOX_IMAGE" --yes
  fi

  info "Installing $package in '$name' and copying $binary to $LOCAL_BIN..."
  run_tty distrobox enter "$name" -- bash -c "
    sudo pacman -Sy --noconfirm --needed '$package' &&
    mkdir -p '$LOCAL_BIN' &&
    cp '/usr/bin/$binary' '$LOCAL_BIN/$binary'
  "

  if ! $DRY_RUN && ldd "$LOCAL_BIN/$binary" | grep -q "not found"; then
    warn "$binary is missing shared libraries on this host (see 'ldd $LOCAL_BIN/$binary')."
  fi
}

# Install $1 by copying it out of the distrobox (copy_binary_from_distrobox), unless the command is already available.
# Skips with a warning if distrobox is missing.
install_distrobox_binary() {
  local binary="$1"

  if command -v "$binary" &>/dev/null; then
    info "$binary already available: $(command -v "$binary")"
    return
  fi
  if ! command -v distrobox &>/dev/null; then
    warn "distrobox command not found, skipping $binary setup."
    return
  fi

  copy_binary_from_distrobox "$binary" "$DISTROBOX_NAME" "$binary"
}

# Remove the copy of $1 in $LOCAL_BIN. The distrobox is left alone.
uninstall_distrobox_binary() {
  local binary="$1"
  if [[ ! -e "$LOCAL_BIN/$binary" ]]; then
    info "$LOCAL_BIN/$binary does not exist"
    return
  fi
  info "Removing $LOCAL_BIN/$binary..."
  run rm -f "$LOCAL_BIN/$binary"
}
