# Feature: copy udev rules into /etc.

# Rules are copied, not linked: udev reads them at boot, before an encrypted home is mounted.
UDEV_RULES_SRC="root/etc/udev/rules.d"
UDEV_RULES_DST="/etc/udev/rules.d"

# Copy changed rules (replacing any old symlink), keep them across SteamOS updates, then reload udev and re-apply rules
# to i2c devices.
#
# @machine framework16
# @os linux
# @gui any
feature_udev() {
  local changed
  f_call install_system_dir changed -- udev "$DOTFILES_ROOT/$UDEV_RULES_SRC" '*.rules' "$UDEV_RULES_DST"
  [[ -n "$changed" ]] || return 0

  info "Reloading udev rules..."
  run sudo udevadm control --reload
  run sudo udevadm trigger --subsystem-match=i2c
}

# Remove the rules, stop keeping them across SteamOS updates, then reload udev.
uninstall_feature_udev() {
  local target removed=false
  for target in $(system_file_targets "$DOTFILES_ROOT/$UDEV_RULES_SRC" '*.rules' "$UDEV_RULES_DST"); do
    [[ -e "$target" || -L "$target" ]] || continue
    remove_system_files "$target"
    removed=true
  done
  forget_across_steamos_updates udev
  $removed || return 0
  run sudo udevadm control --reload
  run sudo udevadm trigger --subsystem-match=i2c
}
