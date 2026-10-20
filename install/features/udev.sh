# Feature: copy udev rules into /etc.

# Rules are copied, not linked: udev reads them at boot, before an encrypted home is mounted.
UDEV_RULES_SRC="root/etc/udev/rules.d"
UDEV_RULES_DST="/etc/udev/rules.d"

# Copy changed rules (replacing any old symlink), then reload udev and re-apply rules to i2c devices.
feature_udev() {
  local file target changed=false
  for file in "$DOTFILES_ROOT/$UDEV_RULES_SRC"/*.rules; do
    [[ -e "$file" ]] || continue
    target="$UDEV_RULES_DST/$(basename "$file")"
    if [[ ! -L "$target" ]] && cmp -s "$file" "$target"; then
      info "$target already up to date"
      continue
    fi
    info "Copying $file to $target..."
    run sudo rm -f "$target"
    run sudo install -Dvm 644 "$file" "$target"
    changed=true
  done
  $changed || return 0

  info "Reloading udev rules..."
  run sudo udevadm control --reload
  run sudo udevadm trigger --subsystem-match=i2c
}
