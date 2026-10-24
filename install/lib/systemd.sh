# systemd helpers: system units copied into /etc, and user units copied into ~/.config/systemd/user.

SYSTEM_UNITS_DIR="/etc/systemd/system"
USER_UNITS_DIR="$HOME/.config/systemd/user"

# Copy system units $2... from $1 into /etc/systemd/system with sudo (copied, not linked: see copy_system_files),
# then reload systemd and reenable and restart each unit that changed or isn't enabled yet, so a oneshot service
# runs again. Outputs: _changed, the space-separated units that were (re)enabled (empty if all were up to date).
# Usage: f_write_args install_system_units _changed -- <src_dir> <unit>...
install_system_units() {
  local src_dir="$1" unit changed=""
  shift
  for unit in "$@"; do
    [[ -e "$src_dir/$unit" ]] || error "install_system_units: $src_dir/$unit does not exist"
    f_write_args copy_system_files _changed -- "$src_dir" "$SYSTEM_UNITS_DIR" "$unit"
    if [[ -n "$_changed" ]] || ! systemctl is-enabled --quiet "$unit" 2>/dev/null; then
      changed+="${changed:+ }$unit"
    fi
  done
  if [[ -n "$changed" ]]; then
    run sudo systemctl daemon-reload
    for unit in $changed; do
      run sudo systemctl reenable "$unit"
      run sudo systemctl restart "$unit"
    done
  fi
  _changed="$changed"
}

# Stop, disable and remove system units $1... from /etc/systemd/system with sudo, then reload systemd. Units that
# aren't installed are skipped. Outputs: _removed, the space-separated units that were removed.
# Usage: f_write_args uninstall_system_units _removed -- <unit>...
uninstall_system_units() {
  local unit removed=""
  for unit in "$@"; do
    if [[ ! -e "$SYSTEM_UNITS_DIR/$unit" && ! -L "$SYSTEM_UNITS_DIR/$unit" ]]; then
      info "$SYSTEM_UNITS_DIR/$unit does not exist"
      continue
    fi
    info "Removing $SYSTEM_UNITS_DIR/$unit..."
    run sudo systemctl disable --now "$unit"
    run sudo rm -f "$SYSTEM_UNITS_DIR/$unit"
    removed+="${removed:+ }$unit"
  done
  [[ -z "$removed" ]] || run sudo systemctl daemon-reload
  _removed="$removed"
}

# Copy user units $2... from $1 into ~/.config/systemd/user, then reload the user manager if any changed. They are
# copied, not linked: systemd treats a symlinked unit file as a "linked" unit, which enable and disable handle
# differently. Outputs: _changed, the space-separated units that were copied (empty if all were up to date).
# Usage: f_write_args install_user_units _changed -- <src_dir> <unit>...
install_user_units() {
  local src_dir="$1" unit target changed=""
  shift
  for unit in "$@"; do
    [[ -e "$src_dir/$unit" ]] || error "install_user_units: $src_dir/$unit does not exist"
    target="$USER_UNITS_DIR/$unit"
    if [[ ! -L "$target" ]] && cmp -s "$src_dir/$unit" "$target"; then
      info "$target already up to date"
      continue
    fi
    info "Copying $src_dir/$unit to $target..."
    run mkdir -p "$USER_UNITS_DIR"
    run rm -f "$target"
    run install -m 644 "$src_dir/$unit" "$target"
    changed+="${changed:+ }$unit"
  done
  [[ -z "$changed" ]] || run systemctl --user daemon-reload
  _changed="$changed"
}
