# TODO(andywang): add comment

# Install yay if it's not already on the system.
ensure_yay() {
  local dry_run="$1"
  if command -v yay &>/dev/null; then
    return
  fi
  info "Installing yay..."
  run "$dry_run" sudo pacman --needed -S git base-devel
  if $dry_run; then
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
  local dry_run="$3"
  info "Installing pacman packages for terminal..."
  run_tty "$dry_run" sudo pacman --needed -Sq "${TERMINAL_PACMAN[@]}"
  info "Installing pacman packages for gnome..."
  run_tty "$dry_run" sudo pacman --needed -Sq "${GNOME_PACMAN[@]}"
  info "Installing pacman packages for latex..."
  run_tty "$dry_run" sudo pacman --needed -Sq "${LATEX_PACMAN[@]}"
}

feature_yay() {
  local dry_run="$3"
  ensure_yay "$dry_run"
  if [[ ${#TERMINAL_YAY[@]} -gt 0 ]]; then
    info "Installing yay packages for terminal..."
    run_tty "$dry_run" yay --answerclean None --answerdiff None --needed -Sq "${TERMINAL_YAY[@]}"
  fi
  info "Installing yay packages for gnome..."
  run_tty "$dry_run" yay --answerclean None --answerdiff None --needed -Sq "${GNOME_YAY[@]}"
}

# Install only the terminal subset of packages. Skips work already covered by
# feature_pacman / feature_yay when those flags were also given.
feature_terminal() {
  local enabled="$2" dry_run="$3"
  if ! list_contains "$enabled" pacman; then
    info "Installing pacman packages for terminal..."
    run_tty "$dry_run" sudo pacman --needed -Sq "${TERMINAL_PACMAN[@]}"
  fi
  if ! list_contains "$enabled" yay && [[ ${#TERMINAL_YAY[@]} -gt 0 ]]; then
    ensure_yay "$dry_run"
    info "Installing yay packages for terminal..."
    run_tty "$dry_run" yay --answerclean None --answerdiff None --needed -Sq "${TERMINAL_YAY[@]}"
  fi

  install_starship_binary "$dry_run"
}

feature_printer() {
  local dry_run="$3"
  info "Installing pacman packages for printer..."
  run_tty "$dry_run" sudo pacman --needed -Sq "${PRINTER_PACMAN[@]}"
  run "$dry_run" sudo systemctl enable --now cups
  info "Note: to install HP printer drivers, use 'hp-setup -i'."
}
