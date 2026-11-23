# Feature: copy systemd-tmpfiles configs into /etc.

# Configs are copied, not linked: systemd-tmpfiles runs at early boot, before an encrypted home is mounted.
TMPFILES_SRC="root/etc/tmpfiles.d"
TMPFILES_DST="/etc/tmpfiles.d"

# Copy the systemd-tmpfiles configs into /etc (needs sudo), which applies the changed ones so no reboot is needed.
#
# @machine framework16
# @os linux
# @gui any
declare_tmpfiles() {
  hook_files 644 "$TMPFILES_SRC" "$TMPFILES_DST" '*.conf'
}
