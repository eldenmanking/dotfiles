# Feature: copy systemd-tmpfiles configs into /etc.

# Configs are copied, not linked: systemd-tmpfiles runs at early boot, before an encrypted home is mounted.
TMPFILES_SRC="root/etc/tmpfiles.d"
TMPFILES_DST="/etc/tmpfiles.d"

# Copy changed configs (replacing any old symlink), keep them across SteamOS updates, then apply them now so no
# reboot is needed.
#
# @machine framework16
# @os linux
# @gui any
feature_tmpfiles() {
  local target changed
  f_call install_system_dir changed -- tmpfiles "$DOTFILES_ROOT/$TMPFILES_SRC" '*.conf' "$TMPFILES_DST"
  for target in $changed; do
    info "Applying $target..."
    run sudo systemd-tmpfiles --create "$target"
  done
}

# Remove the configs and stop keeping them across SteamOS updates. What they already created stays.
uninstall_feature_tmpfiles() {
  local target
  for target in $(system_file_targets "$DOTFILES_ROOT/$TMPFILES_SRC" '*.conf' "$TMPFILES_DST"); do
    [[ -e "$target" || -L "$target" ]] || continue
    remove_system_files "$target"
  done
  forget_across_steamos_updates tmpfiles
}
