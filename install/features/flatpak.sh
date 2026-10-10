# Feature: flatpak app installs from flathub (steamos).

# Flatpak app list (flathub app IDs)
FLATPAK_APPS=(
  "org.gnome.Boxes"                                             # virtual machines
  "com.google.Chrome"                                           # web browser
  "com.discordapp.Discord"                                      # social media
  "io.github.pwr_solaar.solaar"                                 # logitech pairing software
)

# Install apps per-user, so no root is needed on the read-only rootfs.
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
