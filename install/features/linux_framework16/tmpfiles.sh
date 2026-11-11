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
  local target targets
  targets="$(system_file_targets "$DOTFILES_ROOT/$TMPFILES_SRC" '*.conf' "$TMPFILES_DST")"
  keep_across_steamos_updates tmpfiles $targets
  f_write_args copy_system_files _changed -- "$DOTFILES_ROOT/$TMPFILES_SRC" "$TMPFILES_DST" '*.conf'
  for target in $_changed; do
    info "Applying $target..."
    run sudo systemd-tmpfiles --create "$target"
  done
}
