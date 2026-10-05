# TODO(andywang): add comment

feature_link() {
  local dotfile rel target user src
  while IFS= read -r -d '' dotfile; do
    if should_exclude "$dotfile"; then
      continue
    fi

    rel="${dotfile#./}"
    if [[ "$rel" == root/* ]]; then
      target="/${rel#root/}"
      user="sudo"
    else
      target="$HOME/$rel"
      user=""
    fi
    src="$DOTFILES_ROOT/$rel"
    make_symlink "$src" "$target" "$user"
  done < <(find . -type f -print0)
}

# --- Link configs ---
feature_link_config() {
  local paths=(
    .tmux.conf
    .tmux/resurrect/saferestore.sh
    .config/nvim/core/autocommands.vim
    .config/nvim/core/commands.vim
    .config/nvim/core/filetypes.vim
    .config/nvim/core/mappings.vim
    .config/nvim/core/options.vim
    .config/nvim/core/plugins.vim
    .config/nvim/core/plugmaps.vim
    .config/nvim/init.vim
    .config/starship.toml
  )

  for rel in "${paths[@]}"; do
    make_symlink "$DOTFILES_ROOT/$rel" "$HOME/$rel"
  done
}

# --- Link executables ---
feature_link_bin() {
  local paths=(
    .local/bin/vis
    .local/bin/clip
    .local/bin/vm-usb
  )

  for rel in "${paths[@]}"; do
    make_symlink "$DOTFILES_ROOT/$rel" "$HOME/$rel"
  done
}
