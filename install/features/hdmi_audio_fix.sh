# Feature: keep the Framework 16's Radeon 780M SoC clock up, which fixes choppy HDMI audio.

HDMI_AUDIO_FIX_SRC="steamos/systemd"
HDMI_AUDIO_FIX_UNIT="hdmi-audio-fix.service"
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

# Install hdmi-audio-fix.service into /etc (needs sudo), which sets a 720 MHz socclk floor on the 780M (at the
# manual level, with the other clocks left free) at boot and after each resume.
#
# @machine framework16
# @os linux
# @gui any
feature_hdmi_audio_fix() {
  f_write_args install_system_units _changed -- "$DOTFILES_ROOT/$HDMI_AUDIO_FIX_SRC" "$HDMI_AUDIO_FIX_UNIT"
  [[ -n "$_changed" ]] || return 0
  info "Check with: cat /sys/bus/pci/devices/*/pp_dpm_socclk (no level below 720 MHz should be active)"
}

# Remove hdmi-audio-fix.service, then reset the 780M's clock range and set it back to the auto performance level,
# which also lifts the socclk floor.
uninstall_feature_hdmi_audio_fix() {
  f_write_args uninstall_system_units _removed -- "$HDMI_AUDIO_FIX_UNIT"
  [[ -n "$_removed" ]] || return 0
  local dev
  for dev in $(pci_devices_with_id "$HDMI_AUDIO_FIX_ID"); do
    run sudo sh -c "echo r > $dev/pp_od_clk_voltage; echo c > $dev/pp_od_clk_voltage
      echo auto > $dev/power_dpm_force_performance_level"
  done
}
