# Coder workspaces.
variant_coder() {
  _description="Coder workspaces: lightweight, rootless-friendly terminal setup (formerly light-install.sh)"
  _features="binaries link zsh shell starship tmux gng tre claude gitconfig"
  _os="linux"
  _gui="none"
  _optional=""
  _link_paths="${LINK_COMMON_PATHS[*]}"
  # This is not compatible with coder
  _git_fsmonitor=false
}
