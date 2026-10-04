# TODO(andywang): add comment

# --- Tmux plugins ---
feature_tmux() {
  local tpm_dir="$HOME/.tmux/plugins/tpm"

  if [[ ! -d "$tpm_dir" ]]; then
    info "Cloning tpm..."
    run git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
  else
    info "tpm already installed"
  fi

  if $DRY_RUN || [[ ! -x "$tpm_dir/bin/install_plugins" ]]; then
    return
  fi
  if ! "$tpm_dir/bin/install_plugins" 2>/dev/null; then
    warn "Plugin install failed. Open tmux and press 'prefix + I' to bootstrap plugins, then re-run this script."
  fi
}
