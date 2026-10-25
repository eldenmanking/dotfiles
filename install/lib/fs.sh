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

  run ${sudo_cmd:+"$sudo_cmd"} mkdir -pv "$(dirname "$target")"

  # Back up anything in the way (regular file OR symlink pointing elsewhere).
  if [[ -e "$target" || -L "$target" ]]; then
    run mkdir -pv "$(dirname "$BACKUPS_ROOT$target")"
    if has_tty; then
      run_tty ${sudo_cmd:+"$sudo_cmd"} mv -vi "$target" "$BACKUPS_ROOT$target"
    else
      run ${sudo_cmd:+"$sudo_cmd"} mv -v "$target" "$BACKUPS_ROOT$target"
    fi
  fi

  run ${sudo_cmd:+"$sudo_cmd"} ln -snfv "$src" "$target"
}

# Scripts and binaries that system services and the login screen run, copied outside the home, which may be
# encrypted and locked when they run.
SYSTEM_BIN_DIR=/etc/dotfiles/bin

# Copy repo file $2 (under root/) to its install path with sudo and mode $1, replacing any old symlink, unless it is
# already up to date. For files run or read while an encrypted home may still be locked.
# Usage: copy_system_file <mode> <root/path>
copy_system_file() {
  local mode="$1" src="$2" dest="/${2#root/}"
  if [[ ! -L "$dest" ]] && cmp -s "$DOTFILES_ROOT/$src" "$dest"; then
    info "$dest already up to date"
    return 0
  fi
  run sudo rm -f "$dest"
  run sudo install -Dvm"$mode" "$DOTFILES_ROOT/$src" "$dest"
}

# Remove files $1... with sudo, then SYSTEM_BIN_DIR and its parent if that left them empty (other features may still
# have files there).
# Usage: remove_system_files <path>...
remove_system_files() {
  local path dir
  for path in "$@"; do
    [[ -e "$path" || -L "$path" ]] || continue
    run sudo rm -fv "$path"
  done
  for dir in "$SYSTEM_BIN_DIR" "${SYSTEM_BIN_DIR%/*}"; do
    if [[ -d "$dir" && -z "$(ls -A "$dir")" ]]; then
      run sudo rmdir "$dir"
    fi
  done
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

# Print the paths that copy_system_files would copy each file in $1 matching $2 to in $3, one per line.
# Usage: system_file_targets <src_dir> <glob> <dst_dir>
system_file_targets() {
  local src_dir="$1" glob="$2" dst_dir="$3" file
  for file in "$src_dir"/$glob; do
    [[ -e "$file" ]] && printf '%s\n' "$dst_dir/$(basename "$file")"
  done
  return 0
}

# --- Managed block helper ---
# Each managed file holds a single dotfiles section made of one subblock per
# feature. A feature only ever rewrites its own subblock:
#     ## Managed by dotfiles
#
#     ## feature <name>
#     ...content...
#
#     ## /Managed by dotfiles
# The markers start with '##', a comment in sh, zsh and SteamOS keep lists alike.
# Sections written before used '#'; upsert_block converts them.
DOTFILES_BLOCK_START="## Managed by dotfiles"
DOTFILES_BLOCK_END="## /Managed by dotfiles"
DOTFILES_SUBBLOCK_PREFIX="## feature "
DOTFILES_OLD_BLOCK_START="# Managed by dotfiles"
DOTFILES_OLD_BLOCK_END="# /Managed by dotfiles"
DOTFILES_OLD_SUBBLOCK_PREFIX="# feature "

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

# Return 0 if line $1 is a section marker, old or current.
_is_marker_line() {
  [[ "$1" == "$DOTFILES_BLOCK_START" || "$1" == "$DOTFILES_BLOCK_END" || "$1" == "$DOTFILES_SUBBLOCK_PREFIX"* \
    || "$1" == "$DOTFILES_OLD_BLOCK_START" || "$1" == "$DOTFILES_OLD_BLOCK_END" \
    || "$1" == "$DOTFILES_OLD_SUBBLOCK_PREFIX"* ]]
}

# Print file $1 with the markers of an old-style section (starting with a single
# '#') changed to the current ones. Everything else is printed unchanged.
_convert_old_section() {
  awk -v os="$DOTFILES_OLD_BLOCK_START" -v oe="$DOTFILES_OLD_BLOCK_END" -v op="$DOTFILES_OLD_SUBBLOCK_PREFIX" \
      -v ns="$DOTFILES_BLOCK_START" -v ne="$DOTFILES_BLOCK_END" -v np="$DOTFILES_SUBBLOCK_PREFIX" '
    $0 == os { print ns; insec = 1; next }
    insec && $0 == oe { print ne; insec = 0; next }
    insec && index($0, op) == 1 { print np substr($0, length(op) + 1); next }
    { print }
  ' "$1"
}

# Overwrite $file with $tmp in place (keeping its mode and any symlink), creating
# its directory as needed, then remove $tmp. Third arg is an optional sudo-style
# prefix for the write.
_replace_contents() {
  local file="$1" tmp="$2" sudo_cmd="${3:-}"
  ${sudo_cmd:+"$sudo_cmd"} mkdir -p "$(dirname "$file")"
  ${sudo_cmd:+"$sudo_cmd"} tee "$file" < "$tmp" >/dev/null
  rm -f "$tmp"
}

# Idempotently set the <name> subblock of the dotfiles section in <file> to
# <content>, creating the file and section as needed. A new section is
# appended, or inserted before the first line containing <insert_before> if
# given and present. <sudo> is an optional sudo-style prefix for writing files
# the user can read but not write. Refuses to edit malformed sections and
# symlinks into the dotfiles repo.
# Usage: upsert_block <file> <name> <content> [insert_before] [sudo]
upsert_block() {
  local file="$1" name="$2" content="$3" insert_before="${4:-}" sudo_cmd="${5:-}"
  local header="$DOTFILES_SUBBLOCK_PREFIX$name"

  [[ "$name" =~ ^[A-Za-z0-9_-]+$ ]] || error "upsert_block: invalid name '$name'"
  local line
  while IFS= read -r line; do
    _is_marker_line "$line" && error "upsert_block: content for '$name' contains a marker line: $line"
  done <<< "$content"

  if _links_into_dotfiles "$file"; then
    warn "$file links into the dotfiles repo; not adding block '$name'"
    return 0
  fi

  # Work on a copy, with any old-style section converted, and write it back once.
  local work starts ends
  work="$(mktemp)"
  if [[ -f "$file" ]]; then
    _convert_old_section "$file" > "$work"
  fi
  starts="$(_line_numbers "$work" "$DOTFILES_BLOCK_START")"
  ends="$(_line_numbers "$work" "$DOTFILES_BLOCK_END")"
  if [[ "$starts" == *$'\n'* || "$ends" == *$'\n'* ]] \
    || [[ -z "$starts" && -n "$ends" ]] || [[ -n "$starts" && -z "$ends" ]] \
    || { [[ -n "$starts" ]] && (( starts > ends )); }; then
    rm -f "$work"
    warn "Malformed dotfiles section in $file (need one '$DOTFILES_BLOCK_START' before one '$DOTFILES_BLOCK_END'); fix it by hand"
    return 1
  fi

  if $DRY_RUN; then
    rm -f "$work"
    info "[dry-run] would set block '$name' in $file"
    return 0
  fi

  local tmp content_file
  content_file="$(mktemp)"

  if [[ -z "$starts" ]]; then
    # No section yet: add an empty one for the update below to fill.
    printf '%s\n\n%s\n' "$DOTFILES_BLOCK_START" "$DOTFILES_BLOCK_END" > "$content_file"
    if [[ -n "$insert_before" ]] && grep -qF "$insert_before" "$work"; then
      tmp="$(mktemp)"
      awk -v pat="$insert_before" -v cf="$content_file" '
        !done && index($0, pat) {
          while ((getline line < cf) > 0) print line
          close(cf)
          print ""
          done = 1
        }
        { print }
      ' "$work" > "$tmp"
      mv "$tmp" "$work"
    else
      if [[ -s "$work" ]]; then
        printf '\n' >> "$work"
      fi
      cat "$content_file" >> "$work"
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
  ' "$work" > "$tmp"
  rm -f "$work" "$content_file"

  if [[ -f "$file" ]] && cmp -s "$tmp" "$file"; then
    info "Block '$name' already up to date in $file"
    rm -f "$tmp"
    return 0
  fi
  info "Updating block '$name' in $file"
  _replace_contents "$file" "$tmp" "$sudo_cmd"
}

# Remove the <name> subblock from the dotfiles section in <file>, if it is there. The section itself is left, even if
# empty. <sudo> is an optional sudo-style prefix, as for upsert_block.
# Usage: remove_block <file> <name> [sudo]
remove_block() {
  local file="$1" name="$2" sudo_cmd="${3:-}"
  local header="$DOTFILES_SUBBLOCK_PREFIX$name"
  [[ -f "$file" ]] && grep -qxF "$header" "$file" || return 0
  if $DRY_RUN; then
    info "[dry-run] would remove block '$name' from $file"
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  awk -v start="$DOTFILES_BLOCK_START" -v end="$DOTFILES_BLOCK_END" \
      -v prefix="$DOTFILES_SUBBLOCK_PREFIX" -v header="$header" '
    $0 == start { insec = 1 }
    insec && $0 == end { insec = 0; skip = 0 }
    insec && index($0, prefix) == 1 { skip = ($0 == header) }
    skip { next }
    { print }
  ' "$file" > "$tmp"
  info "Removing block '$name' from $file"
  _replace_contents "$file" "$tmp" "$sudo_cmd"
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

# --- SteamOS keep lists ---
# Since SteamOS 3.6, an OS update drops every change to /etc that no keep list in this directory names (into
# /etc/previous). Elsewhere it doesn't exist.
STEAMOS_KEEP_DIR=/etc/atomic-update.conf.d
# The keep list dotfiles features share, with one subblock each (see upsert_block).
STEAMOS_KEEP_LIST="$STEAMOS_KEEP_DIR/dotfiles.conf"

# On SteamOS, set feature <name>'s subblock of STEAMOS_KEEP_LIST to the absolute <path>s (with sudo), so OS updates
# keep those files, or remove the subblock if no <path> is given. Does nothing where the keep list directory doesn't
# exist, which is everywhere but SteamOS 3.6 and later.
# Usage: keep_across_steamos_updates <name> [path...]
keep_across_steamos_updates() {
  local name="$1" content="" path
  shift
  [[ -d "$STEAMOS_KEEP_DIR" ]] || return 0
  if [[ $# -eq 0 ]]; then
    forget_across_steamos_updates "$name"
    return
  fi
  for path in "$@"; do
    content+="${content:+$'\n'}$path"
  done
  upsert_block "$STEAMOS_KEEP_LIST" "$name" "$content" "" sudo
}

# Remove feature <name>'s subblock from STEAMOS_KEEP_LIST (with sudo), if the list exists.
# Usage: forget_across_steamos_updates <name>
forget_across_steamos_updates() {
  remove_block "$STEAMOS_KEEP_LIST" "$1" sudo
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

# Return 0 if $file exists and has SHA-256 $sha256.
sha256_matches() {
  local file="$1" sha256="$2"
  [[ -f "$file" ]] && echo "$sha256  $file" | sha256sum -c --status
}

# Download $url to $out and check it against $sha256 ($name is for messages). With DOWNLOAD_CACHE set, a file there
# named $sha256 that matches it is copied instead, and a download is stored there for next time.
download_verified() {
  local url="$1" sha256="$2" out="$3" name="$4"
  local cached="$DOWNLOAD_CACHE/$sha256"
  if $DRY_RUN; then
    info "[dry-run] would download $url"
    return
  fi
  if [[ -n "$DOWNLOAD_CACHE" ]] && sha256_matches "$cached" "$sha256"; then
    info "Using $name from $DOWNLOAD_CACHE"
    cp "$cached" "$out"
    return
  fi
  curl -fsSL -o "$out" "$url" || return 1
  sha256_matches "$out" "$sha256" || { warn "$name checksum mismatch"; return 1; }
  [[ -z "$DOWNLOAD_CACHE" ]] || { mkdir -p "$DOWNLOAD_CACHE" && install -m 644 "$out" "$cached"; } \
    || warn "could not store $name in $DOWNLOAD_CACHE"
}
