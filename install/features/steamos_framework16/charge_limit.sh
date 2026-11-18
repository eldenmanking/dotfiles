# Feature: let Steam's "Enable battery charge limit" setting set the Framework 16's charge limit. Steam keeps the
# setting itself (ChargeLimitEnabled and ChargeLimit in ~/.local/share/Steam/config/config.vdf) and applies it through
# steamos-manager whenever it starts; this gives steamos-manager a charge limit to set (see
# root/etc/modprobe.d/framework-charge-control.conf and
# root/etc/systemd/system/usr-share-steamos\x2dmanager-devices.mount) and sets Steam's to 80%, the BIOS's default.

CHARGE_LIMIT_MODPROBE="root/etc/modprobe.d/framework-charge-control.conf"
CHARGE_LIMIT_DEVICE="root/etc/dotfiles/steamos-manager/devices/framework-laptop-16.toml"
CHARGE_LIMIT_UNIT_SRC="root/etc/systemd/system"
CHARGE_LIMIT_UNIT='usr-share-steamos\x2dmanager-devices.mount'
CHARGE_LIMIT_MODULE="cros_charge_control"
CHARGE_LIMIT_PARAM="/sys/module/$CHARGE_LIMIT_MODULE/parameters/probe_with_fwk_charge_control"
CHARGE_LIMIT_PERCENT=80
CHARGE_LIMIT_STEAM_CONFIG="$HOME/.local/share/Steam/config/config.vdf"
CHARGE_LIMIT_STEAM_SETTINGS=("ChargeLimitEnabled|1" "ChargeLimit|$CHARGE_LIMIT_PERCENT")

# Unload cros_charge_control if it is loaded and load it again, so the options in /etc/modprobe.d apply.
# Usage: _charge_limit_reload_module
_charge_limit_reload_module() {
  [[ ! -d "/sys/module/$CHARGE_LIMIT_MODULE" ]] || run sudo modprobe -r "$CHARGE_LIMIT_MODULE"
  run sudo modprobe "$CHARGE_LIMIT_MODULE"
}

# Restart steamos-manager, system and user (when there is a user session), so it rereads its device files and offers
# Steam the charge limit, or stops offering it.
# Usage: _charge_limit_restart_steamos_manager
_charge_limit_restart_steamos_manager() {
  run sudo systemctl try-restart steamos-manager.service
  ! has_user_session || run systemctl --user try-restart steamos-manager.service
}

# Turn on Steam's battery charge limit at CHARGE_LIMIT_PERCENT in its config.vdf, for Steam to apply when it starts.
# Usage: _charge_limit_set_steam_setting
_charge_limit_set_steam_setting() {
  local written missing
  if [[ ! -f "$CHARGE_LIMIT_STEAM_CONFIG" ]]; then
    warn "No $CHARGE_LIMIT_STEAM_CONFIG; start Steam once, then rerun with --charge_limit."
    return 0
  fi
  f_call steam_set_vdf written=changed missing -- "$CHARGE_LIMIT_STEAM_CONFIG" "${CHARGE_LIMIT_STEAM_SETTINGS[@]}"
  [[ -z "$missing" ]] ||
    warn "Steam hasn't saved a charge limit yet; turn on its battery charge limit once (Settings > Power), then rerun."
  [[ -z "$written" ]] || info "Steam's charge limit is now on at $CHARGE_LIMIT_PERCENT% from when Steam next starts"
}

# Copy the cros_charge_control option into /etc/modprobe.d, the steamos-manager device file into
# /etc/dotfiles/steamos-manager/devices and the mount unit that adds it to steamos-manager's into /etc/systemd/system
# (sudo), then reload cros_charge_control with the option if it was loaded without it, and restart steamos-manager if
# anything changed. Copied, not linked: they are read at boot, while the home may be locked. Then turn on Steam's
# charge limit at CHARGE_LIMIT_PERCENT in its config.vdf (only while Steam is closed). Loading the module resets the
# limit to 100% until Steam next starts and sets its own, so the first install takes effect after a reboot.
#
# @machine framework16
# @os steamos
# @gui any
feature_charge_limit() {
  local modprobe_dest="/${CHARGE_LIMIT_MODPROBE#root/}" device_dest="/${CHARGE_LIMIT_DEVICE#root/}" changed=""
  local reloaded="" units
  # SteamOS's default keep list covers the mount unit, but not the others.
  keep_across_steamos_updates charge_limit "$modprobe_dest" "$device_dest"
  copy_system_file 644 "$CHARGE_LIMIT_MODPROBE"
  cmp -s "$DOTFILES_ROOT/$CHARGE_LIMIT_DEVICE" "$device_dest" || changed=1
  copy_system_file 644 "$CHARGE_LIMIT_DEVICE"
  # Mounts the overlay too, or mounts it again if the unit changed.
  f_call install_system_units units=changed -- "$DOTFILES_ROOT/$CHARGE_LIMIT_UNIT_SRC" "$CHARGE_LIMIT_UNIT"
  # The option applies when the module loads; reload it now rather than at the next boot.
  if [[ "$(cat "$CHARGE_LIMIT_PARAM" 2>/dev/null)" != Y ]]; then
    _charge_limit_reload_module
    reloaded=1
  fi
  [[ -z "$changed$reloaded$units" ]] || _charge_limit_restart_steamos_manager
  _charge_limit_set_steam_setting
  if [[ -n "$reloaded" ]]; then
    info "Steam's battery charge limit (Settings > Power) now sets the Framework 16's, from the next reboot"
  else
    info "Steam's battery charge limit (Settings > Power) sets the Framework 16's; Steam applies it when it starts"
  fi
}

# Unmount and remove the mount unit and restart steamos-manager, then remove the option and reload cros_charge_control
# without it (which then refuses to load, so the BIOS limit applies again, fully after the next boot), and the device
# file.
uninstall_feature_charge_limit() {
  local removed dir="/${CHARGE_LIMIT_DEVICE#root/}"
  f_call uninstall_system_units removed -- "$CHARGE_LIMIT_UNIT"
  [[ -z "$removed" ]] || _charge_limit_restart_steamos_manager
  if [[ -e "/${CHARGE_LIMIT_MODPROBE#root/}" ]]; then
    run sudo rm -fv "/${CHARGE_LIMIT_MODPROBE#root/}"
    _charge_limit_reload_module
  fi
  # Each folder above the device file up to SYSTEM_DIR goes if that left it empty.
  [[ ! -e "$dir" ]] || run sudo rm -fv "$dir"
  while dir="${dir%/*}"; [[ "$dir" == "$SYSTEM_DIR"/* ]]; do
    [[ -d "$dir" && -z "$(ls -A "$dir")" ]] || break
    run sudo rmdir "$dir"
  done
  # With no paths, this only removes SYSTEM_DIR (and its keep list entry) if that left it empty.
  remove_system_files
  forget_across_steamos_updates charge_limit
}
