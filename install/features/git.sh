# Feature: global git config.

# Set global git defaults (excludes file, pull, push and fetch behavior, credential store).
#
# @machine any
# @os any
# @gui any
feature_gitconfig() {
  local os="$1" profile="$2" git_fsmonitor
  if ! command -v git &>/dev/null; then
    warn "git command not found, skipping git config setup."
    return
  fi

  f_call os_profile_config git_fsmonitor -- "$os" "$profile"

  info "Configuring global git settings..."
  run git config --global core.excludesFile "$DOTFILES_ROOT/home/.config/git/ignore"
  if [[ "$git_fsmonitor" == true ]]; then
    run git config --global core.fsmonitor true
  fi
  run git config --global core.untrackedCache true
  # Deliberate: "store" keeps tokens in plaintext in ~/.git-credentials, chosen over a keyring helper so it works
  # the same on headless, SteamOS and macOS machines. Keep the home directory private (or encrypted).
  run git config --global credential.helper store
  run git config --global feature.manyFiles true
  run git config --global fetch.prune true
  run git config --global pull.rebase false
  run git config --global push.autoSetupRemote true
}
