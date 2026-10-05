# TODO(andywang): add comment
variant_steamos() {
  f_arg_description="SteamOS (placeholder: work in progress)"
  f_arg_features="link zsh shell starship tmux gitconfig"
  f_arg_all_exclude=""
  f_arg_link_paths="${LINK_COMMON_PATHS[*]}"
  f_arg_git_fsmonitor=true
}

# TODO(andywang): add steamos-specific features (e.g. read-only rootfs handling, pacman/flatpak packages)
