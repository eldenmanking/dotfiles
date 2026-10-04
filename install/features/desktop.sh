# TODO(andywang): add comment

feature_font() {
  if $DRY_RUN; then
    info "[dry-run] would install JetBrainsMono"
    return
  fi
  mkdir -p "$HOME/.local/share/fonts"
  (
    cd /tmp && rm -rf fonts && mkdir fonts && cd fonts
    curl -L -o "fonts.zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip" 
    unzip "fonts.zip"
    mv *.ttf "$HOME/.local/share/fonts"
  )
  rm -rf /tmp/fonts
}

feature_logiops() {
  if ! systemctl list-unit-files | grep -q "logid.service"; then
    info "Installing PixlOne/logiops..."
    run sudo pacman --needed -S cmake libevdev libconfig pkgconf
    if $DRY_RUN; then
      info "[dry-run] would build and install PixlOne/logiops from source"
    else
      (
        cd /tmp && rm -rf logiops && git clone https://github.com/PixlOne/logiops && cd logiops
        mkdir -p build
        cd build
        cmake ..
        make
        sudo make install
      )
      rm -rf /tmp/logiops
    fi
  fi

  if [[ "$(systemctl is-active logid.service 2>/dev/null || true)" != "active" ]]; then
    info "Enabling logid.service..."
    run sudo systemctl enable --now logid.service
  fi
}

feature_services() {
  run systemctl enable --now auto-suspend.timer
  run systemctl enable --now bluetooth.service
}

feature_manual() {
  confirmsed /etc/bluetooth/main.conf "#AutoEnable=false" "AutoEnable=true" sudo
}

feature_dconf() {
  local dump_file="$DOTFILES_ROOT/dump/dconf/arch.dconf"

  info "Backing up current dconf configuration..."
  run mkdir -pv "$(dirname "$BACKUPS_ROOT$dump_file")"
  if $DRY_RUN; then
    info "[dry-run] would dump dconf to $BACKUPS_ROOT$dump_file"
    info "[dry-run] would load dconf from $dump_file"
    return
  fi

  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' RETURN
  dconf dump / > "$tmp"
  cp -vi "$tmp" "$BACKUPS_ROOT$dump_file"

  dconf load / < "$dump_file"
  info "dconf configuration loaded."
}

feature_xdg() {
  info "Running xdg-user-dirs-update..."
  run xdg-user-dirs-update

  info "Setting default applications with xdg-mime..."
  run xdg-mime default okularApplication_pdf.desktop application/pdf
  run xdg-mime default org.gnome.gThumb.desktop      image/gif
  run xdg-mime default org.gnome.gThumb.desktop      image/jpeg
  run xdg-mime default org.gnome.gThumb.desktop      image/png
  run xdg-mime default org.gnome.gThumb.desktop      image/webp
  run xdg-mime default org.gnome.Totem.desktop       audio/mpeg
  run xdg-mime default org.gnome.Totem.desktop       audio/mp4
  run xdg-mime default nvim.desktop                  text/plain

  info "xdg update complete."
}

feature_info() {
  cat <<EOF

Providing dump info...
'$DOTFILES_ROOT/dump' contains exported configuration files of various applications, typically those with guis.
dconf settings can be loaded automatically by using this installer with '--dconf'. Most settings need to be imported manually.

Configurations that must be loaded manually include:
 - Insync ignorerules: Account Settings > Ignore Rules (paste ignorerules text)
 - Okular shortcuts: Settings > Configure Keyboard Shortcuts > Manage Schemes > More Actions > Import Scheme (select default.shortcuts)
Files are available in $DOTFILES_ROOT/dump/<application>

EOF
}
