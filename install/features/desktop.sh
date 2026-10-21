# Features: desktop setup (fonts, logiops, services, dconf, xdg).

# JetBrainsMono Nerd Font, checked against a pinned SHA-256. Fonts in ~/.local/share/fonts are also seen by browsers
# (including flatpak ones), which webterm relies on.
FONT_NF_VERSION=v3.4.0
FONT_SHA256=ef552a3e638f25125c6ad4c51176a6adcdce295ab1d2ffacf0db060caf8c1582
FONT_FAMILY="JetBrainsMono Nerd Font Mono"
FONT_DEST="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
FONT_STAMP="$FONT_DEST/.version"

# True when FONT_DEST holds exactly the pinned release.
font_up_to_date() {
  [[ -f "$FONT_STAMP" && "$(cat "$FONT_STAMP")" == "$FONT_NF_VERSION $FONT_SHA256" ]]
}

# True when the family comes from somewhere else (e.g. a system package), which we leave alone.
font_installed_elsewhere() {
  [[ ! -d "$FONT_DEST" ]] && command -v fc-list >/dev/null && fc-list : family | grep -qF "$FONT_FAMILY"
}

feature_font() {
  if font_up_to_date; then
    info "$FONT_FAMILY $FONT_NF_VERSION already installed"
    return
  fi
  if font_installed_elsewhere; then
    info "$FONT_FAMILY already installed outside $FONT_DEST"
    return
  fi
  require_commands curl sha256sum tar xz

  info "Downloading JetBrainsMono Nerd Font $FONT_NF_VERSION"
  local tmp
  tmp="$(mktemp -d)"
  download_verified \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/$FONT_NF_VERSION/JetBrainsMono.tar.xz" \
    "$FONT_SHA256" "$tmp/font.tar.xz" font \
    || { rm -rf "$tmp"; error "could not download the font"; }
  # Start clean so files dropped by a newer release don't linger.
  run rm -rf "$FONT_DEST"
  run mkdir -p "$FONT_DEST"
  run tar -xJf "$tmp/font.tar.xz" -C "$FONT_DEST" --wildcards '*.ttf' OFL.txt
  if command -v fc-cache >/dev/null; then run fc-cache -f "$FONT_DEST"; fi
  $DRY_RUN || printf '%s\n' "$FONT_NF_VERSION $FONT_SHA256" > "$FONT_STAMP"
  rm -rf "$tmp"
  info "Installed $FONT_FAMILY to $FONT_DEST (restart the browser if it was open)"
}

feature_logiops() {
  if ! systemctl list-unit-files | grep -q "logid.service"; then
    info "Installing PixlOne/logiops..."
    run sudo pacman --needed -S cmake libevdev libconfig pkgconf
    if $DRY_RUN; then
      info "[dry-run] would build and install PixlOne/logiops from source"
    else
      (
        cd /tmp && rm -rf logiops && git clone https://github.com/PixlOne/logiops && cd logiops || exit
        mkdir -p build
        cd build || exit
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
