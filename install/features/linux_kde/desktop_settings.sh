# Feature: desktop settings on KDE Plasma (steamos desktop mode). KDE rewrites its config files, which would break
# symlinks, so each file listed here is merged into its ~/.config counterpart key by key with kwriteconfig, leaving
# other keys alone. --capture writes each file back from its ~/.config counterpart, keeping the keys KDE_CAPTURE
# selects. linux_gnome/desktop_settings.sh does the same on GNOME.

# Partial KDE config files, home/-relative like the link paths. Nested groups ([A][B]) are supported. --capture rewrites
# them, so keep notes about their settings here, not in comments in them:
# - kcminputrc sets the keyboard repeat (300 ms delay; GNOME on Arch uses 200 ms, in dump/dconf/arch.dconf).
# - kxkbrc sets no XKB options: the Keychron's firmware swaps Caps Lock and Escape, so Plasma mustn't remap them too.
# - powerdevilrc makes closing the lid on external power do nothing (LidAction=0 is "do nothing"). PowerDevil holds the
#   lid switch away from logind, so the logind feature's lid.conf doesn't reach Desktop Mode, and PowerDevil's default
#   (sleep) re-suspends the laptop right after a wake with the lid closed, while the projector's output is still coming
#   back. Closing it on battery still suspends. PowerDevil reads this when it starts, so it applies from the next login.
KDE_CONFIG_FILES=(
  home/.config/kcminputrc
  home/.config/kxkbrc
  home/.config/powerdevilrc
)

# The KDE settings the files in KDE_CONFIG_FILES keep: --capture --desktop_settings writes the keys of each ~/.config
# file that these select, as <file>/<group>/<key> (see capture_filter): an entry ending in / selects a whole group, any
# other a single key, and an entry starting with ! leaves out what it names.
KDE_CAPTURE=(
  kcminputrc/Keyboard/
  kxkbrc/Layout/Options
  'powerdevilrc/AC][SuspendAndShutdown/LidAction'
)

# Resolve the kwriteconfig/kreadconfig pair for the installed Plasma (6, else 5).
# Usage: f_call kde_config_tools write read
# Returns: write read
#   write: kwriteconfig6 or kwriteconfig5, or empty when neither pair exists
#   read: kreadconfig6 or kreadconfig5, or empty when neither pair exists
kde_config_tools() {
  local v
  f_return write="" read=""
  for v in 6 5; do
    if command -v "kwriteconfig$v" >/dev/null && command -v "kreadconfig$v" >/dev/null; then
      f_return write="kwriteconfig$v" read="kreadconfig$v"
      return
    fi
  done
}

# Parse INI file <file>, skipping blank lines, # and ; comments, and keys outside a group.
# Usage: f_call kde_parse_ini entries -- <file>
# Returns: entries
#   entries: newline-separated "group<TAB>key<TAB>value" entries, where group keeps nested groups as "A][B"
kde_parse_ini() {
  local file="$1" line group="" key value entries=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    case "$line" in
      ''|'#'*|';'*) ;;
      '['*']') group="${line#[}"; group="${group%]}" ;;
      *=*)
        [[ -n "$group" ]] || continue
        key="${line%%=*}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${line#*=}"
        value="${value#"${value%%[![:space:]]*}"}"
        entries+="$group"$'\t'"$key"$'\t'"$value"$'\n'
        ;;
    esac
  done < "$file"
  f_return entries
}

# Merge each partial KDE config file in KDE_CONFIG_FILES into its ~/.config counterpart with kwriteconfig.
#
# @machine any
# @os linux
# @gui kde
feature_desktop_settings__linux_kde() {
  local writer reader rel file entries group key value rest group_args
  f_call kde_config_tools writer=write reader=read
  if [[ -z "$writer" ]]; then
    warn "kwriteconfig not found, skipping KDE settings."
    return
  fi

  for rel in "${KDE_CONFIG_FILES[@]}"; do
    file="$HOME/${rel#home/}"
    f_call kde_parse_ini entries -- "$DOTFILES_ROOT/$rel"
    while IFS=$'\t' read -r group key value; do
      [[ -n "$key" ]] || continue
      # "A][B" becomes --group A --group B.
      group_args=()
      rest="$group"
      while [[ "$rest" == *']['* ]]; do
        group_args+=(--group "${rest%%][*}")
        rest="${rest#*][}"
      done
      group_args+=(--group "$rest")
      if [[ "$("$reader" --file "$file" "${group_args[@]}" --key "$key")" == "$value" ]]; then
        info "KDE ${rel##*/} [$group] $key already $value"
        continue
      fi
      info "Setting KDE ${rel##*/} [$group] $key=$value"
      # --notify lets running Plasma/KWin pick up the change; otherwise it applies at the next login.
      run "$writer" --notify --file "$file" "${group_args[@]}" --key "$key" "$value"
    done <<< "$entries"
  done
}

# For --capture: write each file in KDE_CONFIG_FILES from its ~/.config counterpart, keeping only the keys KDE_CAPTURE
# selects for it, e.g. after changing them in System Settings. A file with none of them set is left alone.
capture_feature_desktop_settings__linux_kde() {
  local rel name live entry entries text
  for rel in "${KDE_CONFIG_FILES[@]}"; do
    name="${rel##*/}"
    live="$HOME/${rel#home/}"
    entries=()
    for entry in "${KDE_CAPTURE[@]}"; do
      case "$entry" in
        "$name"/*)  entries+=("${entry#"$name"/}") ;;
        "!$name"/*) entries+=("!${entry#"!$name"/}") ;;
      esac
    done
    if [[ ${#entries[@]} -eq 0 ]]; then
      warn "KDE_CAPTURE selects nothing in $name; leaving it as it is"
      continue
    fi
    text=""
    [[ ! -f "$live" ]] || text="$(capture_filter "${entries[@]}" < "$live")"
    if [[ -z "$text" ]]; then
      warn "None of the settings KDE_CAPTURE selects in $name are set on this system; leaving it as it is"
      continue
    fi
    write_captured "$DOTFILES_ROOT/$rel" "$text"
  done
}
