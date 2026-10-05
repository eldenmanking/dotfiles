# TODO(andywang): add comment
variant_portable() {
  _description="Portable terminal setup (e.g. Windows WSL, macOS): no package manager or root required"
  _features="binaries link zsh shell starship tmux gitconfig"
  _all_exclude=""
  _link_paths="${LINK_COMMON_PATHS[*]}"
  _git_fsmonitor=true
}
