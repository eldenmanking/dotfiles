# TODO(andywang): add comment

# Install yay if it's not already on the system.
ensure_yay() {
  if command -v yay &>/dev/null; then
    return
  fi
  info "Installing yay..."
  run sudo pacman --needed -S git base-devel
  if $DRY_RUN; then
    info "[dry-run] would clone and build yay from AUR"
    return
  fi
  (
    cd /tmp
    rm -rf yay
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si
  )
  rm -rf /tmp/yay
}

feature_pacman() {
  info "Installing pacman packages for terminal..."
  run_tty sudo pacman --needed -Sq "${TERMINAL_PACMAN[@]}"
  info "Installing pacman packages for gnome..."
  run_tty sudo pacman --needed -Sq "${GNOME_PACMAN[@]}"
  info "Installing pacman packages for latex..."
  run_tty sudo pacman --needed -Sq "${LATEX_PACMAN[@]}"
}

feature_yay() {
  ensure_yay
  if [[ ${#TERMINAL_YAY[@]} -gt 0 ]]; then
    info "Installing yay packages for terminal..."
    run_tty yay --answerclean None --answerdiff None --needed -Sq "${TERMINAL_YAY[@]}"
  fi
  info "Installing yay packages for gnome..."
  run_tty yay --answerclean None --answerdiff None --needed -Sq "${GNOME_YAY[@]}"
}

# Install only the terminal subset of packages. Skips work already covered by
# feature_pacman / feature_yay when those flags were also given.
feature_terminal() {
  local enabled="$2"
  if ! list_contains "$enabled" pacman; then
    info "Installing pacman packages for terminal..."
    run_tty sudo pacman --needed -Sq "${TERMINAL_PACMAN[@]}"
  fi
  if ! list_contains "$enabled" yay && [[ ${#TERMINAL_YAY[@]} -gt 0 ]]; then
    ensure_yay
    info "Installing yay packages for terminal..."
    run_tty yay --answerclean None --answerdiff None --needed -Sq "${TERMINAL_YAY[@]}"
  fi

  install_starship_binary
}

feature_printer() {
  info "Installing pacman packages for printer..."
  run_tty sudo pacman --needed -Sq "${PRINTER_PACMAN[@]}"
  run sudo systemctl enable --now cups
  info "Note: to install HP printer drivers, use 'hp-setup -i'."
}
