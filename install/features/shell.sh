# TODO(andywang): add comment

# --- Shell keybindings ---
feature_shell() {
  local aliases_line="source ~/dotfiles/.config/sh/aliases.sh"
  local keybindings_line="source ~/dotfiles/.config/zsh/keybindings.zsh"

  detect_shell_rc

  # Aliases apply to every shell; keybindings.zsh is zsh-only. Both live in a
  # single managed block.
  local content="$aliases_line"
  if [[ "$SHELL_NAME" == zsh ]]; then
    content+=$'\n'"$keybindings_line"
  fi

  upsert_block "$RC_FILE" shell "$content"
}

# TODO(andywang): add comment
install_starship_binary() {
  if command -v starship &>/dev/null; then
    info "starship already available: $(command -v starship)"
    return
  fi
  if $DRY_RUN; then
    info "[dry-run] would install starship"
    return
  fi
  curl -sS https://starship.rs/install.sh | sh -s -- -y
}

# --- Starship prompt ---
feature_starship() {
  install_starship_binary

  detect_shell_rc
  upsert_block "$RC_FILE" starship "eval \"\$(starship init $SHELL_NAME)\""
}

# --- Zsh plugins ---
# Clone popular zsh plugins into ~/.zsh/plugins and source them from .zshrc.
# Portable: no package manager or root required. Safe to re-run.
feature_zsh() {
  local plugins_dir="$HOME/.zsh/plugins"

  # Each repo's main script shares the repo's basename (e.g. zsh-autosuggestions.zsh).
  # Order matters: syntax-highlighting must precede history-substring-search.
  local repos=(
    zsh-users/zsh-autosuggestions
    zsh-users/zsh-syntax-highlighting
    zsh-users/zsh-history-substring-search
  )

  mkdir -p "$plugins_dir"

  local content="" repo name
  for repo in "${repos[@]}"; do
    name="${repo##*/}"
    if [[ -d "$plugins_dir/$name" ]]; then
      info "zsh plugin already cloned: $name"
    else
      info "Cloning $name..."
      git clone --depth 1 "https://github.com/$repo" "$plugins_dir/$name"
    fi
    [[ -n "$content" ]] && content+=$'\n'
    content+="source ~/.zsh/plugins/$name/$name.zsh"
  done

  upsert_block "$HOME/.zshrc" zsh_plugins "$content"
}
