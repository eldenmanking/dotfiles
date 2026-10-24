# Feature: hand an OREI HDMI switch to another input while a Framework 16 sleeps, and back on wake, by cutting power
# to the left USB-C PD controller with Framework's framework_tool, and turn the projector off over CEC on sleep and
# poweroff and back on on wake and boot (see root/etc/orei-switch/orei-switch.sh).

OREI_SWITCH_DIR=/etc/orei-switch
OREI_SWITCH_STATE_DIR=/var/lib/orei-switch
OREI_SWITCH_UNITS="orei-switch.service orei-switch-boot.service orei-switch-poweroff.service"
FRAMEWORK_TOOL_VERSION=v0.6.6
FRAMEWORK_TOOL_SHA256=ebc2f3ca300dac6f484c02d058833372ff8dd3c23f2a74b63c774f8dc2f86171
# "<mode> <repo-relative source> <destination>" for each installed file. Copied, not linked: the unit runs when the
# home may be locked. The keep list makes /etc/orei-switch survive SteamOS updates.
OREI_SWITCH_FILES=(
  "755 root/etc/orei-switch/orei-switch.sh $OREI_SWITCH_DIR/orei-switch.sh"
  "644 root/etc/systemd/system/orei-switch.service /etc/systemd/system/orei-switch.service"
  "644 root/etc/systemd/system/orei-switch-boot.service /etc/systemd/system/orei-switch-boot.service"
  "644 root/etc/systemd/system/orei-switch-poweroff.service /etc/systemd/system/orei-switch-poweroff.service"
  "644 root/etc/atomic-update.conf.d/orei-switch.conf /etc/atomic-update.conf.d/orei-switch.conf"
)

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

# Download framework_tool and install the orei-switch script and its sleep, boot and poweroff units into /etc (sudo).
# The units are enabled but not started, since starting the sleep unit can cut power to the left ports.
#
# @machine framework16
# @os linux
# @gui any
feature_orei_switch() {
  local entry mode src dest unit changed=false
  install_framework_tool
  for entry in "${OREI_SWITCH_FILES[@]}"; do
    read -r mode src dest <<<"$entry"
    if cmp -s "$DOTFILES_ROOT/$src" "$dest"; then
      info "$dest already up to date"
      continue
    fi
    run sudo install -Dvm"$mode" "$DOTFILES_ROOT/$src" "$dest"
    changed=true
  done
  ! $changed || run sudo systemctl daemon-reload
  for unit in $OREI_SWITCH_UNITS; do
    if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
      info "$unit already enabled"
    else
      run sudo systemctl enable "$unit"
    fi
  done
  info "Keep the charger on a right-side port: sleep cuts power to ports 2 and 3. Logs: journalctl -t orei-switch -b"
}

# Disable the units and remove the installed files.
uninstall_feature_orei_switch() {
  local entry mode src dest unit removed=false
  for unit in $OREI_SWITCH_UNITS; do
    if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
      run sudo systemctl disable "$unit"
    fi
  done
  for entry in "${OREI_SWITCH_FILES[@]}"; do
    read -r mode src dest <<<"$entry"
    [[ -e "$dest" ]] || continue
    run sudo rm -fv "$dest"
    removed=true
  done
  if [[ -d "$OREI_SWITCH_DIR" ]]; then
    run sudo rm -rfv "$OREI_SWITCH_DIR"
  fi
  if [[ -d "$OREI_SWITCH_STATE_DIR" ]]; then
    run sudo rm -rfv "$OREI_SWITCH_STATE_DIR"
  fi
  ! $removed || run sudo systemctl daemon-reload
}
