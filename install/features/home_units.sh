# Feature: install home-units.service system-wide (steamos). With a dirlock-encrypted home, the user manager starts
# before the home is unlocked and can't see ~/.config/systemd/user; this unit starts those units once it is unlocked.
# A SteamOS keep list makes the files survive OS updates: SteamOS's default list keeps system units in
# /etc/systemd/system, but nothing in /etc/systemd/user. See Webterm in README.md.

HOME_UNITS_UNITS_SRC="$DOTFILES_ROOT/root/etc/systemd/user"
HOME_UNITS_UNIT=home-units.service
# The script the unit runs, copied to its path under root/, not linked: the user manager runs it before the home
# directory, and the checkout in it, is unlocked.
HOME_UNITS_START_SRC=root/etc/dotfiles/home-units-start
HOME_UNITS_START="/${HOME_UNITS_START_SRC#root/}"

home_is_encrypted() {
  command -v dirlock >/dev/null && dirlock status "$HOME" 2>/dev/null | grep -q '^Encrypted'
}

# With a dirlock-encrypted home, install home-units.service into /etc (needs sudo) so user units in the home
# start once it is unlocked, and keep it across SteamOS updates. Once installed, it is kept up to date even if the
# home is no longer encrypted.
#
# @machine any
# @os steamos
# @gui any
feature_home_units() {
  if [[ ! -e "$USER_UNITS_DIR/$HOME_UNITS_UNIT" ]] && ! home_is_encrypted; then
    info "Home directory is not encrypted with dirlock; $HOME_UNITS_UNIT is not needed."
    return
  fi
  keep_across_steamos_updates home_units "$HOME_UNITS_START" \
    $(unit_keep_paths "$USER_UNITS_DIR" "$HOME_UNITS_UNIT")
  if [[ -L "$HOME_UNITS_START" ]] || ! cmp -s "$DOTFILES_ROOT/$HOME_UNITS_START_SRC" "$HOME_UNITS_START"; then
    run sudo rm -f "$HOME_UNITS_START"
    run sudo install -Dvm755 "$DOTFILES_ROOT/$HOME_UNITS_START_SRC" "$HOME_UNITS_START"
  else
    info "$HOME_UNITS_START already up to date"
  fi
  f_write_args install_user_units _changed -- --global "$HOME_UNITS_UNITS_SRC" "$HOME_UNITS_UNIT"
  [[ -n "$_changed" ]] || return 0
  info "Installed. From the next login on, units in your home directory start"
  info "once it is unlocked. Check with: systemctl --user status $HOME_UNITS_UNIT"
}

# Remove home-units.service, its enablement link and the script it runs. Units enabled in the home directory no
# longer start after a reboot until something reloads the user manager.
uninstall_feature_home_units() {
  f_write_args uninstall_user_units _removed -- --global "$HOME_UNITS_UNIT"
  if [[ -e "$HOME_UNITS_START" || -L "$HOME_UNITS_START" ]]; then
    run sudo rm -fv "$HOME_UNITS_START"
  fi
  # /etc/dotfiles also holds other features' files, like orei-switch's.
  if [[ -d "${HOME_UNITS_START%/*}" && -z "$(ls -A "${HOME_UNITS_START%/*}")" ]]; then
    run sudo rmdir "${HOME_UNITS_START%/*}"
  fi
  forget_across_steamos_updates home_units
}
