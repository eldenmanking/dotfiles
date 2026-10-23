# Feature: Steam client settings (steamos game mode).

STEAM_USERDATA="$HOME/.local/share/Steam/userdata"

# Settings as "section|key|value" in the top level of each Steam user's config/localconfig.vdf. Hotkeys are the
# modifiers and the key separated by tabs, as Steam writes them.
STEAM_SETTINGS=(
  "Gamescope|GuideKeyboardHotkey|Win	KEY_TAB"         # main menu (Steam button)
  "Gamescope|QAMKeyboardHotkey|Shift	Win	KEY_TAB"     # quick access menu (... button)
)

# Read a localconfig.vdf on stdin and print it with "key" "value" set in top-level section $1, adding the key or the
# section if missing. Steam writes one token pair or brace per line, indented with one tab per level.
steam_vdf_set() {
  SECTION="$1" KEY="$2" VALUE="$3" awk '
    function pair(indent) { return indent "\"" ENVIRON["KEY"] "\"\t\t\"" ENVIRON["VALUE"] "\"" }
    {
      line = $0
      sub(/^\t+/, "", line)
      if (line == "{") {
        depth++
        if (pending) { in_section = 1; pending = 0 }
      } else if (line == "}") {
        if (in_section && depth == 2) {
          if (!done) print pair("\t\t")
          done = 1
          in_section = 0
        } else if (depth == 1 && !done) {
          print "\t\"" ENVIRON["SECTION"] "\""
          print "\t{"
          print pair("\t\t")
          print "\t}"
          done = 1
        }
        depth--
      } else if (depth == 1 && line == "\"" ENVIRON["SECTION"] "\"") {
        pending = 1
      } else if (in_section && depth == 2 && index(line, "\"" ENVIRON["KEY"] "\"\t") == 1) {
        if (!done) print pair("\t\t")
        done = 1
        next
      }
      print
    }
  '
}

# Print the localconfig.vdf on stdin with every STEAM_SETTINGS entry applied.
steam_apply_settings() {
  local content entry section key value
  content="$(cat)"
  for entry in "${STEAM_SETTINGS[@]}"; do
    IFS='|' read -r section key value <<< "$entry"
    content="$(steam_vdf_set "$section" "$key" "$value" <<< "$content")"
  done
  printf '%s\n' "$content"
}

# Write STEAM_SETTINGS into each Steam user's localconfig.vdf. Steam rewrites the file from memory when it exits, so
# this only edits it while Steam isn't running; the settings apply the next time Steam starts.
#
# @machine any
# @os steamos
# @gui any
feature_steam() {
  local file tmp found=false changed=false
  for file in "$STEAM_USERDATA"/*/config/localconfig.vdf; do
    [[ -f "$file" ]] || continue
    found=true
    tmp="$(mktemp)"
    steam_apply_settings < "$file" > "$tmp"
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
