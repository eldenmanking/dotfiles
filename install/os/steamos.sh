# SteamOS.
os_steamos() {
  f_return description="SteamOS: per-user installs for the read-only rootfs"
  f_return platforms="steamos"
  f_return machines="generic framework16"
}

# SteamOS desktop (KDE and Game Mode), plus webterm.
os_steamos_desktop() {
  # distrobox is near the end since it leaves you in the new container's shell; steamos_xclip and
  # steamos_make follow it to reuse that container instead of downloading another image.
  f_return features="link neovim starship tmux claude gitconfig flatpak kde steam udev tmpfiles logind font webterm hdmi_audio_fix orei_switch light_sleep gamescope_screenshot distrobox steamos_xclip steamos_make steamos_arch_vm steamos_vm"
  f_return gui="kde"
  f_return optional="steamos_arch_vm steamos_vm"
  # Link the shell startup files rather than running the shell and zsh features. zsh plugins load from
  # /usr/share/zsh/plugins when present and are skipped otherwise.
  f_return link_paths="${LINK_COMMON_PATHS[*]} ${LINK_SHELL_PATHS[*]} ${LINK_STEAMOS_PATHS[*]} ${LINK_WEBTERM_PATHS[*]}"
}

# SteamOS terminal setup, with the shell startup files linked.
os_steamos_minimal() {
  f_return features="link neovim starship tmux claude gitconfig udev tmpfiles logind hdmi_audio_fix orei_switch light_sleep"
  f_return gui="none"
  f_return optional=""
  f_return link_paths="${LINK_COMMON_PATHS[*]} ${LINK_SHELL_PATHS[*]}"
}

# TODO(andywang): add steamos-specific features (e.g. read-only rootfs handling, pacman packages)
