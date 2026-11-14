# Feature: copy systemd-logind drop-ins into /etc.

# Drop-ins are copied, not linked: systemd-logind reads them at boot, before an encrypted home is mounted.
LOGIND_SRC="root/etc/systemd/logind.conf.d"
LOGIND_DST="/etc/systemd/logind.conf.d"

# Copy the systemd-logind drop-ins into /etc (needs sudo), which stop a closed lid from suspending the laptop on
# external power; changing them reloads systemd-logind, so no reboot is needed.
#
# @machine laptop
# @os linux
# @gui any
declare_logind() {
  hook_files 644 "$LOGIND_SRC" "$LOGIND_DST" '*.conf'
}
