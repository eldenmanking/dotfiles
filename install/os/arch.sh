# Arch Linux (or Arch-based).
# Usage: f_call os_arch description platforms machines
# Returns: description platforms machines
os_arch() {
  f_return description="Arch Linux (or Arch-based), with pacman and yay"
  f_return platforms="arch"
  f_return machines="generic framework16"
}

# Arch desktop with pacman/yay packages, gnome and dconf, plus webterm.
# Usage: f_call os_arch_desktop features gui optional link_paths
# Returns: features gui optional link_paths
os_arch_desktop() {
  f_return features="pacman yay terminal font printer logiops link webterm desktop udev tmpfiles logind hdmi_audio_fix manual tmux claude gitconfig dconf xdg info"
  f_return gui="gnome"
  # Optional features run only when named, not with --all. pacman + yay cover the packages --terminal would install,
  # and --printer is only needed on machines with a printer.
  f_return optional="terminal printer"
  f_return link_paths="${LINK_COMMON_PATHS[*]} ${LINK_SHELL_PATHS[*]} ${LINK_DESKTOP_PATHS[*]} ${LINK_WEBTERM_PATHS[*]}"
}

# Arch terminal setup: the terminal pacman packages, with the shell startup files linked.
# Usage: f_call os_arch_minimal features gui optional link_paths
# Returns: features gui optional link_paths
os_arch_minimal() {
  f_return features="terminal link udev tmpfiles logind hdmi_audio_fix tmux claude gitconfig"
  f_return gui="none"
  f_return optional=""
  f_return link_paths="${LINK_COMMON_PATHS[*]} ${LINK_SHELL_PATHS[*]}"
}
