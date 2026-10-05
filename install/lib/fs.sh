# TODO(andywang): add comment

# Create a symlink at $target pointing to $src, backing up any existing file
# or stale symlink. Third arg is an optional sudo-style prefix.
make_symlink() {
  local dry_run="$1" src="$2" target="$3" sudo_cmd="${4:-}"

  if [[ ! -e "$src" ]]; then
    warn "Source does not exist, skipping: $src"
    return
  fi

  # Already pointing where we want — nothing to do.
  if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$src" ]]; then
    return
  fi

  run "$dry_run" $sudo_cmd mkdir -pv "$(dirname "$target")"

  # Back up anything in the way (regular file OR symlink pointing elsewhere).
  if [[ -e "$target" || -L "$target" ]]; then
    run "$dry_run" mkdir -pv "$(dirname "$BACKUPS_ROOT$target")"
    if has_tty; then
      run_tty "$dry_run" $sudo_cmd mv -vi "$target" "$BACKUPS_ROOT$target"
    else
      run "$dry_run" $sudo_cmd mv -v "$target" "$BACKUPS_ROOT$target"
    fi
  fi

  run "$dry_run" $sudo_cmd ln -snfv "$src" "$target"
}

# --- Managed block helper ---
# Idempotently insert or update a named block of lines in a file. Each block is
# delimited by markers unique to <name>:
#     # Added by light-install.sh#<name>
#     ...content...
#     # /Added by light-install.sh#<name>
# so multiple blocks can coexist in one file and each is updated in place (not
# duplicated) on re-run. Creates the file if missing.
# Usage: upsert_block <file> <name> <content>
upsert_block() {
  local file="$1" name="$2" content="$3"
  local start="# Added by light-install.sh#$name"
  local end="# /Added by light-install.sh#$name"

  if [[ ! -f "$file" ]]; then
    info "Creating $file"
    touch "$file"
  fi

  local desired
  desired="$(printf '%s\n%s\n%s' "$start" "$content" "$end")"

  # No existing block for this name — append a fresh one.
  if ! grep -qxF "$start" "$file"; then
    info "Adding block '$name' to $file"
    printf '\n%s\n' "$desired" >> "$file"
    return
  fi

  # Block exists — skip if unchanged, otherwise replace it in place.
  local existing
  existing="$(awk -v s="$start" -v e="$end" '
    $0==s {found=1}
    found {print}
    $0==e {found=0}
  ' "$file")"
  if [[ "$existing" == "$desired" ]]; then
    info "Block '$name' already up to date in $file"
    return
  fi

  info "Updating block '$name' in $file"
  local tmp content_file
  tmp="$(mktemp)"
  content_file="$(mktemp)"
  printf '%s\n' "$desired" > "$content_file"
  awk -v s="$start" -v e="$end" -v cf="$content_file" '
    $0==s {
      while ((getline line < cf) > 0) print line
      close(cf)
      skip=1
      next
    }
    skip && $0==e { skip=0; next }
    !skip { print }
  ' "$file" > "$tmp"
  rm "$content_file"
  mv "$tmp" "$file"
}
