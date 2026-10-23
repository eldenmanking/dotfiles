# Feature: Steam client settings (steamos game mode).

STEAM_USERDATA="$HOME/.local/share/Steam/userdata"

# Settings as "key|value" in each Steam user's config/localconfig.vdf (the hotkeys are in its "Gamescope" section).
# Hotkeys are the modifiers and the key separated by tabs, as Steam writes them.
STEAM_SETTINGS=(
  "GuideKeyboardHotkey|Win	KEY_TAB"         # main menu (Steam button)
  "QAMKeyboardHotkey|Shift	Win	KEY_TAB"     # quick access menu (... button)
)

# Read a localconfig.vdf on stdin and print it with the value on each "key" line replaced by $2. Fails if no line has
# the key, after printing the file unchanged. Steam writes each "key"<tab><tab>"value" pair on its own line.
steam_vdf_replace() {
  KEY="$1" VALUE="$2" awk '
    {
      match($0, /^\t*/)
      if (index($0, "\"" ENVIRON["KEY"] "\"\t") == RLENGTH + 1) {
        $0 = substr($0, 1, RLENGTH) "\"" ENVIRON["KEY"] "\"\t\t\"" ENVIRON["VALUE"] "\""
        found = 1
      }
      print
    }
    END { exit !found }
  '
}

# Outputs: _content, localconfig.vdf $1 with every STEAM_SETTINGS value replaced, and _missing, the space-separated
# keys it lacks.
# Usage: f_write_args steam_apply_settings _content _missing -- <file>
steam_apply_settings() {
  local file="$1" content entry key value missing=""
  content="$(cat "$file")"
  for entry in "${STEAM_SETTINGS[@]}"; do
    IFS='|' read -r key value <<< "$entry"
    content="$(steam_vdf_replace "$key" "$value" <<< "$content")" || missing+="${missing:+ }$key"
  done
  _content="$content"
  _missing="$missing"
}

# Replace the STEAM_SETTINGS values in each Steam user's localconfig.vdf. Only keys Steam already wrote are replaced,
# so a missing one must be set once in Steam first. Steam rewrites the file from memory when it exits, so this only
# edits it while Steam isn't running; the settings apply the next time Steam starts.
#
# @machine any
# @os steamos
# @gui any
feature_steam() {
  local file tmp found=false changed=false
  for file in "$STEAM_USERDATA"/*/config/localconfig.vdf; do
    [[ -f "$file" ]] || continue
    found=true
    f_write_args steam_apply_settings _content _missing -- "$file"
    [[ -z "$_missing" ]] || warn "$file has no $_missing; set it once in Steam (Settings > In Game), then rerun with --steam."
    tmp="$(mktemp)"
    printf '%s\n' "$_content" > "$tmp"
    if cmp -s "$file" "$tmp"; then
      info "$file already up to date"
    elif pgrep -x steam >/dev/null 2>&1; then
      warn "Steam is running and would overwrite $file on exit; quit Steam and rerun with --steam."
    else
      info "Updating Steam settings in $file..."
      run mkdir -p "$(dirname "$BACKUPS_ROOT$file")"
      run cp "$file" "$BACKUPS_ROOT$file"
      run cp "$tmp" "$file"
      changed=true
    fi
    rm -f "$tmp"
  done

  if ! $found; then
    warn "No Steam user config under $STEAM_USERDATA; sign in to Steam once, then rerun with --steam."
  elif $changed; then
    info "Steam settings updated; they apply the next time Steam starts."
  fi
}
