# Feature: keyboard screenshots in SteamOS Gaming Mode. gamescope-screenshot --watch watches the keyboards for
# Print Screen or Shift+Meta+4 (macOS's Cmd+Shift+4) and saves the screen with gamescopectl to ~/Pictures/Screenshots.
# The units go into /etc/systemd/user and are enabled globally, so both the units and their links in
# gamescope-session.target.wants are outside an encrypted home and the user manager sees them from boot. See Gaming
# Mode screenshots in README.md.

GAMESCOPE_SCREENSHOT_UNITS_SRC="$DOTFILES_ROOT/root/etc/systemd/user"
GAMESCOPE_SCREENSHOT_UNITS=(gamescope-screenshot.service keyboard-rescan.path
  keyboard-rescan.service)
# The units gamescope-session.target wants; the rescan service is started by its path unit.
GAMESCOPE_SCREENSHOT_ENABLED=(gamescope-screenshot.service keyboard-rescan.path)

# Install systemd user units into /etc (needs sudo) that run with Gaming Mode and save a screenshot when Print Screen
# or Shift+Meta+4 is pressed on any keyboard, and restart the watch when keyboards come or go.
#
# @machine any
# @os steamos
# @gui any
# @requires link
feature_gamescope_screenshot() {
  keep_across_steamos_updates gamescope_screenshot $(unit_keep_paths "$USER_UNITS_DIR" \
    "$GAMESCOPE_SCREENSHOT_UNITS_SRC" "${GAMESCOPE_SCREENSHOT_UNITS[@]}")
  f_write_args install_user_units _changed -- --global "$GAMESCOPE_SCREENSHOT_UNITS_SRC" \
    "${GAMESCOPE_SCREENSHOT_UNITS[@]}"

  if ! systemctl --user is-active --quiet gamescope-session.target 2>/dev/null; then
    info "gamescope-screenshot.service starts with Gaming Mode."
    return
  fi
  if [[ -n "$_changed" ]]; then
    run systemctl --user restart "${GAMESCOPE_SCREENSHOT_ENABLED[@]}"
  else
    run systemctl --user start "${GAMESCOPE_SCREENSHOT_ENABLED[@]}"
  fi
  info "Press Print Screen or Shift+Meta+4 in Gaming Mode; screenshots go to ~/Pictures/Screenshots."
  info "Check with: journalctl --user -u gamescope-screenshot.service"
}

# Stop the screenshot watch and remove its units and their enablement links. Screenshots already taken are kept.
uninstall_feature_gamescope_screenshot() {
  f_write_args uninstall_user_units _removed -- --global "${GAMESCOPE_SCREENSHOT_UNITS[@]}"
  forget_across_steamos_updates gamescope_screenshot
}
