# Feature: stop Steam's Slow Charger dialog by reporting a charger that can't keep up as an ordinary one (see
# root/etc/dotfiles/bin/vpower-filter).

QUIET_SLOW_CHARGER_SCRIPT="root/etc/dotfiles/bin/vpower-filter"
QUIET_SLOW_CHARGER_UNIT_SRC="root/etc/systemd/system"
QUIET_SLOW_CHARGER_UNIT="vpower-filter.service"
QUIET_SLOW_CHARGER_DROPIN_SRC="root/etc/systemd/system/vpower.service.d"
QUIET_SLOW_CHARGER_DROPIN_DIR="$SYSTEM_UNITS_DIR/vpower.service.d"
QUIET_SLOW_CHARGER_DROPIN="vpower-filter.conf"

# Install vpower-filter into /etc/dotfiles/bin, its service, and a vpower.service drop-in that makes vpower write its
# state for vpower-filter to pass on, into /etc (sudo), then restart vpower if any of them changed. Copied, not
# linked: systemd starts them at boot, while the home may be locked.
#
# @machine framework16
# @os steamos
# @gui any
feature_quiet_slow_charger() {
  local script_dest="/${QUIET_SLOW_CHARGER_SCRIPT#root/}" changed="" units dropin
  # SteamOS's default keep list covers the unit and the drop-in (*.service.d/), but not the script.
  keep_across_steamos_updates quiet_slow_charger "$script_dest"
  cmp -s "$DOTFILES_ROOT/$QUIET_SLOW_CHARGER_SCRIPT" "$script_dest" || changed="$script_dest"
  copy_system_file 755 "$QUIET_SLOW_CHARGER_SCRIPT"
  f_call install_system_units units=changed -- "$DOTFILES_ROOT/$QUIET_SLOW_CHARGER_UNIT_SRC" \
    "$QUIET_SLOW_CHARGER_UNIT"
  f_call copy_system_files dropin=changed -- "$DOTFILES_ROOT/$QUIET_SLOW_CHARGER_DROPIN_SRC" \
    "$QUIET_SLOW_CHARGER_DROPIN" "$QUIET_SLOW_CHARGER_DROPIN_DIR"
  [[ -z "$dropin" ]] || run sudo systemctl daemon-reload
  if [[ -n "$changed$units$dropin" ]]; then
    # Restarting vpower restarts vpower-filter too (BindsTo=), and starts it if it wasn't running (Wants=).
    # vpower only runs where there is a battery (its ConditionPathExistsGlob=), so try-restart leaves it off otherwise.
    run sudo systemctl try-restart vpower.service
  fi
  info "Steam now shows a slow charger as connected. Logs: journalctl -b -u vpower-filter"
}

# Remove the drop-in and restart vpower, so it writes /run/vpower itself again, then the service and the script.
uninstall_feature_quiet_slow_charger() {
  local removed dropin=""
  if [[ -e "$QUIET_SLOW_CHARGER_DROPIN_DIR/$QUIET_SLOW_CHARGER_DROPIN" ]]; then
    run sudo rm -fv "$QUIET_SLOW_CHARGER_DROPIN_DIR/$QUIET_SLOW_CHARGER_DROPIN"
    if [[ -d "$QUIET_SLOW_CHARGER_DROPIN_DIR" && -z "$(ls -A "$QUIET_SLOW_CHARGER_DROPIN_DIR")" ]]; then
      run sudo rmdir "$QUIET_SLOW_CHARGER_DROPIN_DIR"
    fi
    run sudo systemctl daemon-reload
    dropin=removed
  fi
  f_call uninstall_system_units removed -- "$QUIET_SLOW_CHARGER_UNIT"
  # After vpower-filter has stopped, so nothing copies over vpower's own files.
  [[ -z "$dropin$removed" ]] || run sudo systemctl try-restart vpower.service
  remove_system_files "/${QUIET_SLOW_CHARGER_SCRIPT#root/}"
  forget_across_steamos_updates quiet_slow_charger
}
