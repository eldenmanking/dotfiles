# Feature: symlink dotfiles into place.

# Paths linked by every variant. Directories link every file under them.
LINK_COMMON_PATHS=(
  .tmux.conf
  .tmux/resurrect/saferestore.sh
  .config/nvim
  .config/starship.toml
  .local/bin/vis
  .local/bin/clip
)

# Extra paths linked on full desktop installs (e.g. arch).
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

# Link one repo-relative file: root/* goes to /, everything else to $HOME.
link_dotfile() {
  local rel="$1"
  if [[ "$rel" == root/* ]]; then
    make_symlink "$DOTFILES_ROOT/$rel" "/${rel#root/}" sudo
  else
    make_symlink "$DOTFILES_ROOT/$rel" "$HOME/$rel"
  fi
}

feature_link() {
  local variant="$1" link_paths entry file
  f_with_args variant_config link_paths -- "$variant"
  link_paths="$_link_paths"
  for entry in $link_paths; do
    if [[ ! -e "$DOTFILES_ROOT/$entry" ]]; then
      warn "Source does not exist, skipping: $DOTFILES_ROOT/$entry"
      continue
    fi
    while IFS= read -r -d '' file; do
      link_dotfile "${file#./}"
    done < <(cd "$DOTFILES_ROOT" && find "./$entry" -type f -print0)
  done
}
