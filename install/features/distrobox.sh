# Feature: arch distrobox (steamos).

DISTROBOX_NAME="arch"
DISTROBOX_IMAGE="archlinux:latest"

# Return 0 if a distrobox named $1 exists. Matches the NAME column exactly, so
# 'arch' doesn't match e.g. 'tmp-arch'.
_distrobox_exists() {
  distrobox list --no-color 2>/dev/null \
    | awk -F'|' -v name="$1" 'NR > 1 { gsub(/^ +| +$/, "", $2); if ($2 == name) found = 1 } END { exit !found }'
}

# Create the arch distrobox and enter it once to finish its setup.
#
# @machine any
# @os linux
# @gui any
feature_distrobox() {
  local name="$DISTROBOX_NAME"

  if ! command -v distrobox &>/dev/null; then
    warn "distrobox command not found, skipping."
    return
  fi
  if _distrobox_exists "$name"; then
    info "distrobox '$name' already exists (use --reinstall to recreate it)"
    return
  fi

  info "Creating distrobox '$name' from $DISTROBOX_IMAGE..."
  run distrobox create --name "$name" --image "$DISTROBOX_IMAGE" --yes
  info "Entering distrobox '$name' (exit the shell to continue)..."
  run_tty distrobox enter "$name" || warn "distrobox '$name' shell exited with status $?"
}

# Remove the arch distrobox, after asking, since it may hold changes.
uninstall_feature_distrobox() {
  local name="$DISTROBOX_NAME"

  if ! command -v distrobox &>/dev/null || ! _distrobox_exists "$name"; then
    info "distrobox '$name' does not exist"
    return
  fi
  if $DRY_RUN; then
    info "[dry-run] would ask to remove distrobox '$name'"
  elif ! has_tty; then
    warn "No terminal to confirm removing distrobox '$name'; keeping it"
    return
  elif ! confirm "Remove distrobox '$name' and all changes made inside it?"; then
    info "Keeping distrobox '$name'"
    return
  fi
  info "Removing distrobox '$name'..."
  run distrobox rm --force "$name"
}
