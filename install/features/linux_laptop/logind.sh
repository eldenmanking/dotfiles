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
  local targets
  targets="$(system_file_targets "$DOTFILES_ROOT/$LOGIND_SRC" '*.conf' "$LOGIND_DST")"
  keep_across_steamos_updates logind $targets
  f_write_args copy_system_files _changed -- "$DOTFILES_ROOT/$LOGIND_SRC" "$LOGIND_DST" '*.conf'
  [[ -n "$_changed" ]] || return 0

  info "Reloading systemd-logind..."
  run sudo systemctl reload systemd-logind
}

# Remove the drop-ins, stop keeping them across SteamOS updates, then reload systemd-logind.
uninstall_feature_logind() {
  local target removed=false
  for target in $(system_file_targets "$DOTFILES_ROOT/$LOGIND_SRC" '*.conf' "$LOGIND_DST"); do
    [[ -e "$target" || -L "$target" ]] || continue
    remove_system_files "$target"
    removed=true
  done
  forget_across_steamos_updates logind
  $removed || return 0
  run sudo systemctl reload systemd-logind
}
