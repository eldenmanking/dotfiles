# Feature: arch distrobox (steamos).

DISTROBOX_NAME="arch"
DISTROBOX_IMAGE="archlinux:latest"

# Return 0 if a distrobox named $1 exists. Matches the NAME column exactly, so
# 'arch' doesn't match e.g. 'tmp-arch'.
_distrobox_exists() {
  distrobox list --no-color 2>/dev/null \
    | awk -F'|' -v name="$1" 'NR > 1 { gsub(/^ +| +$/, "", $2); if ($2 == name) found = 1 } END { exit !found }'
}

# With --reset, ask before removing an existing distrobox so it is recreated.
# Outputs: _keep, true if the existing distrobox should be left as is.
_distrobox_reset() {
  local name="$1"
  if $DRY_RUN; then
    info "[dry-run] would ask to remove distrobox '$name'"
  elif ! has_tty; then
    warn "No terminal to confirm removing distrobox '$name'; keeping it"
    _keep=true
    return
  elif ! confirm "Remove distrobox '$name' and all changes made inside it?"; then
    info "Keeping distrobox '$name'"
    _keep=true
    return
  fi
  info "Removing distrobox '$name'..."
  run distrobox rm --force "$name"
  _keep=false
}

# Create the arch distrobox and enter it once to finish its setup. With
# --reset, offers to delete and recreate an existing one.
feature_distrobox() {
  local options="${3:-}" name="$DISTROBOX_NAME"

  if ! command -v distrobox &>/dev/null; then
    warn "distrobox command not found, skipping."
    return
  fi

  if _distrobox_exists "$name"; then
    if ! list_contains "$options" reset; then
      info "distrobox '$name' already exists (use --reset to recreate it)"
      return
    fi
    f_write_args _distrobox_reset _keep -- "$name"
    ! $_keep || return 0
  fi

  info "Creating distrobox '$name' from $DISTROBOX_IMAGE..."
  run distrobox create --name "$name" --image "$DISTROBOX_IMAGE" --yes
  info "Entering distrobox '$name' (exit the shell to continue)..."
  run_tty distrobox enter "$name" || warn "distrobox '$name' shell exited with status $?"
}
