# Arch Linux (or Arch-based).
# Usage: f_call os_arch description platforms machines
# Returns: description platforms machines
os_arch() {
  f_return description="Arch Linux (or Arch-based), with pacman and yay"
  f_return platforms="arch"
  f_return machines="generic framework16"
}

# The machine-specific features in these lists (an @machine other than any, e.g. udev) are left out by --all
# on other machines (see machine_supported); naming one still runs it, with a warning.

# Arch desktop with pacman/yay packages, gnome and dconf, plus webterm.
# Usage: f_call os_arch_desktop features gui optional link_paths
# Returns: features gui optional link_paths
os_arch_desktop() {
  f_return features="pacman yay terminal font printer logiops link webterm desktop $FEATURES_SYSTEM manual $FEATURES_TOOLS dconf xdg info"
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
  f_return features="terminal link $FEATURES_SYSTEM $FEATURES_TOOLS"
  f_return gui="none"
  f_return optional=""
  f_return link_paths="${LINK_COMMON_PATHS[*]} ${LINK_SHELL_PATHS[*]}"
}
