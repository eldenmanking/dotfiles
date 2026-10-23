# Feature: install home-units.service system-wide (steamos). With a dirlock-encrypted home, the user manager starts
# before the home is unlocked and can't see ~/.config/systemd/user; this unit starts those units once it is unlocked.
# A SteamOS keep list makes the files survive OS updates. See steamos/README.md.

HOME_UNITS_SRC="steamos"
HOME_UNITS_KEEP_LIST=/etc/atomic-update.conf.d/dotfiles.conf
# "<mode> <repo-relative source> <destination>" for each installed file.
HOME_UNITS_FILES=(
  "755 $HOME_UNITS_SRC/bin/home-units-start /etc/dotfiles/home-units-start"
  "644 $HOME_UNITS_SRC/systemd/home-units.service /etc/systemd/user/home-units.service"
  "644 $HOME_UNITS_SRC/systemd/home-units.keep.conf $HOME_UNITS_KEEP_LIST"
)
# Files installed by the standalone steamos-config repo, before it moved into dotfiles.
HOME_UNITS_OLD_FILES=(
  /etc/steamos-config/home-units-start
  /etc/atomic-update.conf.d/steamos-config.conf
  /etc/atomic-update.conf.d/home-units.conf
)

# Installed copies are compared with the repo, so updates get reinstalled too.
home_units_current() {
  local entry mode src dest
  for entry in "${HOME_UNITS_FILES[@]}"; do
    read -r mode src dest <<<"$entry"
    cmp -s "$DOTFILES_ROOT/$src" "$dest" || return 1
  done
}

home_is_encrypted() {
  command -v dirlock >/dev/null && dirlock status "$HOME" 2>/dev/null | grep -q '^Encrypted'
}

# Error unless the keep list names every other installed file.
check_home_units_keep_list() {
  local entry mode src dest
  for entry in "${HOME_UNITS_FILES[@]}"; do
    read -r mode src dest <<<"$entry"
    [[ "$dest" == "$HOME_UNITS_KEEP_LIST" ]] && continue
    grep -qxF "$dest" "$DOTFILES_ROOT/$HOME_UNITS_SRC/systemd/home-units.keep.conf" \
      || error "$dest is missing from $HOME_UNITS_SRC/systemd/home-units.keep.conf"
  done
}

# With a dirlock-encrypted home, install home-units.service into /etc (needs sudo) so user units in the home
# start once it is unlocked.
#
# @machine any
# @os steamos
# @gui any
feature_home_units() {
  if home_units_current; then
    info "home-units.service already up to date"
    return
  fi
  if ! home_is_encrypted; then
    info "Home directory is not encrypted with dirlock; home-units.service is not needed."
    return
  fi
  check_home_units_keep_list

  info "Your home directory is encrypted: installing home-units.service (needs sudo) so units in it start after a reboot."
  local entry mode src dest
  for entry in "${HOME_UNITS_FILES[@]}"; do
    read -r mode src dest <<<"$entry"
    run sudo install -Dm"$mode" "$DOTFILES_ROOT/$src" "$dest"
  done
  run sudo systemctl --global enable home-units.service
  run sudo rm -f "${HOME_UNITS_OLD_FILES[@]}"
  run sudo rmdir /etc/steamos-config 2>/dev/null || true

  info "Installed. From the next login on, units in your home directory start"
  info "once it is unlocked. Check with: systemctl --user status home-units.service"
}
