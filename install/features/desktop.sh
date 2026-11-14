# Features: desktop setup (fonts, logiops, desktop system units, xdg). The desktop settings (dconf) are in
# linux_gnome/desktop_settings.sh.

# JetBrainsMono Nerd Font, checked against a pinned SHA-256. Fonts in ~/.local/share/fonts are also seen by browsers
# (including flatpak ones), which webterm relies on.
FONT_NF_VERSION=v3.4.0
FONT_SHA256=ef552a3e638f25125c6ad4c51176a6adcdce295ab1d2ffacf0db060caf8c1582
FONT_FAMILY="JetBrainsMono Nerd Font Mono"
FONT_DEST="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
FONT_STAMP="$FONT_DEST/.version"

# True when FONT_DEST holds exactly the pinned release.
# Usage: font_up_to_date
font_up_to_date() {
  [[ -f "$FONT_STAMP" && "$(cat "$FONT_STAMP")" == "$FONT_NF_VERSION $FONT_SHA256" ]]
}

# True when the family comes from somewhere else (e.g. a system package), which we leave alone.
# Usage: font_installed_elsewhere
font_installed_elsewhere() {
  local families
  [[ ! -d "$FONT_DEST" ]] && command -v fc-list >/dev/null || return 1
  families="$(fc-list : family)"
  [[ "$families" == *"$FONT_FAMILY"* ]]
}

# Install the pinned JetBrainsMono Nerd Font to ~/.local/share/fonts, unless it is already installed elsewhere.
#
# @machine any
# @os linux
# @gui any
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
  with_tmpdir _install_font_in
  info "Installed $FONT_FAMILY to $FONT_DEST (restart the browser if it was open)"
}

# Download the verified font into the temp dir $1 and unpack it into FONT_DEST.
# Usage: _install_font_in <tmp>
_install_font_in() {
  local tmp="$1"
  download_verified \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/$FONT_NF_VERSION/JetBrainsMono.tar.xz" \
    "$FONT_SHA256" "$tmp/font.tar.xz" font \
    || { error "could not download the font"; }
  # Extract aside and swap in, so a failed extract keeps the old fonts and files dropped by a newer release don't linger.
  run mkdir -p "$tmp/new"
  run tar -xJf "$tmp/font.tar.xz" -C "$tmp/new" --wildcards '*.ttf' OFL.txt \
    || { error "could not extract the font"; }
  run rm -rf "$FONT_DEST"
  run mkdir -p "$(dirname "$FONT_DEST")"
  run mv "$tmp/new" "$FONT_DEST"
  if command -v fc-cache >/dev/null; then run fc-cache -f "$FONT_DEST"; fi
  $DRY_RUN || printf '%s\n' "$FONT_NF_VERSION $FONT_SHA256" > "$FONT_STAMP"
}

LOGIOPS_VERSION=v0.3.5
LOGIOPS_COMMIT=628ab937a25724c1f21e7edf25c8e5aaff82c691

# Build and install logiops from a pinned commit cloned into the temp dir $1.
# Usage: _build_logiops_in <tmp>
_build_logiops_in() {
  local tmp="$1"
  clone_pinned https://github.com/PixlOne/logiops "$LOGIOPS_COMMIT" "$tmp/logiops"
  (
    cd "$tmp/logiops" || exit
    mkdir -p build
    cd build || exit
    cmake ..
    make
    sudo make install
  )
}

# Build logiops (Logitech mouse and keyboard daemon) from a pinned release and enable logid.service, which reads
# root/etc/logid.cfg.
#
# @machine any
# @os arch
# @gui any
feature_logiops() {
  local unit_files
  # No systemctl (a macOS dry run) or a failing one just means logid.service isn't known to be installed.
  unit_files="$(systemctl list-unit-files 2>/dev/null || true)"
  if [[ "$unit_files" != *logid.service* ]]; then
    info "Installing PixlOne/logiops $LOGIOPS_VERSION..."
    run sudo pacman --needed -S cmake libevdev libconfig pkgconf
    if $DRY_RUN; then
      info "[dry-run] would build and install PixlOne/logiops from source"
    else
      with_tmpdir _build_logiops_in
    fi
  fi

  if [[ "$(systemctl is-active logid.service 2>/dev/null || true)" != "active" ]]; then
    info "Enabling logid.service..."
    run sudo systemctl enable --now logid.service
  fi
}

# System units the Arch desktop enables and starts right away.
DESKTOP_START_UNITS=(
  "bluetooth.service"                                           # bluetooth (bluez, from --pacman)
)
# System units it enables for the next boot only: starting the login screen now would replace the session running
# the install.
DESKTOP_BOOT_UNITS=(
  "gdm.service"                                                 # GNOME login screen (gdm, from --pacman)
)
# The target it boots into: the login screen, not a console.
DESKTOP_DEFAULT_TARGET="graphical.target"

# Enable the desktop's system units (bluetooth, and GDM from the next boot) and boot into the graphical target.
#
# @machine any
# @os arch
# @gui gnome
# @requires pacman
feature_desktop() {
  local unit
  for unit in "${DESKTOP_START_UNITS[@]}"; do
    if ! systemctl is-enabled --quiet "$unit" 2>/dev/null || ! systemctl is-active --quiet "$unit"; then
      info "Enabling and starting $unit..."
      run sudo systemctl enable --now "$unit"
    fi
  done
  for unit in "${DESKTOP_BOOT_UNITS[@]}"; do
    if ! systemctl is-enabled --quiet "$unit" 2>/dev/null; then
      info "Enabling $unit from the next boot..."
      run sudo systemctl enable "$unit"
    fi
  done
  if [[ "$(systemctl get-default 2>/dev/null)" != "$DESKTOP_DEFAULT_TARGET" ]]; then
    info "Booting into $DESKTOP_DEFAULT_TARGET from now on..."
    run sudo systemctl set-default "$DESKTOP_DEFAULT_TARGET"
  fi
}

# Edit files that can't be symlinked in place, e.g. turn on bluetooth at boot in /etc/bluetooth/main.conf.
#
# @machine any
# @os linux
# @gui any
feature_manual() {
  confirmsed /etc/bluetooth/main.conf "#AutoEnable=false" "AutoEnable=true" sudo
}

# Create the XDG user directories and set default apps for PDFs, images, audio and text.
#
# @machine any
# @os linux
# @gui gnome
# @requires pacman
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

# Print the settings in dump/ that must be imported by hand.
#
# @machine any
# @os any
# @gui any
feature_info() {
  cat <<EOF

Providing dump info...
'$DOTFILES_ROOT/dump' contains exported configuration files of various applications, typically those with guis.
dconf settings can be loaded automatically by using this installer with '--desktop_settings', and changes made in GNOME copied back with '--capture --desktop_settings'. Most settings need to be imported manually.

Configurations that must be loaded manually include:
 - Insync ignorerules: Account Settings > Ignore Rules (paste ignorerules text)
 - Okular shortcuts: Settings > Configure Keyboard Shortcuts > Manage Schemes > More Actions > Import Scheme (select default.shortcuts)
Files are available in $DOTFILES_ROOT/dump/<application>

EOF
}
