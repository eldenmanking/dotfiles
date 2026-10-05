# TODO(andywang): add comment
variant_portable() {
  f_arg_description="Portable terminal setup (e.g. Windows WSL, macOS): no package manager or root required"
  f_arg_features="binaries link zsh shell starship tmux gitconfig"
  f_arg_all_exclude=""
  f_arg_link_paths="${LINK_COMMON_PATHS[*]}"
  f_arg_git_fsmonitor=true
}
