# Arch Linux desktop.
variant_arch() {
  _description="Arch Linux (or Arch-based) desktop with pacman/yay packages, gnome and dconf"
  _features="pacman yay terminal font printer logiops link services manual tmux claude gitconfig dconf xdg info"
  # Optional features run only when named, not with --all. pacman + yay cover the packages --terminal would install,
  # and --printer is only needed on machines with a printer.
  _optional="terminal printer"
  _link_paths="${LINK_COMMON_PATHS[*]} ${LINK_SHELL_PATHS[*]} ${LINK_DESKTOP_PATHS[*]}"
  _git_fsmonitor=true
}
