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
