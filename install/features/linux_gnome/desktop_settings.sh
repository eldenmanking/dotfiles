# Feature: desktop settings on GNOME, loaded from dump/dconf/arch.dconf with dconf. --capture writes the file back from
# this system's dconf, keeping the keys DCONF_CAPTURE selects. linux_kde/desktop_settings.sh does the same on KDE.

# The GNOME settings dump/dconf/arch.dconf keeps: --capture --desktop_settings writes the keys of `dconf dump /` that
# these select. An entry ending in / selects a dconf directory with its subdirectories, and any other entry a single
# key. An entry starting with ! leaves out what it names, for state kept beside settings (see capture_filter). Keep only
# settings worth carrying to another machine: org/gnome/shell, for one, also holds the Alt+F2 command history and
# extension state.
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
# Usage: dconf_unexpand_home <text> <home>
dconf_unexpand_home() {
  printf '%s\n' "${1//"$2/"/\$\{HOME\}/}"
}

# Print text $1 with each ${HOME}/... written as a path under home directory $2, for dconf.
# Usage: dconf_expand_home <text> <home>
dconf_expand_home() {
  printf '%s\n' "${1//"\${HOME}/"/$2/}"
}

# Back up the current dconf settings, then load dump/dconf/arch.dconf (GNOME settings), with ${HOME} expanded to the
# home directory. The first backup is kept, since later ones would hold what an earlier install loaded.
#
# @machine any
# @os linux
# @gui gnome
feature_desktop_settings__linux_gnome() {
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

# For --capture: write the settings DCONF_CAPTURE selects from this system's dconf into dump/dconf/arch.dconf, with
# paths under the home directory written as ${HOME}/..., e.g. after changing them in GNOME Settings. With none of them
# set (an unconfigured machine), the file is left alone. Under --dry-run, prints the change as a diff instead.
capture_feature_desktop_settings__linux_gnome() {
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
