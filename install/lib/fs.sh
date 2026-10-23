# Filesystem helpers: symlinks and managed blocks.

# Create a symlink at $target pointing to $src, backing up any existing file
# or stale symlink. Third arg is an optional sudo-style prefix.
make_symlink() {
  local src="$1" target="$2" sudo_cmd="${3:-}"

  if [[ ! -e "$src" ]]; then
    warn "Source does not exist, skipping: $src"
    return
  fi

  # Already pointing where we want — nothing to do.
  if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$src" ]]; then
    return
  fi

  run $sudo_cmd mkdir -pv "$(dirname "$target")"

  # Back up anything in the way (regular file OR symlink pointing elsewhere).
  if [[ -e "$target" || -L "$target" ]]; then
    run mkdir -pv "$(dirname "$BACKUPS_ROOT$target")"
    if has_tty; then
      # shellcheck disable=SC2086 # $sudo_cmd is empty or a command
      run_tty $sudo_cmd mv -vi "$target" "$BACKUPS_ROOT$target"
    else
      run $sudo_cmd mv -v "$target" "$BACKUPS_ROOT$target"
    fi
  fi

  run $sudo_cmd ln -snfv "$src" "$target"
}

# Copy each file in $src_dir matching $glob into $dst_dir with sudo, replacing
# any old symlink. For system files read at boot, before an encrypted home is
# mounted, where a symlink into ~ would dangle. Outputs: _changed, the
# space-separated targets that were copied (empty if all were up to date).
# Usage: f_write_args copy_system_files _changed -- <src_dir> <dst_dir> <glob>
copy_system_files() {
  local src_dir="$1" dst_dir="$2" glob="$3" file target changed=""
  for file in "$src_dir"/$glob; do
    [[ -e "$file" ]] || continue
    target="$dst_dir/$(basename "$file")"
    if [[ ! -L "$target" ]] && cmp -s "$file" "$target"; then
      info "$target already up to date"
      continue
    fi
    info "Copying $file to $target..."
    run sudo rm -f "$target"
    run sudo install -Dvm 644 "$file" "$target"
    changed+="${changed:+ }$target"
  done
  _changed="$changed"
}

# --- Managed block helper ---
# Each managed file holds a single dotfiles section made of one subblock per
# feature. A feature only ever rewrites its own subblock:
#     # Managed by dotfiles
#
#     # feature <name>
#     ...content...
#
#     # /Managed by dotfiles
DOTFILES_BLOCK_START="# Managed by dotfiles"
DOTFILES_BLOCK_END="# /Managed by dotfiles"
DOTFILES_SUBBLOCK_PREFIX="# feature "

# Print the 1-based line numbers of lines in $1 exactly equal to $2.
_line_numbers() {
  awk -v s="$2" '$0 == s { print NR }' "$1"
}

# Return 0 if $file is a symlink into the dotfiles repo, where edits would
# land in tracked files.
_links_into_dotfiles() {
  local file="$1" target dir root
  [[ -L "$file" ]] || return 1
  target="$(readlink "$file")"
  [[ "$target" == /* ]] || target="$(dirname "$file")/$target"
  dir="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || return 1
  root="$(cd "$DOTFILES_ROOT" && pwd -P)"
  [[ "$dir/" == "$root/"* ]]
}

# Overwrite $file with $tmp in place, keeping its mode and any symlink.
_replace_contents() {
  local file="$1" tmp="$2"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

# Idempotently set the <name> subblock of the dotfiles section in <file> to
# <content>, creating the file and section as needed. A new section is
# appended, or inserted before the first line containing <insert_before> if
# given and present. Refuses to edit malformed sections and symlinks into the
# dotfiles repo.
# Usage: upsert_block <file> <name> <content> [insert_before]
upsert_block() {
  local file="$1" name="$2" content="$3" insert_before="${4:-}"
  local header="$DOTFILES_SUBBLOCK_PREFIX$name"

  [[ "$name" =~ ^[A-Za-z0-9_-]+$ ]] || error "upsert_block: invalid name '$name'"
  local line
  while IFS= read -r line; do
    if [[ "$line" == "$DOTFILES_BLOCK_START" || "$line" == "$DOTFILES_BLOCK_END" \
      || "$line" == "$DOTFILES_SUBBLOCK_PREFIX"* ]]; then
      error "upsert_block: content for '$name' contains a marker line: $line"
    fi
  done <<< "$content"

  if _links_into_dotfiles "$file"; then
    warn "$file links into the dotfiles repo; not adding block '$name'"
    return 0
  fi

  local starts="" ends=""
  if [[ -f "$file" ]]; then
    starts="$(_line_numbers "$file" "$DOTFILES_BLOCK_START")"
    ends="$(_line_numbers "$file" "$DOTFILES_BLOCK_END")"
    if [[ "$starts" == *$'\n'* || "$ends" == *$'\n'* ]] \
      || [[ -z "$starts" && -n "$ends" ]] || [[ -n "$starts" && -z "$ends" ]] \
      || { [[ -n "$starts" ]] && (( starts > ends )); }; then
      warn "Malformed dotfiles section in $file (need one '$DOTFILES_BLOCK_START' before one '$DOTFILES_BLOCK_END'); fix it by hand"
      return 1
    fi
  fi

  if $DRY_RUN; then
    info "[dry-run] would set block '$name' in $file"
    return 0
  fi

  local tmp content_file
  content_file="$(mktemp)"

  if [[ -z "$starts" ]]; then
    # No section yet: add an empty one for the update below to fill.
    printf '%s\n\n%s\n' "$DOTFILES_BLOCK_START" "$DOTFILES_BLOCK_END" > "$content_file"
    mkdir -p "$(dirname "$file")"
    if [[ -f "$file" && -n "$insert_before" ]] && grep -qF "$insert_before" "$file"; then
      tmp="$(mktemp)"
      awk -v pat="$insert_before" -v cf="$content_file" '
        !done && index($0, pat) {
          while ((getline line < cf) > 0) print line
          close(cf)
          print ""
          done = 1
        }
        { print }
      ' "$file" > "$tmp"
      _replace_contents "$file" "$tmp"
    else
      [[ -s "$file" ]] && printf '\n' >> "$file"
      cat "$content_file" >> "$file"
    fi
  fi

  # Copy the file, swapping this feature's subblock (up to the next subblock
  # or the section end) for the new content, or adding it at the section end.
  printf '%s\n' "$content" > "$content_file"
  tmp="$(mktemp)"
  awk -v start="$DOTFILES_BLOCK_START" -v end="$DOTFILES_BLOCK_END" \
      -v prefix="$DOTFILES_SUBBLOCK_PREFIX" -v header="$header" -v cf="$content_file" '
    function emit(  line) {
      print header
      while ((getline line < cf) > 0) print line
      close(cf)
      print ""
      done = 1
    }
    $0 == start { insec = 1 }
    insec && $0 == end { if (!done) emit(); insec = 0; skip = 0 }
    insec && index($0, prefix) == 1 {
      skip = 0
      if ($0 == header) { if (!done) emit(); skip = 1; next }
    }
    skip { next }
    { print }
  ' "$file" > "$tmp"
  rm -f "$content_file"

  if cmp -s "$tmp" "$file"; then
    info "Block '$name' already up to date in $file"
    rm -f "$tmp"
    return 0
  fi
  info "Updating block '$name' in $file"
  _replace_contents "$file" "$tmp"
}

# Set the <name> subblock of <file> to source each repo-relative <path>. Shell
# startup files only ever source files, so the same logic can be shared with the
# directly linked ones. Uses POSIX '.' since sh may read ~/.profile.
# Usage: upsert_sources <file> <name> <path>...
upsert_sources() {
  local file="$1" name="$2" content="" rel
  shift 2
  for rel in "$@"; do
    [[ -f "$DOTFILES_ROOT/$rel" ]] || error "upsert_sources: $DOTFILES_ROOT/$rel does not exist"
    content+="${content:+$'\n'}. ~/dotfiles/$rel"
  done
  upsert_block "$file" "$name" "$content"
}

# --- File writing and downloads (honor DRY_RUN) ---

# Write stdin to $dest, or just announce it under --dry-run.
write_file() {
  local dest="$1"
  if $DRY_RUN; then
    info "[dry-run] would write $dest"
    cat >/dev/null
  else
    cat >"$dest"
  fi
}

# Print $template with each __KEY__ replaced by VALUE, for each KEY=VALUE arg.
render_template() {
  local template="$1" pair args=()
  shift
  for pair in "$@"; do
    args+=(-e "s|__${pair%%=*}__|${pair#*=}|g")
  done
  sed "${args[@]}" "$template"
}

# Return 0 if $file exists and has SHA-256 $sha256.
sha256_matches() {
  local file="$1" sha256="$2"
  [[ -f "$file" ]] && echo "$sha256  $file" | sha256sum -c --status
}

# Download $url to $out and check it against $sha256 ($name is for messages).
download_verified() {
  local url="$1" sha256="$2" out="$3" name="$4"
  if $DRY_RUN; then
    info "[dry-run] would download $url"
    return
  fi
  curl -fsSL -o "$out" "$url" || return 1
  sha256_matches "$out" "$sha256" || { warn "$name checksum mismatch"; return 1; }
}
