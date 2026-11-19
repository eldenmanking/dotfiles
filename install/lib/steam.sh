# Editing Steam's own settings files (localconfig.vdf, config.vdf), for the features that set Steam settings.

# Read a Steam .vdf on stdin and print it with the value on each "key" line replaced by <value>. Fails if no line has
# the key, after printing the file unchanged. Steam writes each "key"<tab><tab>"value" pair on its own line.
# Usage: steam_vdf_replace <key> <value>
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

# Apply <setting>... to the Steam .vdf <file>, without writing it.
# Usage: f_call steam_apply_settings content missing -- <file> <setting>...
#   <setting>: key|value
# Returns: content missing
#   content: <file>'s contents with the value of each <setting>'s key replaced
#   missing: the space-separated keys it lacks
steam_apply_settings() {
  local file="$1" content entry key value missing=""
  shift
  content="$(cat "$file")"
  for entry in "$@"; do
    IFS='|' read -r key value <<< "$entry"
    content="$(steam_vdf_replace "$key" "$value" <<< "$content")" || missing+="${missing:+ }$key"
  done
  f_return content missing
}

# Set <setting>... in the Steam .vdf <file>. Only keys Steam already wrote are replaced, so the caller should ask for
# a missing one to be set once in Steam first. Steam rewrites the file from memory when it exits, so this only edits
# it while Steam isn't running (and warns otherwise); the settings apply the next time Steam starts. The first time it
# changes <file>, it backs the old one up under $BACKUPS_ROOT.
# Usage: f_call steam_set_vdf changed missing -- <file> <setting>...
#   <setting>: key|value
# Returns: changed missing
#   changed: <file> if it was written, else empty
#   missing: the space-separated keys it lacks
steam_set_vdf() {
  local file="$1" tmp content missing changed=""
  f_call steam_apply_settings content missing -- "$@"
  tmp="$(mktemp)"
  printf '%s\n' "$content" > "$tmp"
  if cmp -s "$file" "$tmp"; then
    info "$file already up to date"
  elif pgrep -x steam >/dev/null 2>&1; then
    warn "Steam is running and would overwrite $file on exit; quit Steam and rerun."
  else
    info "Updating Steam settings in $file..."
    # Keep the first backup: later ones would hold what an earlier install wrote.
    if [[ ! -e "$BACKUPS_ROOT$file" ]]; then
      run mkdir -p "$(dirname "$BACKUPS_ROOT$file")"
      run cp "$file" "$BACKUPS_ROOT$file"
    fi
    run cp "$tmp" "$file"
    changed="$file"
  fi
  rm -f "$tmp"
  f_return changed missing
}
