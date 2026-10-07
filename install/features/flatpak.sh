# TODO(andywang): add comment

FLATPAK_APPS=(
  "org.gnome.Boxes"
)

feature_flatpak() {
  if ! command -v flatpak &>/dev/null; then
    warn "flatpak command not found, skipping flatpak setup."
    return
  fi

  info "Adding flathub remote..."
  run flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  info "Installing flatpak apps..."
  run_tty flatpak install --user -y flathub "${FLATPAK_APPS[@]}"
}
