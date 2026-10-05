# SteamOS.
variant_steamos() {
  _description="SteamOS (placeholder: work in progress)"
  _features="link zsh shell starship tmux gitconfig"
  _all_exclude=""
  _link_paths="${LINK_COMMON_PATHS[*]}"
  _git_fsmonitor=true
}

# TODO(andywang): add steamos-specific features (e.g. read-only rootfs handling, pacman/flatpak packages)
