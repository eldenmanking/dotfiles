# Arch Linux desktop.
variant_arch() {
  _description="Arch Linux (or Arch-based) desktop with pacman/yay packages, gnome and dconf"
  _features="pacman yay terminal font printer logiops link services manual tmux gitconfig dconf xdg info"
  # 'terminal' is intentionally left skipped: pacman + yay together cover
  # all packages the --terminal flag would install.
  _all_exclude="terminal"
  _link_paths="${LINK_COMMON_PATHS[*]} ${LINK_DESKTOP_PATHS[*]}"
  _git_fsmonitor=true
}
