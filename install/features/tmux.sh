# Feature: tmux plugin manager and plugins.

# Clone tpm, install the tmux plugins listed in the linked ~/.tmux.conf, and link the custom resurrect strategies into
# tmux-resurrect.
#
# @machine any
# @os any
# @gui any
# @requires link
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

  # .tmux.conf links them too when tmux starts, but install_plugins reads it before cloning tmux-resurrect. Only into an
  # installed plugin: tpm counts a plugin as installed once its directory exists.
  local resurrect_dir="$HOME/.tmux/plugins/tmux-resurrect" strategy
  [[ -d "$resurrect_dir" ]] || return 0
  for strategy in "$DOTFILES_ROOT"/home/.tmux/resurrect/strategies/*.sh; do
    make_symlink "$strategy" "$resurrect_dir/strategies/$(basename "$strategy")"
  done
}
