# TODO(andywang): add comment

# --- Shell keybindings ---
feature_shell() {
  local all_shell_config=$(cat <<EOF
# global config
source ~/dotfiles/.config/sh/aliases.sh
source ~/dotfiles/.config/sh/env.sh
EOF
)
  local zsh_shell_config=$(cat <<EOF
# zsh config
source ~/dotfiles/.config/zsh/keybindings.zsh
source ~/dotfiles/.config/zsh/settings.zsh
EOF
)

  detect_shell_rc

  local content="$all_shell_config"
  if [[ "$SHELL_NAME" == zsh ]]; then
    content+=$'\n'"$zsh_shell_config"
  fi

  upsert_block "$RC_FILE" shell "$content"
}

# TODO(andywang): add comment
install_starship_binary() {
  local bin_dir="${1:-}"
  if command -v starship &>/dev/null; then
    info "starship already available: $(command -v starship)"
    return
  fi
  if $DRY_RUN; then
    info "[dry-run] would install starship"
    return
  fi
  curl -sS https://starship.rs/install.sh | sh -s -- -y ${bin_dir:+-b "$bin_dir"}
}

# --- Starship prompt ---
feature_starship() {
  install_starship_binary "$LOCAL_BIN"

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

  [[ -n "$content" ]] && content+=$'\n'
  content+=$(cat <<EOF
autoload -Uz compinit colors                                    # Autoload these zsh functions when called
compinit -d                                                     # Initialize zsh completion
colors                                                          # Activate color-coding for completion
EOF
)

  upsert_block "$HOME/.zshrc" zsh_plugins "$content"
}
