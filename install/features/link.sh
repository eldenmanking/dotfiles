# Feature: symlink dotfiles into place.

# Paths linked by every variant. Directories link every file under them.
LINK_COMMON_PATHS=(
  home/.tmux.conf
  home/.tmux/resurrect/saferestore.sh
  home/.config/nvim
  home/.config/starship.toml
  home/.local/bin/vis
  home/.local/bin/clip
)

# Shell startup files, for variants that link them instead of writing managed blocks with the shell feature.
LINK_SHELL_PATHS=(
  home/.bash_profile
  home/.bashrc
  home/.profile
  home/.zprofile
  home/.zshrc
)

# Extra paths linked on steamos.
LINK_STEAMOS_PATHS=(
  home/.config/webterm
)

# Extra paths linked on full desktop installs (e.g. arch).
LINK_DESKTOP_PATHS=(
  home/.vimrc
  home/.ideavimrc
  home/.ocamlformat
  home/.pylintrc
  home/.config/alacritty
  home/.config/git
  home/.config/sh
  home/.config/yapf
  home/.config/zsh
  home/.local/bin/squidpdf
  home/.local/bin/vm-usb
  home/.local/share
  root/etc
  root/usr
)

# Link one repo-relative file: root/* goes to / and home/* to $HOME.
link_dotfile() {
  local rel="$1"
  case "$rel" in
    root/*) make_symlink "$DOTFILES_ROOT/$rel" "/${rel#root/}" sudo ;;
    home/*) make_symlink "$DOTFILES_ROOT/$rel" "$HOME/${rel#home/}" ;;
    *) warn "Not under root/ or home/, skipping: $rel" ;;
  esac
}

# Symlink the variant's _link_paths: home/ into $HOME and root/ into / (with sudo).
#
# @machine any
# @os any
# @gui any
feature_link() {
  local variant="$1" link_paths entry file
  f_write_args variant_config _link_paths -- "$variant"
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
