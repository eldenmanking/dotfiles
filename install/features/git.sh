# TODO(andywang): add comment

# --- Git config ---
feature_gitconfig() {
  local variant="$1" dry_run="$3" git_fsmonitor
  if ! command -v git &>/dev/null; then
    warn "git command not found, skipping git config setup."
    return
  fi

  f_with_args variant_config git_fsmonitor -- "$variant"
  git_fsmonitor="$f_arg_git_fsmonitor"

  info "Configuring global git settings..."
  run "$dry_run" git config --global core.excludesFile "$DOTFILES_ROOT/.config/git/ignore"
  if [[ "$git_fsmonitor" == true ]]; then
    run "$dry_run" git config --global core.fsmonitor true
  fi
  run "$dry_run" git config --global core.untrackedCache true
  run "$dry_run" git config --global credential.helper store
  run "$dry_run" git config --global feature.manyFiles true
  run "$dry_run" git config --global fetch.prune true
  run "$dry_run" git config --global pull.rebase false
  run "$dry_run" git config --global push.autoSetupRemote true
}
