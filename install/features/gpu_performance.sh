# Feature: force AMD GPUs to manual DPM with the 3D full-screen power profile (steamos).

GPU_PERFORMANCE_UNIT="gpu-performance.service"
GPU_PERFORMANCE_SRC="steamos/systemd/$GPU_PERFORMANCE_UNIT"
GPU_PERFORMANCE_DST="/etc/systemd/system/$GPU_PERFORMANCE_UNIT"

gpu_performance_installed() {
  cmp -s "$DOTFILES_ROOT/$GPU_PERFORMANCE_SRC" "$GPU_PERFORMANCE_DST" \
    && systemctl is-enabled --quiet "$GPU_PERFORMANCE_UNIT" 2>/dev/null
}

# Install gpu-performance.service into /etc (needs sudo), which sets every amdgpu card to the manual performance
# level and power profile 1 at boot and after each resume.
#
# @machine any
# @os steamos
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
  info "Check with: cat /sys/class/drm/card*/device/power_dpm_force_performance_level"
}

# Remove gpu-performance.service and set every amdgpu card back to the auto performance level.
uninstall_feature_gpu_performance() {
  if [[ ! -e "$GPU_PERFORMANCE_DST" ]]; then
    info "$GPU_PERFORMANCE_DST does not exist"
    return
  fi
  info "Removing $GPU_PERFORMANCE_UNIT (needs sudo)..."
  run sudo systemctl disable "$GPU_PERFORMANCE_UNIT"
  run sudo rm -f "$GPU_PERFORMANCE_DST"
  run sudo systemctl daemon-reload
  run sudo sh -c 'for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
    [ -e "$f" ] && echo auto > "$f"; done; true'
}
