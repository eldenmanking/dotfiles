# Feature: custom Steam library artwork from dump/steamgrid (steamos).

STEAMGRID_STEAM="$HOME/.local/share/Steam"

# Print the app ids of the non-Steam shortcuts in the binary shortcuts.vdf <file>, one per line (nothing if it doesn't
# exist). Each shortcut stores its id as the 4-byte little-endian integer after the key "appid".
# Usage: steamgrid_shortcut_ids <file>
steamgrid_shortcut_ids() {
  [[ -f "$1" ]] || return 0
  od -An -v -tu1 "$1" | awk '
    { for (i = 1; i <= NF; i++) b[n++] = $i }
    END {
      split("2 97 112 112 105 100 0", key, " ")
      for (i = 0; i + 11 <= n; i++) {
        for (k = 1; k <= 7; k++) if (b[i + k - 1] != key[k]) break
        if (k > 7) printf "%.0f\n", b[i + 7] + b[i + 8] * 256 + b[i + 9] * 65536 + b[i + 10] * 16777216
      }
    }'
}

# Print the app ids of the Steam apps installed in the library folders under the Steam directory <steam_dir>, one per
# line: the default library plus those libraryfolders.vdf lists (an SD card, for one).
# Usage: steamgrid_installed_ids <steam_dir>
steamgrid_installed_ids() {
  local steam_dir="$1" lib manifest id libs
  libs="$steam_dir"
  if [[ -f "$steam_dir/steamapps/libraryfolders.vdf" ]]; then
    libs+=$'\n'"$(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$steam_dir/steamapps/libraryfolders.vdf")"
  fi
  while IFS= read -r lib; do
    [[ -n "$lib" ]] || continue
    for manifest in "$lib"/steamapps/appmanifest_*.acf; do
      [[ -f "$manifest" ]] || continue
      id="${manifest##*appmanifest_}"
      printf '%s\n' "${id%.acf}"
    done
  done <<< "$libs"
}

# Print the app id a file in dump/steamgrid is artwork for, taken from the digits its name starts with
# (<appid>p.png, <appid>_hero.png, <appid>_logo.png, <appid>.png, <appid>_icon.png), or nothing for any other name.
# Usage: steamgrid_file_id <file name>
steamgrid_file_id() {
  case "$1" in
    [0-9]*.png | [0-9]*.jpg | [0-9]*.webp) ;;
    *) return 0 ;;
  esac
  local id="${1%%[!0-9]*}"
  printf '%s\n' "$id"
}

# Copy the artwork in dump/steamgrid into each Steam user's config/grid for the apps that user has: their non-Steam
# shortcuts and any app installed in a Steam library. Files are named by app id, so ones for apps a user doesn't
# have are left out. A file that differs from one already there replaces it, after the first copy of the old one is
# backed up. Steam reads the artwork when it starts, so restart it to see changes.
#
# @machine any
# @os steamos
# @gui any
feature_steamgrid() {
  local src="$DOTFILES_ROOT/dump/steamgrid" userdata="$STEAMGRID_STEAM/userdata" user_dir grid file name id ids
  local installed found=false copied=0 current=0 dest
  if [[ ! -d "$src" ]]; then
    warn "$src does not exist"
    return
  fi
  installed="$(steamgrid_installed_ids "$STEAMGRID_STEAM")"
  for user_dir in "$userdata"/*/; do
    [[ -d "$user_dir" ]] || continue
    found=true
    user_dir="${user_dir%/}"
    grid="$user_dir/config/grid"
    ids="$(steamgrid_shortcut_ids "$user_dir/config/shortcuts.vdf")"$'\n'"$installed"
    for file in "$src"/*; do
      [[ -f "$file" ]] || continue
      name="${file##*/}"
      id="$(steamgrid_file_id "$name")"
      [[ -n "$id" ]] || continue
      grep -qx "$id" <<< "$ids" || continue
      dest="$grid/$name"
      if [[ -f "$dest" ]] && cmp -s "$file" "$dest"; then
        current=$((current + 1))
        continue
      fi
      info "Installing $name for Steam user ${user_dir##*/}..."
      run mkdir -p "$grid"
      # Keep the first backup: later ones would hold what an earlier install wrote.
      if [[ -f "$dest" && ! -e "$BACKUPS_ROOT$dest" ]]; then
        run mkdir -p "$(dirname "$BACKUPS_ROOT$dest")"
        run cp "$dest" "$BACKUPS_ROOT$dest"
      fi
      run cp "$file" "$dest"
      copied=$((copied + 1))
    done
  done

  if ! $found; then
    warn "No Steam user under $userdata; sign in to Steam once, then rerun with --steamgrid."
  elif [[ $copied -gt 0 ]]; then
    info "Steam artwork installed ($copied files); restart Steam to see it."
  else
    info "Steam artwork already up to date ($current files)"
  fi
}
