# Feature: keep the Framework 16's Radeon 780M SoC clock up, which fixes choppy HDMI audio.

HDMI_AUDIO_FIX_UNIT="hdmi-audio-fix.service"
HDMI_AUDIO_FIX_SRC="steamos/systemd/$HDMI_AUDIO_FIX_UNIT"
HDMI_AUDIO_FIX_DST="/etc/systemd/system/$HDMI_AUDIO_FIX_UNIT"
# PCI vendor:device ID of the 780M, matched instead of its address or card number, which can change.
HDMI_AUDIO_FIX_ID="0x1002:0x15bf"

# Print the sysfs directory of each PCI device with ID $1 (vendor:device).
pci_devices_with_id() {
  local dev
  for dev in /sys/bus/pci/devices/*; do
    [[ "$(cat "$dev/vendor" 2>/dev/null):$(cat "$dev/device" 2>/dev/null)" == "$1" ]] && echo "$dev"
  done
  return 0
}

hdmi_audio_fix_installed() {
  cmp -s "$DOTFILES_ROOT/$HDMI_AUDIO_FIX_SRC" "$HDMI_AUDIO_FIX_DST" \
    && systemctl is-enabled --quiet "$HDMI_AUDIO_FIX_UNIT" 2>/dev/null
}

# Install hdmi-audio-fix.service into /etc (needs sudo), which sets a 720 MHz socclk floor on the 780M (at the
# manual level, with the other clocks left free) at boot and after each resume.
#
# @machine framework16
# @os linux
# @gui any
feature_hdmi_audio_fix() {
  if hdmi_audio_fix_installed; then
    info "$HDMI_AUDIO_FIX_UNIT already up to date"
    return
  fi
  info "Installing $HDMI_AUDIO_FIX_UNIT (needs sudo)..."
  run sudo install -Dm644 "$DOTFILES_ROOT/$HDMI_AUDIO_FIX_SRC" "$HDMI_AUDIO_FIX_DST"
  run sudo systemctl daemon-reload
  run sudo systemctl reenable "$HDMI_AUDIO_FIX_UNIT"
  run sudo systemctl start "$HDMI_AUDIO_FIX_UNIT"
  info "Check with: cat /sys/bus/pci/devices/*/pp_dpm_socclk (no level below 720 MHz should be active)"
}

# Remove hdmi-audio-fix.service, then reset the 780M's clock range and set it back to the auto performance level,
# which also lifts the socclk floor.
uninstall_feature_hdmi_audio_fix() {
  if [[ ! -e "$HDMI_AUDIO_FIX_DST" ]]; then
    info "$HDMI_AUDIO_FIX_DST does not exist"
    return
  fi
  info "Removing $HDMI_AUDIO_FIX_UNIT (needs sudo)..."
  run sudo systemctl disable "$HDMI_AUDIO_FIX_UNIT"
  run sudo rm -f "$HDMI_AUDIO_FIX_DST"
  run sudo systemctl daemon-reload
  local dev
  for dev in $(pci_devices_with_id "$HDMI_AUDIO_FIX_ID"); do
    run sudo sh -c "echo r > $dev/pp_od_clk_voltage; echo c > $dev/pp_od_clk_voltage
      echo auto > $dev/power_dpm_force_performance_level"
  done
}
