# SteamOS.
variant_steamos() {
  _description="SteamOS: per-user installs for the read-only rootfs, plus webterm"
  # distrobox is last since it leaves you in the new container's shell.
  _features="link neovim starship tmux claude gitconfig steamos_xclip flatpak udev tmpfiles font webterm home_units distrobox"
  _all_exclude=""
  # Link the shell startup files rather than running the shell and zsh features. zsh plugins load from
  # /usr/share/zsh/plugins when present and are skipped otherwise.
  _link_paths="${LINK_COMMON_PATHS[*]} ${LINK_SHELL_PATHS[*]} ${LINK_STEAMOS_PATHS[*]}"
  _git_fsmonitor=true
}

# TODO(andywang): add steamos-specific features (e.g. read-only rootfs handling, pacman packages)
# TODO(andywang): udev and tmpfiles are Framework 16 fixes, not SteamOS ones. Consider composing variants
# (--variant steamos,framework) or a separate machine layer (--machine framework16) that only adds features and paths.
