# Feature: keyboard screenshots in SteamOS Gaming Mode. gamescope-screenshot --watch watches the keyboards for
# Print Screen or Shift+Meta+4 (macOS's Cmd+Shift+4) and saves the screen with gamescopectl to ~/Pictures/Screenshots.
# The units go into /etc/systemd/user and are enabled globally, so both the units and their links in
# gamescope-session.target.wants are outside an encrypted home and the user manager sees them from boot. See Gaming
# Mode screenshots in README.md.

GAMESCOPE_SCREENSHOT_UNITS_SRC="root/etc/systemd/user"
GAMESCOPE_SCREENSHOT_UNITS=(gamescope-screenshot.service keyboard-rescan.path
  keyboard-rescan.service)
# The units gamescope-session.target wants; the rescan service is started by its path unit.
GAMESCOPE_SCREENSHOT_ENABLED=(gamescope-screenshot.service keyboard-rescan.path)

# Link gamescope-screenshot into ~/.local/bin and install systemd user units into /etc (needs sudo) that run it with
# Gaming Mode and save a screenshot when Print Screen or Shift+Meta+4 is pressed on any keyboard, and restart the watch
# when keyboards come or go.
#
# @machine any
# @os steamos
# @gui any
declare_gamescope_screenshot() {
  hook_link home/.local/bin/gamescope-screenshot
  hook_units user --restart-on-change "$GAMESCOPE_SCREENSHOT_UNITS_SRC" "${GAMESCOPE_SCREENSHOT_UNITS[@]}"
}

# Start the watch now if Gaming Mode is running (units that changed were restarted already).
post_gamescope_screenshot() {
  if ! systemctl --user is-active --quiet gamescope-session.target 2>/dev/null; then
    info "gamescope-screenshot.service starts with Gaming Mode."
    return
  fi
  run systemctl --user start "${GAMESCOPE_SCREENSHOT_ENABLED[@]}"
  info "Press Print Screen or Shift+Meta+4 in Gaming Mode; screenshots go to ~/Pictures/Screenshots."
  info "Check with: journalctl --user -u gamescope-screenshot.service"
}
