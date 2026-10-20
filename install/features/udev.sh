# Feature: copy udev rules into /etc.

# TODO(andywang): add comment
UDEV_RULES_SRC="root/etc/udev/rules.d"
UDEV_RULES_DST="/etc/udev/rules.d"

# TODO(andywang): add comment
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
