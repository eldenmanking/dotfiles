# SteamOS.
variant_steamos() {
  _description="SteamOS: per-user installs for the read-only rootfs, plus webterm"
  _features="link zsh shell starship tmux gitconfig steamos_xclip flatpak udev font webterm home_units"
  _all_exclude=""
  _link_paths="${LINK_COMMON_PATHS[*]}"
  _git_fsmonitor=true
}

# TODO(andywang): add steamos-specific features (e.g. read-only rootfs handling, pacman packages)
