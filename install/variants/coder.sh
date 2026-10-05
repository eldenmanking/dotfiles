# TODO(andywang): add comment
variant_coder() {
  f_arg_description="Coder workspaces: lightweight, rootless-friendly terminal setup (formerly light-install.sh)"
  f_arg_features="binaries link zsh shell starship tmux gng tre claude gitconfig"
  f_arg_all_exclude=""
  f_arg_link_paths="${LINK_COMMON_PATHS[*]}"
  # This is not compatible with coder
  f_arg_git_fsmonitor=false
}
