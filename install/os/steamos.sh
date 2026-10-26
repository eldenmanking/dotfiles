# SteamOS.
os_steamos() {
  _description="SteamOS: per-user installs for the read-only rootfs"
  _platforms="steamos"
  _machines="generic framework16"
}

# SteamOS desktop (KDE and Game Mode), plus webterm.
os_steamos_desktop() {
  # distrobox is near the end since it leaves you in the new container's shell; steamos_xclip follows it to
  # reuse that container instead of downloading another image.
  _features="link neovim starship tmux claude gitconfig flatpak kde steam udev tmpfiles logind font webterm hdmi_audio_fix orei_switch gamescope_screenshot distrobox steamos_xclip"
  _gui="kde"
  _optional=""
  # Link the shell startup files rather than running the shell and zsh features. zsh plugins load from
  # /usr/share/zsh/plugins when present and are skipped otherwise.
  _link_paths="${LINK_COMMON_PATHS[*]} ${LINK_SHELL_PATHS[*]} ${LINK_STEAMOS_PATHS[*]}"
}

# SteamOS terminal setup, with the shell startup files linked.
os_steamos_minimal() {
  _features="link neovim starship tmux claude gitconfig udev tmpfiles logind hdmi_audio_fix orei_switch"
  _gui="none"
  _optional=""
  _link_paths="${LINK_COMMON_PATHS[*]} ${LINK_SHELL_PATHS[*]}"
}

# TODO(andywang): add steamos-specific features (e.g. read-only rootfs handling, pacman packages)
