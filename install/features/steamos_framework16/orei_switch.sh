# Feature: hand an OREI HDMI switch to another input while a Framework 16 sleeps, and back on wake, by cutting power
# to the left USB-C PD controller with Framework's framework_tool, and turn the projector off over CEC on sleep and
# poweroff and back on on wake and boot (see root/etc/dotfiles/bin/orei-switch). Also lay out the boot login screen for
# the projector (root/etc/dotfiles/bin/sddm-xsetup), and keep its exit from dropping the switch to the session's VT
# (root/etc/dotfiles/bin/sddm-xstop).

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
  "755 root/etc/dotfiles/bin/sddm-xstop"
  "644 root/etc/sddm.conf.d/orei-switch.conf"
)

# Install the orei-switch scripts, the SDDM config, framework_tool and the sleep, boot and poweroff units into /etc
# (needs sudo). The units are enabled but not started: starting the sleep unit cuts power to the left ports, and the
# poweroff one turns the projector off.
#
# @machine framework16
# @os steamos
# @gui any
declare_orei_switch() {
  local entry mode src
  for entry in "${OREI_SWITCH_FILES[@]}"; do
    read -r mode src <<<"$entry"
    hook_file "$mode" "$src"
  done
  hook_download 755 "$FRAMEWORK_TOOL" \
    "https://github.com/FrameworkComputer/framework-system/releases/download/$FRAMEWORK_TOOL_VERSION/framework_tool" \
    "$FRAMEWORK_TOOL_SHA256"
  hook_units system --no-start "$OREI_SWITCH_UNITS_SRC" $OREI_SWITCH_UNITS
}

# Remind where the charger must go, and where the logs are.
# Usage: post_orei_switch <os> <profile> <enabled> <changed>
post_orei_switch() {
  info "Keep the charger on a right-side port: sleep cuts power to ports 2 and 3. Logs: journalctl -t orei-switch -b"
}
