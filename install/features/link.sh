# TODO(andywang): add comment

# TODO(andywang): add comment
LINK_COMMON_PATHS=(
  .tmux.conf
  .tmux/resurrect/saferestore.sh
  .config/nvim
  .config/starship.toml
  .local/bin/vis
  .local/bin/clip
)

# TODO(andywang): add comment
LINK_DESKTOP_PATHS=(
  .bash_profile
  .bashrc
  .profile
  .zprofile
  .zshrc
  .p10k.zsh
  .vimrc
  .ideavimrc
  .ocamlformat
  .pylintrc
  .claude/commands
  .claude/scripts
  .config/alacritty
  .config/git
  .config/lvim
  .config/sh
  .config/yapf
  .config/zsh
  .local/bin/squidpdf
  .local/share
  root/etc
  root/usr
)

# TODO(andywang): add comment
link_dotfile() {
  local dry_run="$1" rel="$2"
  if [[ "$rel" == root/* ]]; then
    make_symlink "$dry_run" "$DOTFILES_ROOT/$rel" "/${rel#root/}" sudo
  else
    make_symlink "$dry_run" "$DOTFILES_ROOT/$rel" "$HOME/$rel"
  fi
}

feature_link() {
  local variant="$1" dry_run="$3" link_paths entry file
  f_with_args variant_config link_paths -- "$variant"
  link_paths="$f_arg_link_paths"
  for entry in $link_paths; do
    if [[ ! -e "$DOTFILES_ROOT/$entry" ]]; then
      warn "Source does not exist, skipping: $DOTFILES_ROOT/$entry"
      continue
    fi
    while IFS= read -r -d '' file; do
      link_dotfile "$dry_run" "${file#./}"
    done < <(cd "$DOTFILES_ROOT" && find "./$entry" -type f -print0)
  done
}
