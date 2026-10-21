# Feature: copy udev rules into /etc.

# Rules are copied, not linked: udev reads them at boot, before an encrypted home is mounted.
UDEV_RULES_SRC="root/etc/udev/rules.d"
UDEV_RULES_DST="/etc/udev/rules.d"

# Copy changed rules (replacing any old symlink), then reload udev and re-apply rules to i2c devices.
feature_udev() {
  f_write_args copy_system_files _changed -- "$DOTFILES_ROOT/$UDEV_RULES_SRC" "$UDEV_RULES_DST" '*.rules'
  [[ -n "$_changed" ]] || return 0

  info "Reloading udev rules..."
  run sudo udevadm control --reload
  run sudo udevadm trigger --subsystem-match=i2c
}
