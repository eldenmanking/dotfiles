# Feature: copy udev rules into /etc.

# Rules are copied, not linked: udev reads them at boot, before an encrypted home is mounted.
UDEV_RULES_SRC="root/etc/udev/rules.d"
UDEV_RULES_DST="/etc/udev/rules.d"

# Copy the udev rules into /etc (needs sudo), which reloads udev, then re-apply rules to i2c devices.
#
# @machine framework16
# @os linux
# @gui any
declare_udev() {
  hook_files 644 "$UDEV_RULES_SRC" "$UDEV_RULES_DST" '*.rules'
}

# Re-apply the rules to i2c devices if any changed.
# Usage: post_udev <os> <profile> <enabled> <changed>
post_udev() {
  local changed="$4"
  [[ -n "$changed" ]] || return 0
  run sudo udevadm trigger --subsystem-match=i2c
}
