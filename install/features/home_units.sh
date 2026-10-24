# Feature: install home-units.service system-wide (steamos). With a dirlock-encrypted home, the user manager starts
# before the home is unlocked and can't see ~/.config/systemd/user; this unit starts those units once it is unlocked.
# A SteamOS keep list makes the files survive OS updates: SteamOS's default list keeps system units in
# /etc/systemd/system, but nothing in /etc/systemd/user. See steamos/README.md.

HOME_UNITS_SRC="steamos"
# "<mode> <repo-relative source> <destination>" for each installed file.
HOME_UNITS_FILES=(
  "755 $HOME_UNITS_SRC/bin/home-units-start /etc/dotfiles/home-units-start"
  "644 $HOME_UNITS_SRC/systemd/home-units.service /etc/systemd/user/home-units.service"
)
# The link 'systemctl --global enable' makes, from the unit's WantedBy=default.target.
HOME_UNITS_ENABLED_LINK=/etc/systemd/user/default.target.wants/home-units.service

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

# Print the destination of each installed file, then the enablement link, one per line.
home_units_paths() {
  local entry mode src dest
  for entry in "${HOME_UNITS_FILES[@]}"; do
    read -r mode src dest <<<"$entry"
    printf '%s\n' "$dest"
  done
  printf '%s\n' "$HOME_UNITS_ENABLED_LINK"
}


# With a dirlock-encrypted home, install home-units.service into /etc (needs sudo) so user units in the home
# start once it is unlocked, and keep it across SteamOS updates.
#
# @machine any
# @os steamos
# @gui any
feature_home_units() {
  if home_units_current; then
    info "home-units.service already up to date"
  elif ! home_is_encrypted; then
    info "Home directory is not encrypted with dirlock; home-units.service is not needed."
    return
  else
    info "Your home directory is encrypted: installing home-units.service (needs sudo) so units in it start after a reboot."
    local entry mode src dest
    for entry in "${HOME_UNITS_FILES[@]}"; do
      read -r mode src dest <<<"$entry"
      run sudo install -Dm"$mode" "$DOTFILES_ROOT/$src" "$dest"
    done
    run sudo systemctl --global enable home-units.service
    info "Installed. From the next login on, units in your home directory start"
    info "once it is unlocked. Check with: systemctl --user status home-units.service"
  fi

  # Also when up to date, so the keep list always names what is installed.
  keep_across_steamos_updates home_units $(home_units_paths)
}
