# Feature: copy the console keymap and keyboard module options into place.

# Files read at boot or in the initramfs are copied, not linked: an encrypted home isn't mounted yet.
CONSOLE_KEYMAP="root/usr/share/kbd/keymaps/us-caps.map"
CONSOLE_MODPROBE="root/etc/modprobe.d/hid_apple.conf"
CONSOLE_VCONSOLE="root/etc/vconsole.conf"

# Copy the us-caps console keymap and the hid_apple module option, and root/etc/vconsole.conf (which selects the
# keymap) only where there is none or it is a link from an older install: one that is there already may hold the
# keymap chosen when installing Arch, which this leaves alone.
#
# @machine any
# @os arch
# @gui any
feature_console() {
  copy_system_file 644 "$CONSOLE_KEYMAP"
  copy_system_file 644 "$CONSOLE_MODPROBE"
  if [[ ! -e /etc/vconsole.conf || -L /etc/vconsole.conf ]]; then
    copy_system_file 644 "$CONSOLE_VCONSOLE"
  elif ! cmp -s "$DOTFILES_ROOT/$CONSOLE_VCONSOLE" /etc/vconsole.conf; then
    info "Keeping /etc/vconsole.conf; set KEYMAP=us-caps there to use the keymap in the console"
  fi
}

# Remove the keymap and the module option, and vconsole.conf only if it is still the repo's.
uninstall_feature_console() {
  local file
  for file in "$CONSOLE_KEYMAP" "$CONSOLE_MODPROBE"; do
    remove_system_files "/${file#root/}"
  done
  if [[ ! -L /etc/vconsole.conf ]] && cmp -s "$DOTFILES_ROOT/$CONSOLE_VCONSOLE" /etc/vconsole.conf; then
    remove_system_files /etc/vconsole.conf
  fi
}
