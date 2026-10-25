# Feature: hand an OREI HDMI switch to another input while a Framework 16 sleeps, and back on wake, by cutting power
# to the left USB-C PD controller with Framework's framework_tool, and turn the projector off over CEC on sleep and
# poweroff and back on on wake and boot (see root/etc/dotfiles/orei-switch/orei-switch.sh). Also lay out the boot login
# screen for the projector (root/etc/dotfiles/orei-switch/sddm-xsetup).

OREI_SWITCH_DIR=/etc/dotfiles/orei-switch
OREI_SWITCH_UNITS_SRC="root/etc/systemd/system"
OREI_SWITCH_UNITS="orei-switch.service orei-switch-boot.service orei-switch-poweroff.service"
FRAMEWORK_TOOL_VERSION=v0.6.6
FRAMEWORK_TOOL_SHA256=ebc2f3ca300dac6f484c02d058833372ff8dd3c23f2a74b63c774f8dc2f86171
# "<mode> <repo-relative source>" for each file installed besides the units, at its path under root/. Copied, not
# linked: they run while the home may be locked.
OREI_SWITCH_FILES=(
  "755 root/etc/dotfiles/orei-switch/orei-switch.sh"
  "755 root/etc/dotfiles/orei-switch/sddm-xsetup"
  "644 root/etc/sddm.conf.d/orei-switch.conf"
)
# The units are on SteamOS's default keep list; these aren't.
OREI_SWITCH_KEEP_PATHS=("$OREI_SWITCH_DIR/**" /etc/sddm.conf.d/orei-switch.conf)

# Download the pinned framework_tool into $OREI_SWITCH_DIR unless it is already there.
install_framework_tool() {
  local dest="$OREI_SWITCH_DIR/framework_tool" tmp
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
  local entry mode src dest
  keep_across_steamos_updates orei_switch "${OREI_SWITCH_KEEP_PATHS[@]}"
  install_framework_tool
  for entry in "${OREI_SWITCH_FILES[@]}"; do
    read -r mode src <<<"$entry"
    dest="/${src#root/}"
    if cmp -s "$DOTFILES_ROOT/$src" "$dest"; then
      info "$dest already up to date"
      continue
    fi
    run sudo install -Dvm"$mode" "$DOTFILES_ROOT/$src" "$dest"
  done
  f_write_args install_system_units _changed -- --no-start "$DOTFILES_ROOT/$OREI_SWITCH_UNITS_SRC" $OREI_SWITCH_UNITS
  info "Keep the charger on a right-side port: sleep cuts power to ports 2 and 3. Logs: journalctl -t orei-switch -b"
}

# Disable and remove the units, then the installed files.
uninstall_feature_orei_switch() {
  local entry mode src dest
  f_write_args uninstall_system_units _removed -- $OREI_SWITCH_UNITS
  for entry in "${OREI_SWITCH_FILES[@]}"; do
    read -r mode src <<<"$entry"
    dest="/${src#root/}"
    [[ -e "$dest" ]] || continue
    run sudo rm -fv "$dest"
  done
  if [[ -d "$OREI_SWITCH_DIR" ]]; then
    run sudo rm -rfv "$OREI_SWITCH_DIR"
  fi
}
