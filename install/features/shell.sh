# Features: shell startup file blocks, starship prompt and zsh plugins.

# Write managed blocks into the profiles, .bashrc and .zshrc that source the shared config in home/.config/sh
# and home/.config/zsh.
#
# @machine any
# @os any
# @gui any
feature_shell() {
  local sh_files=(home/.config/sh/env.sh home/.config/sh/aliases.sh)
  local zsh_files=(home/.config/zsh/keybindings.zsh home/.config/zsh/settings.zsh home/.config/zsh/external.zsh)

  # Login shells load the environment from a profile; bash ignores ~/.profile when ~/.bash_profile exists.
  upsert_sources "$HOME/.profile" shell home/.config/sh/env.sh
  upsert_sources "$HOME/.zprofile" shell home/.config/sh/env.sh
  if [[ -f "$HOME/.bash_profile" ]]; then
    upsert_sources "$HOME/.bash_profile" shell home/.config/sh/env.sh
  fi

  # rc files source env.sh too, for shells with no login shell above them. Write both rc files so switching shells
  # keeps the config.
  upsert_sources "$HOME/.bashrc" shell "${sh_files[@]}"
  upsert_sources "$HOME/.zshrc" shell "${sh_files[@]}" "${zsh_files[@]}"
}

# Install starship if missing, optionally into bin_dir.
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

# Install starship to ~/.local/bin if missing and start it from .bashrc and .zshrc.
#
# @machine any
# @os any
# @gui any
feature_starship() {
  install_starship_binary "$LOCAL_BIN"

  upsert_sources "$HOME/.bashrc" starship home/.config/sh/starship.sh
  upsert_sources "$HOME/.zshrc" starship home/.config/sh/starship.sh
}

# Clone popular zsh plugins into ~/.zsh/plugins and source plugins.zsh (which loads them) from .zshrc. Portable:
# no package manager or root required.
#
# @machine any
# @os any
# @gui any
feature_zsh() {
  local plugins_dir="$HOME/.zsh/plugins"

  # Keep in sync with the plugin list in home/.config/zsh/plugins.zsh.
  local repos=(
    zsh-users/zsh-autosuggestions
    zsh-users/zsh-syntax-highlighting
    zsh-users/zsh-history-substring-search
  )

  mkdir -p "$plugins_dir"

  local repo name
  for repo in "${repos[@]}"; do
    name="${repo##*/}"
    if [[ -d "$plugins_dir/$name" ]]; then
      info "zsh plugin already cloned: $name"
    else
      info "Cloning $name..."
      git clone --depth 1 "https://github.com/$repo" "$plugins_dir/$name"
    fi
  done

  upsert_sources "$HOME/.zshrc" zsh home/.config/zsh/plugins.zsh
}
