# Feature: keyboard screenshots in SteamOS Gaming Mode. gamescope-screenshot --watch watches the keyboards for
# Print Screen or Shift+Meta+4 (macOS's Cmd+Shift+4) and saves the screen with gamescopectl to ~/Pictures/Screenshots.
# The units go into /etc/systemd/user and are enabled globally, so both the units and their links in
# gamescope-session.target.wants are outside an encrypted home: home-units-start can't start them, since
# gamescope-session.target usually comes up after the unlock. See Gaming Mode screenshots in README.md.

GAMESCOPE_SCREENSHOT_UNITS_SRC="$DOTFILES_ROOT/root/etc/systemd/user"
GAMESCOPE_SCREENSHOT_UNITS=(gamescope-screenshot.service keyboard-rescan.path
  keyboard-rescan.service)
# The units gamescope-session.target wants; the rescan service is started by its path unit.
GAMESCOPE_SCREENSHOT_ENABLED=(gamescope-screenshot.service keyboard-rescan.path)
# Where 'systemctl --global enable' links them, from their WantedBy=gamescope-session.target.
GAMESCOPE_SCREENSHOT_WANTS="$USER_UNITS_DIR/gamescope-session.target.wants"

# Print the path of each installed unit and enablement link, one per line, for the SteamOS keep list.
gamescope_screenshot_paths() {
  local unit
  for unit in "${GAMESCOPE_SCREENSHOT_UNITS[@]}"; do
    printf '%s\n' "$USER_UNITS_DIR/$unit"
  done
  for unit in "${GAMESCOPE_SCREENSHOT_ENABLED[@]}"; do
    printf '%s\n' "$GAMESCOPE_SCREENSHOT_WANTS/$unit"
  done
}

# Install systemd user units into /etc (needs sudo) that run with Gaming Mode and save a screenshot when Print Screen
# or Shift+Meta+4 is pressed on any keyboard, and restart the watch when keyboards come or go.
#
# @machine any
# @os steamos
# @gui any
# @requires link
feature_gamescope_screenshot() {
  local unit changed session=false
  systemctl --user show-environment >/dev/null 2>&1 && session=true
  f_write_args install_user_units _changed -- "$GAMESCOPE_SCREENSHOT_UNITS_SRC" "${GAMESCOPE_SCREENSHOT_UNITS[@]}"
  changed="$_changed"
  for unit in "${GAMESCOPE_SCREENSHOT_ENABLED[@]}"; do
    if [[ ! -L "$GAMESCOPE_SCREENSHOT_WANTS/$unit" ]]; then
      run sudo systemctl --global enable "$unit"
      changed+="${changed:+ }$unit"
    fi
  done
  # SteamOS's default keep list covers nothing in /etc/systemd/user.
  keep_across_steamos_updates gamescope_screenshot $(gamescope_screenshot_paths)
  # So a Gaming Mode session started before the next boot sees the new links.
  if [[ -n "$changed" ]] && $session; then
    run systemctl --user daemon-reload
  fi

  if ! systemctl --user is-active --quiet gamescope-session.target 2>/dev/null; then
    info "gamescope-screenshot.service starts with Gaming Mode."
    return
  fi
  if [[ -n "$changed" ]]; then
    run systemctl --user restart "${GAMESCOPE_SCREENSHOT_ENABLED[@]}"
  else
    run systemctl --user start "${GAMESCOPE_SCREENSHOT_ENABLED[@]}"
  fi
  info "Press Print Screen or Shift+Meta+4 in Gaming Mode; screenshots go to ~/Pictures/Screenshots."
  info "Check with: journalctl --user -u gamescope-screenshot.service"
}

# Stop the screenshot watch and remove its units and their enablement links. Screenshots already taken are kept.
uninstall_feature_gamescope_screenshot() {
  local unit session=false installed=false
  systemctl --user show-environment >/dev/null 2>&1 && session=true
  for unit in "${GAMESCOPE_SCREENSHOT_UNITS[@]}"; do
    [[ -e "$USER_UNITS_DIR/$unit" ]] && installed=true
  done
  # Stopping units that aren't loaded fails, so only while their files are there.
  if $installed && $session; then
    run systemctl --user stop "${GAMESCOPE_SCREENSHOT_UNITS[@]}"
  fi
  for unit in "${GAMESCOPE_SCREENSHOT_ENABLED[@]}"; do
    if [[ -L "$GAMESCOPE_SCREENSHOT_WANTS/$unit" ]]; then
      run sudo rm -f "$GAMESCOPE_SCREENSHOT_WANTS/$unit"
    fi
  done
  for unit in "${GAMESCOPE_SCREENSHOT_UNITS[@]}"; do
    if [[ -e "$USER_UNITS_DIR/$unit" || -L "$USER_UNITS_DIR/$unit" ]]; then
      info "Removing $USER_UNITS_DIR/$unit..."
      run sudo rm -f "$USER_UNITS_DIR/$unit"
    fi
  done
  forget_across_steamos_updates gamescope_screenshot
  if $installed && $session; then
    run systemctl --user daemon-reload
  fi
}
