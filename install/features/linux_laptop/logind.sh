# Feature: copy systemd-logind drop-ins into /etc.

# Drop-ins are copied, not linked: systemd-logind reads them at boot, before an encrypted home is mounted.
LOGIND_SRC="root/etc/systemd/logind.conf.d"
LOGIND_DST="/etc/systemd/logind.conf.d"

# Copy changed drop-ins (replacing any old symlink), which stop a closed lid from suspending the laptop on external
# power, keep them across SteamOS updates, then reload systemd-logind so no reboot is needed.
#
# @machine laptop
# @os linux
# @gui any
feature_logind() {
  local changed
  f_call install_system_dir changed -- logind "$DOTFILES_ROOT/$LOGIND_SRC" '*.conf' "$LOGIND_DST"
  [[ -n "$changed" ]] || return 0

  info "Reloading systemd-logind..."
  run sudo systemctl reload systemd-logind
}

# Remove the drop-ins, stop keeping them across SteamOS updates, then reload systemd-logind.
uninstall_feature_logind() {
  local removed
  f_call uninstall_system_dir removed -- logind "$DOTFILES_ROOT/$LOGIND_SRC" '*.conf' "$LOGIND_DST"
  [[ -n "$removed" ]] || return 0
  run sudo systemctl reload systemd-logind
}
