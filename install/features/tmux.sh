# Feature: tmux plugin manager and plugins.

# --- Tmux plugins ---
feature_tmux() {
  local dry_run="$3"
  local tpm_dir="$HOME/.tmux/plugins/tpm"

  if [[ ! -d "$tpm_dir" ]]; then
    info "Cloning tpm..."
    run "$dry_run" git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
  else
    info "tpm already installed"
  fi

  if $dry_run || [[ ! -x "$tpm_dir/bin/install_plugins" ]]; then
    return
  fi
  if ! "$tpm_dir/bin/install_plugins" 2>/dev/null; then
    warn "Plugin install failed. Open tmux and press 'prefix + I' to bootstrap plugins, then re-run this script."
  fi
}
