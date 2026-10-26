# Arch Linux (or Arch-based).
os_arch() {
  _description="Arch Linux (or Arch-based), with pacman and yay"
  _platforms="arch"
  _machines="generic framework16"
}

# Arch desktop with pacman/yay packages, gnome and dconf.
os_arch_desktop() {
  _features="pacman yay terminal font printer logiops link services udev tmpfiles hdmi_audio_fix manual tmux claude gitconfig dconf xdg info"
  _gui="gnome"
  # Optional features run only when named, not with --all. pacman + yay cover the packages --terminal would install,
  # and --printer is only needed on machines with a printer.
  _optional="terminal printer"
  _link_paths="${LINK_COMMON_PATHS[*]} ${LINK_SHELL_PATHS[*]} ${LINK_DESKTOP_PATHS[*]}"
}

# Arch terminal setup: the terminal pacman packages, with the shell startup files linked.
os_arch_minimal() {
  _features="terminal link udev tmpfiles hdmi_audio_fix tmux claude gitconfig"
  _gui="none"
  _optional=""
  _link_paths="${LINK_COMMON_PATHS[*]} ${LINK_SHELL_PATHS[*]}"
}
