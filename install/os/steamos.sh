# SteamOS.
# Usage: f_call os_steamos description platforms machines
# Returns: description platforms machines
os_steamos() {
  f_return description="SteamOS: per-user installs for the read-only rootfs"
  f_return platforms="steamos"
  f_return machines="generic framework16"
}

# The machine-specific features in these lists (an @machine other than any, e.g. orei_switch) are left out by --all on
# other machines (see machine_supported); naming one still runs it, with a warning.

# SteamOS desktop (KDE and Game Mode), plus webterm.
# Usage: f_call os_steamos_desktop features gui optional link_paths
# Returns: features gui optional link_paths
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
# Usage: f_call os_steamos_minimal features gui optional link_paths
# Returns: features gui optional link_paths
os_steamos_minimal() {
  f_return features="link neovim starship $FEATURES_TOOLS $FEATURES_SYSTEM orei_switch light_sleep"
  f_return gui="none"
  f_return optional=""
  f_return link_paths="${LINK_COMMON_PATHS[*]} ${LINK_SHELL_PATHS[*]}"
}
