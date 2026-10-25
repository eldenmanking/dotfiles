# Feature: tmux plugin manager and plugins.

# Clone tpm and install the tmux plugins listed in the linked ~/.tmux.conf, then load it once more so it can set up the
# plugins it installed.
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

  # install_plugins reads .tmux.conf before it clones the plugins, so its run-shell lines (e.g. linking the resurrect
  # strategies) ran without them. Run it again in a throwaway server on its own socket, leaving any running server
  # alone. source-file, rather than the server's own startup, finishes each run-shell before kill-server runs.
  if ! tmux -L dotfiles-install -f /dev/null \
    start-server \; source-file "$HOME/.tmux.conf" \; kill-server 2>/dev/null; then
    warn "Loading ~/.tmux.conf failed. Start tmux once to finish setting up its plugins."
  fi
}
