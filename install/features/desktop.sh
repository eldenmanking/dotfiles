# Features: desktop setup (fonts, logiops, desktop system units, dconf, xdg).

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
  local tmp
  tmp="$(mktemp -d)"
  download_verified \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/$FONT_NF_VERSION/JetBrainsMono.tar.xz" \
    "$FONT_SHA256" "$tmp/font.tar.xz" font \
    || { rm -rf "$tmp"; error "could not download the font"; }
  # Extract aside and swap in, so a failed extract keeps the old fonts and files dropped by a newer release don't linger.
  run mkdir -p "$tmp/new"
  run tar -xJf "$tmp/font.tar.xz" -C "$tmp/new" --wildcards '*.ttf' OFL.txt \
    || { rm -rf "$tmp"; error "could not extract the font"; }
  run rm -rf "$FONT_DEST"
  run mkdir -p "$(dirname "$FONT_DEST")"
  run mv "$tmp/new" "$FONT_DEST"
  if command -v fc-cache >/dev/null; then run fc-cache -f "$FONT_DEST"; fi
  $DRY_RUN || printf '%s\n' "$FONT_NF_VERSION $FONT_SHA256" > "$FONT_STAMP"
  rm -rf "$tmp"
  info "Installed $FONT_FAMILY to $FONT_DEST (restart the browser if it was open)"
}

# Build logiops (Logitech mouse and keyboard daemon) from source and enable logid.service, which reads
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

# The GNOME settings dump/dconf/arch.dconf keeps: --capture --dconf writes the keys of `dconf dump /` that these select.
# An entry ending in / selects a dconf directory with its subdirectories, and any other entry a single key. An entry
# starting with ! leaves out what it names, for state kept beside settings (see capture_filter). Keep only settings worth carrying to another
# machine: org/gnome/shell, for one, also holds the Alt+F2 command history and extension state.
DCONF_CAPTURE=(
  org/gnome/desktop/app-folders/
  org/gnome/desktop/background/
  org/gnome/desktop/input-sources/
  '!org/gnome/desktop/input-sources/mru-sources'
  org/gnome/desktop/interface/
  org/gnome/desktop/peripherals/
  org/gnome/desktop/privacy/
  org/gnome/desktop/screensaver/
  org/gnome/desktop/session/
  org/gnome/desktop/wm/keybindings/
  org/gnome/mutter/
  org/gnome/nautilus/icon-view/
  org/gnome/nautilus/list-view/
  org/gnome/nautilus/preferences/
  '!org/gnome/nautilus/preferences/migrated-gtk-settings'
  org/gnome/settings-daemon/plugins/
  '!org/gnome/settings-daemon/plugins/color/night-light-last-coordinates'
  org/gnome/shell/app-switcher/
  org/gnome/shell/favorite-apps
  org/gnome/terminal/legacy/profiles:/
)
DCONF_DUMP="$DOTFILES_ROOT/dump/dconf/arch.dconf"

# Print text $1 with each path under home directory $2 written as ${HOME}/..., for the repo.
dconf_unexpand_home() {
  printf '%s\n' "${1//"$2/"/\$\{HOME\}/}"
}

# Print text $1 with each ${HOME}/... written as a path under home directory $2, for dconf.
dconf_expand_home() {
  printf '%s\n' "${1//"\${HOME}/"/$2/}"
}

# Back up the current dconf settings, then load dump/dconf/arch.dconf (GNOME settings), with ${HOME} expanded to the
# home directory. The first backup is kept, since later ones would hold what an earlier install loaded.
#
# @machine any
# @os linux
# @gui gnome
feature_dconf() {
  local backup="$BACKUPS_ROOT$DCONF_DUMP" tmp

  if [[ -e "$backup" ]]; then
    info "Keeping the earlier dconf backup $backup"
  elif $DRY_RUN; then
    info "[dry-run] would dump dconf to $backup"
  else
    info "Backing up current dconf configuration..."
    mkdir -p "$(dirname "$backup")"
    tmp="$(mktemp)"
    dconf dump / > "$tmp" || { rm -f "$tmp"; error "could not dump dconf"; }
    mv "$tmp" "$backup"
  fi
  if $DRY_RUN; then
    info "[dry-run] would load dconf from $DCONF_DUMP"
    return
  fi

  dconf_expand_home "$(cat "$DCONF_DUMP")" "$HOME" | dconf load /
  info "dconf configuration loaded."
}

# For --capture: write the settings DCONF_CAPTURE selects from this system's dconf into dump/dconf/arch.dconf, with paths
# under the home directory written as ${HOME}/..., e.g. after changing them in GNOME Settings. With none of them set
# (an unconfigured machine), the file is left alone. Under --dry-run, prints the change as a diff instead.
capture_feature_dconf() {
  local dump text
  if ! command -v dconf >/dev/null; then
    warn "dconf not found, skipping dconf settings."
    return
  fi
  dump="$(dconf dump /)" || error "could not dump dconf"
  text="$(printf '%s\n' "$dump" | capture_filter "${DCONF_CAPTURE[@]}")"
  if [[ -z "$text" ]]; then
    warn "None of the settings in DCONF_CAPTURE are set on this system; leaving ${DCONF_DUMP##*/} as it is"
    return
  fi
  write_captured "$DCONF_DUMP" "$(dconf_unexpand_home "$text" "$HOME")"
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
dconf settings can be loaded automatically by using this installer with '--dconf', and changes made in GNOME copied back with '--capture --dconf'. Most settings need to be imported manually.

Configurations that must be loaded manually include:
 - Insync ignorerules: Account Settings > Ignore Rules (paste ignorerules text)
 - Okular shortcuts: Settings > Configure Keyboard Shortcuts > Manage Schemes > More Actions > Import Scheme (select default.shortcuts)
Files are available in $DOTFILES_ROOT/dump/<application>

EOF
}
