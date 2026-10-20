# SteamOS.
variant_steamos() {
  _description="SteamOS (placeholder: work in progress)"
  _features="link starship tmux gitconfig steamos_xclip flatpak udev"
  _all_exclude=""
  # Link the shell startup files rather than running the shell and zsh features. zsh plugins load from
  # /usr/share/zsh/plugins when present and are skipped otherwise.
  _link_paths="${LINK_COMMON_PATHS[*]} ${LINK_SHELL_PATHS[*]}"
  _git_fsmonitor=true
}

# TODO(andywang): add steamos-specific features (e.g. read-only rootfs handling, pacman packages)
