# Feature: idle with the displays off instead of suspending while an eGPU is on the Framework 16 expansion bay, whose
# PCIe link doesn't survive s2idle (see root/etc/dotfiles/bin/light-sleep and docs/light-sleep.md).

LIGHT_SLEEP_SCRIPT="root/etc/dotfiles/bin/light-sleep"
LIGHT_SLEEP_DROPIN_SRC="root/etc/systemd/system/systemd-suspend.service.d"
LIGHT_SLEEP_DROPIN_DIR="$SYSTEM_UNITS_DIR/systemd-suspend.service.d"
LIGHT_SLEEP_DROPIN="light-sleep.conf"

# Install light-sleep into /etc/dotfiles/bin, and a systemd-suspend.service drop-in that suspends through it, into
# /etc (sudo). Copied, not linked: systemd runs them while the home may be locked.
#
# @machine framework16
# @os steamos
# @gui any
feature_light_sleep() {
  local changed
  # SteamOS's default keep list covers the drop-in (*.service.d/), but not the script.
  keep_across_steamos_updates light_sleep "/${LIGHT_SLEEP_SCRIPT#root/}"
  copy_system_file 755 "$LIGHT_SLEEP_SCRIPT"
  f_call copy_system_files changed -- "$DOTFILES_ROOT/$LIGHT_SLEEP_DROPIN_SRC" "$LIGHT_SLEEP_DROPIN" \
    "$LIGHT_SLEEP_DROPIN_DIR"
  [[ -z "$changed" ]] || run sudo systemctl daemon-reload
  info "Suspend idles instead while an eGPU is on the expansion bay. Logs: journalctl -t light-sleep -b"
}

# Remove the drop-in, so suspend runs systemd-sleep directly again, then the script.
uninstall_feature_light_sleep() {
  if [[ -e "$LIGHT_SLEEP_DROPIN_DIR/$LIGHT_SLEEP_DROPIN" ]]; then
    run sudo rm -fv "$LIGHT_SLEEP_DROPIN_DIR/$LIGHT_SLEEP_DROPIN"
    if [[ -d "$LIGHT_SLEEP_DROPIN_DIR" && -z "$(ls -A "$LIGHT_SLEEP_DROPIN_DIR")" ]]; then
      run sudo rmdir "$LIGHT_SLEEP_DROPIN_DIR"
    fi
    run sudo systemctl daemon-reload
  fi
  remove_system_files "/${LIGHT_SLEEP_SCRIPT#root/}"
  forget_across_steamos_updates light_sleep
}
