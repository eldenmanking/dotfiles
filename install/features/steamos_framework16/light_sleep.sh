# Feature: idle with the displays off instead of suspending while an eGPU is on the Framework 16 expansion bay, whose
# PCIe link doesn't survive s2idle (see root/etc/dotfiles/bin/light-sleep and docs/light-sleep.md).

LIGHT_SLEEP_SCRIPTS="root/etc/dotfiles/bin/light-sleep root/etc/dotfiles/bin/light-sleep-helper"
LIGHT_SLEEP_DROPIN_SRC="root/etc/systemd/system/systemd-suspend.service.d"
LIGHT_SLEEP_DROPIN_DIR="$SYSTEM_UNITS_DIR/systemd-suspend.service.d"
LIGHT_SLEEP_DROPIN="light-sleep.conf"

# Print the install path of each script, one per line.
light_sleep_script_paths() {
  local src
  for src in $LIGHT_SLEEP_SCRIPTS; do
    printf '%s\n' "/${src#root/}"
  done
}

# Install light-sleep and its helper into /etc/dotfiles/bin, and a systemd-suspend.service drop-in that suspends
# through them, into /etc (sudo). Copied, not linked: systemd runs them while the home may be locked.
#
# @machine framework16
# @os steamos
# @gui any
feature_light_sleep() {
  local src
  # SteamOS's default keep list covers the drop-in (*.service.d/), but not the scripts.
  keep_across_steamos_updates light_sleep $(light_sleep_script_paths)
  for src in $LIGHT_SLEEP_SCRIPTS; do
    copy_system_file 755 "$src"
  done
  f_write_args copy_system_files _changed -- "$DOTFILES_ROOT/$LIGHT_SLEEP_DROPIN_SRC" "$LIGHT_SLEEP_DROPIN_DIR" \
    "$LIGHT_SLEEP_DROPIN"
  [[ -z "$_changed" ]] || run sudo systemctl daemon-reload
  info "Suspend idles instead while an eGPU is on the expansion bay. Logs: journalctl -t light-sleep -b"
}

# Remove the drop-in, so suspend runs systemd-sleep directly again, then the scripts.
uninstall_feature_light_sleep() {
  if [[ -e "$LIGHT_SLEEP_DROPIN_DIR/$LIGHT_SLEEP_DROPIN" ]]; then
    run sudo rm -fv "$LIGHT_SLEEP_DROPIN_DIR/$LIGHT_SLEEP_DROPIN"
    if [[ -d "$LIGHT_SLEEP_DROPIN_DIR" && -z "$(ls -A "$LIGHT_SLEEP_DROPIN_DIR")" ]]; then
      run sudo rmdir "$LIGHT_SLEEP_DROPIN_DIR"
    fi
    run sudo systemctl daemon-reload
  fi
  remove_system_files $(light_sleep_script_paths)
  forget_across_steamos_updates light_sleep
}
