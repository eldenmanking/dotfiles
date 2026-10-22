# Feature: KDE Plasma settings (steamos desktop mode). KDE rewrites its config files, so instead of linking them this
# sets individual keys with kwriteconfig, leaving everything else in the files alone.

# Settings as "file|group|key|value". Keyboard repeat matches dump/dconf/arch.dconf (150 ms delay, 10 ms interval).
KDE_SETTINGS=(
  "kcminputrc|Keyboard|KeyRepeat|repeat"
  "kcminputrc|Keyboard|RepeatDelay|150"
  "kcminputrc|Keyboard|RepeatRate|100"
)

# Resolve the kwriteconfig/kreadconfig pair for the installed Plasma (6, else 5), or empty when neither exists.
kde_config_tools() {
  local v
  _write=""
  _read=""
  for v in 6 5; do
    if command -v "kwriteconfig$v" >/dev/null && command -v "kreadconfig$v" >/dev/null; then
      _write="kwriteconfig$v"
      _read="kreadconfig$v"
      return
    fi
  done
}

feature_kde() {
  local writer reader entry file group key value
  f_write_args kde_config_tools _write _read --
  writer="$_write"
  reader="$_read"
  if [[ -z "$writer" ]]; then
    warn "kwriteconfig not found, skipping KDE settings."
    return
  fi

  for entry in "${KDE_SETTINGS[@]}"; do
    IFS='|' read -r file group key value <<< "$entry"
    if [[ "$("$reader" --file "$file" --group "$group" --key "$key")" == "$value" ]]; then
      info "KDE $file [$group] $key already $value"
      continue
    fi
    info "Setting KDE $file [$group] $key=$value"
    # --notify lets running Plasma/KWin pick up the change; otherwise it applies at the next login.
    run "$writer" --notify --file "$file" --group "$group" --key "$key" "$value"
  done
}
