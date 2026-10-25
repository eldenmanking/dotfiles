# Feature: hand an OREI HDMI switch to another input while a Framework 16 sleeps, and back on wake, by cutting power
# to the left USB-C PD controller with Framework's framework_tool, and turn the projector off over CEC on sleep and
# poweroff and back on on wake and boot (see root/etc/dotfiles/bin/orei-switch). Also lay out the boot login screen for
# the projector (root/etc/dotfiles/bin/sddm-xsetup).

OREI_SWITCH_UNITS_SRC="root/etc/systemd/system"
OREI_SWITCH_UNITS="orei-switch.service orei-switch-boot.service orei-switch-poweroff.service"
FRAMEWORK_TOOL_VERSION=v0.6.6
FRAMEWORK_TOOL_SHA256=ebc2f3ca300dac6f484c02d058833372ff8dd3c23f2a74b63c774f8dc2f86171
FRAMEWORK_TOOL="$SYSTEM_BIN_DIR/framework_tool"
# "<mode> <repo-relative source>" for each file installed besides the units, at its path under root/. Copied, not
# linked: they run while the home may be locked.
OREI_SWITCH_FILES=(
  "755 root/etc/dotfiles/bin/orei-switch"
  "755 root/etc/dotfiles/bin/sddm-xsetup"
  "644 root/etc/sddm.conf.d/orei-switch.conf"
)

# Print the path of each file the feature installs besides the units, framework_tool last, one per line.
orei_switch_paths() {
  local entry mode src
  for entry in "${OREI_SWITCH_FILES[@]}"; do
    read -r mode src <<<"$entry"
    printf '%s\n' "/${src#root/}"
  done
  printf '%s\n' "$FRAMEWORK_TOOL"
}

# Download the pinned framework_tool into SYSTEM_BIN_DIR unless it is already there.
install_framework_tool() {
  local dest="$FRAMEWORK_TOOL" tmp
  if sha256_matches "$dest" "$FRAMEWORK_TOOL_SHA256"; then
    info "framework_tool $FRAMEWORK_TOOL_VERSION already installed"
    return
  fi
  info "Downloading framework_tool $FRAMEWORK_TOOL_VERSION"
  tmp="$(mktemp)"
  download_verified \
    "https://github.com/FrameworkComputer/framework-system/releases/download/$FRAMEWORK_TOOL_VERSION/framework_tool" \
    "$FRAMEWORK_TOOL_SHA256" "$tmp" framework_tool \
    || { rm -f "$tmp"; error "Failed to download framework_tool"; }
  run sudo install -Dm755 "$tmp" "$dest"
  rm -f "$tmp"
}

# Download framework_tool and install the orei-switch scripts, the SDDM config and the sleep, boot and poweroff units
# into /etc (sudo). The units are enabled but not started: starting the sleep unit cuts power to the left ports, and
# the poweroff one turns the projector off.
#
# @machine framework16
# @os linux
# @gui any
feature_orei_switch() {
  local entry mode src
  # The default keep list covers the units, but not these files.
  keep_across_steamos_updates orei_switch $(orei_switch_paths) \
    $(unit_keep_paths "$SYSTEM_UNITS_DIR" "$DOTFILES_ROOT/$OREI_SWITCH_UNITS_SRC" $OREI_SWITCH_UNITS)
  install_framework_tool
  for entry in "${OREI_SWITCH_FILES[@]}"; do
    read -r mode src <<<"$entry"
    copy_system_file "$mode" "$src"
  done
  f_write_args install_system_units _changed -- --no-start "$DOTFILES_ROOT/$OREI_SWITCH_UNITS_SRC" $OREI_SWITCH_UNITS
  info "Keep the charger on a right-side port: sleep cuts power to ports 2 and 3. Logs: journalctl -t orei-switch -b"
}

# Disable and remove the units, then the installed files.
uninstall_feature_orei_switch() {
  f_write_args uninstall_system_units _removed -- $OREI_SWITCH_UNITS
  remove_system_files $(orei_switch_paths)
  forget_across_steamos_updates orei_switch
}
