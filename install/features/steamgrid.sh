# Feature: custom Steam library artwork from dump/steamgrid (steamos).

STEAMGRID_STEAM="$HOME/.local/share/Steam"

# The apps whose artwork is in dump/steamgrid, as "<app id> <name>". A non-Steam shortcut's app id comes from its name
# and executable, so it is the same on every machine; the files are named by it (<id>p.png, <id>_hero.png).
STEAMGRID_APPS=(
  "2293441873 Google Chrome"
  "2333229111 Discord"
)

# Copy the artwork of the STEAMGRID_APPS in dump/steamgrid into every Steam user's config/grid, whether or not that
# user has the app yet: Steam ignores artwork for an app it doesn't know, and shows it once the shortcut is added. A
# file that differs from one already there replaces it, after the first copy of the old one is backed up. Steam reads
# the artwork when it starts, so restart it to see changes.
#
# @machine any
# @os steamos
# @gui any
feature_steamgrid() {
  local src="$DOTFILES_ROOT/dump/steamgrid" userdata="$STEAMGRID_STEAM/userdata" user_dir grid app id name file dest
  local found=false copied=0 current=0
  for user_dir in "$userdata"/*/; do
    [[ -d "$user_dir" ]] || continue
    found=true
    user_dir="${user_dir%/}"
    grid="$user_dir/config/grid"
    for app in "${STEAMGRID_APPS[@]}"; do
      id="${app%% *}"
      for file in "$src/$id"p.png "$src/$id"_hero.png; do
        if [[ ! -f "$file" ]]; then
          warn "$file is missing (${app#* })"
          continue
        fi
        name="${file##*/}"
        dest="$grid/$name"
        if [[ -f "$dest" ]] && cmp -s "$file" "$dest"; then
          current=$((current + 1))
          continue
        fi
        info "Installing $name (${app#* }) for Steam user ${user_dir##*/}..."
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
  done

  if ! $found; then
    warn "No Steam user under $userdata; sign in to Steam once, then rerun with --steamgrid."
  elif [[ $copied -gt 0 ]]; then
    info "Steam artwork installed ($copied files); restart Steam to see it."
  else
    info "Steam artwork already up to date ($current files)"
  fi
}
