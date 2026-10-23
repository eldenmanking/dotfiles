# Feature: set the Framework 16's Radeon 780M to manual clocks, which fixes choppy HDMI audio.

GPU_PERFORMANCE_UNIT="gpu-performance.service"
GPU_PERFORMANCE_SRC="steamos/systemd/$GPU_PERFORMANCE_UNIT"
GPU_PERFORMANCE_DST="/etc/systemd/system/$GPU_PERFORMANCE_UNIT"
GPU_PERFORMANCE_DEVICE="/sys/bus/pci/devices/0000:c1:00.0"

gpu_performance_installed() {
  cmp -s "$DOTFILES_ROOT/$GPU_PERFORMANCE_SRC" "$GPU_PERFORMANCE_DST" \
    && systemctl is-enabled --quiet "$GPU_PERFORMANCE_UNIT" 2>/dev/null
}

# Install gpu-performance.service into /etc (needs sudo), which sets the 780M to the manual performance level with
# its full 800-2700 MHz graphics clock range at boot and after each resume.
#
# @machine framework16
# @os linux
# @gui any
feature_gpu_performance() {
  if gpu_performance_installed; then
    info "$GPU_PERFORMANCE_UNIT already up to date"
    return
  fi
  info "Installing $GPU_PERFORMANCE_UNIT (needs sudo)..."
  run sudo install -Dm644 "$DOTFILES_ROOT/$GPU_PERFORMANCE_SRC" "$GPU_PERFORMANCE_DST"
  run sudo systemctl daemon-reload
  run sudo systemctl reenable "$GPU_PERFORMANCE_UNIT"
  run sudo systemctl start "$GPU_PERFORMANCE_UNIT"
  info "Check with: cat $GPU_PERFORMANCE_DEVICE/power_dpm_force_performance_level $GPU_PERFORMANCE_DEVICE/pp_od_clk_voltage"
}

# Remove gpu-performance.service, then reset the 780M's clock range and set it back to the auto performance level.
uninstall_feature_gpu_performance() {
  if [[ ! -e "$GPU_PERFORMANCE_DST" ]]; then
    info "$GPU_PERFORMANCE_DST does not exist"
    return
  fi
  info "Removing $GPU_PERFORMANCE_UNIT (needs sudo)..."
  run sudo systemctl disable "$GPU_PERFORMANCE_UNIT"
  run sudo rm -f "$GPU_PERFORMANCE_DST"
  run sudo systemctl daemon-reload
  if [[ -e "$GPU_PERFORMANCE_DEVICE/power_dpm_force_performance_level" ]]; then
    run sudo sh -c "echo r > $GPU_PERFORMANCE_DEVICE/pp_od_clk_voltage; echo c > $GPU_PERFORMANCE_DEVICE/pp_od_clk_voltage
      echo auto > $GPU_PERFORMANCE_DEVICE/power_dpm_force_performance_level"
  fi
}
