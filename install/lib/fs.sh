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
      run_tty $sudo_cmd mv -vi "$target" "$BACKUPS_ROOT$target"
    else
      run $sudo_cmd mv -v "$target" "$BACKUPS_ROOT$target"
    fi
  fi

  run $sudo_cmd ln -snfv "$src" "$target"
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
# The section is ours: unlabeled lines inside it (e.g. from an older format)
# are dropped on update.
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

# Remove an old-format "# Added by light-install.sh#<name>" block, if present.
# Usage: remove_legacy_block <file> <name>
remove_legacy_block() {
  local file="$1" name="$2"
  local start="# Added by light-install.sh#$name"
  local end="# /Added by light-install.sh#$name"
  [[ -f "$file" ]] || return 0

  local starts ends
  starts="$(_line_numbers "$file" "$start")"
  ends="$(_line_numbers "$file" "$end")"
  [[ -z "$starts" && -z "$ends" ]] && return 0
  if [[ "$starts" == *$'\n'* || "$ends" == *$'\n'* || -z "$starts" || -z "$ends" ]] \
    || (( starts > ends )); then
    warn "Malformed legacy block '$name' in $file; remove it by hand"
    return 1
  fi

  if $DRY_RUN; then
    info "[dry-run] would remove legacy block '$name' from $file"
    return 0
  fi
  info "Removing legacy block '$name' from $file"
  local tmp
  tmp="$(mktemp)"
  # Also drop the blank line the old helper wrote before each block.
  awk -v s="$starts" -v e="$ends" '
    NR == s - 1 && $0 == "" { next }
    NR >= s && NR <= e { next }
    { print }
  ' "$file" > "$tmp"
  _replace_contents "$file" "$tmp"
}

# Rename old "# Added by dotfiles" section markers to the current ones, unless
# the file already has a current section.
# Usage: rename_legacy_section <file>
rename_legacy_section() {
  local file="$1"
  local start="# Added by dotfiles" end="# /Added by dotfiles"
  [[ -f "$file" ]] || return 0
  [[ -n "$(_line_numbers "$file" "$start")" ]] || return 0
  [[ -z "$(_line_numbers "$file" "$DOTFILES_BLOCK_START")" ]] || return 0

  if $DRY_RUN; then
    info "[dry-run] would rename legacy dotfiles section markers in $file"
    return 0
  fi
  info "Renaming legacy dotfiles section markers in $file"
  local tmp
  tmp="$(mktemp)"
  awk -v os="$start" -v oe="$end" -v ns="$DOTFILES_BLOCK_START" -v ne="$DOTFILES_BLOCK_END" '
    $0 == os { print ns; next }
    $0 == oe { print ne; next }
    { print }
  ' "$file" > "$tmp"
  _replace_contents "$file" "$tmp"
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

  remove_legacy_block "$file" "$name" || return 1
  rename_legacy_section "$file"

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
  tmp="$(mktemp)"
  content_file="$(mktemp)"
  printf '%s\n' "$content" > "$content_file"

  if [[ -z "$starts" ]]; then
    # No section yet: write one holding just this subblock.
    local section
    section="$(printf '%s\n\n%s\n%s\n\n%s' "$DOTFILES_BLOCK_START" "$header" "$content" "$DOTFILES_BLOCK_END")"
    printf '%s\n' "$section" > "$content_file"
    if [[ -f "$file" && -n "$insert_before" ]] && grep -qF "$insert_before" "$file"; then
      info "Adding block '$name' before '$insert_before' in $file"
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
      info "Adding block '$name' to $file"
      mkdir -p "$(dirname "$file")"
      [[ -s "$file" ]] && printf '\n' >> "$file"
      cat "$content_file" >> "$file"
      rm -f "$tmp"
    fi
    rm -f "$content_file"
    return 0
  fi

  # Rebuild the section in place, replacing or appending this subblock and
  # keeping the others (and their order) as they are.
  awk -v start="$DOTFILES_BLOCK_START" -v end="$DOTFILES_BLOCK_END" \
      -v prefix="$DOTFILES_SUBBLOCK_PREFIX" -v name="$name" -v cf="$content_file" '
    BEGIN {
      while ((getline line < cf) > 0) new = new line "\n"
      close(cf)
    }
    $0 == start { insec = 1; next }
    insec && $0 == end {
      insec = 0
      for (i = 1; i <= n && names[i] != name; i++) ;
      if (i > n) { n++; names[n] = name }
      bodies[i] = new
      print start
      print ""
      for (i = 1; i <= n; i++) {
        print prefix names[i]
        printf "%s", bodies[i]
        print ""
      }
      print end
      next
    }
    insec && index($0, prefix) == 1 {
      nm = substr($0, length(prefix) + 1)
      for (cur = 1; cur <= n && names[cur] != nm; cur++) ;
      if (cur > n) { n++; names[n] = nm; bodies[n] = "" }
      pending = ""
      next
    }
    insec {
      # Hold blank lines until more content follows, so subblocks do not
      # accumulate trailing blanks.
      if ($0 ~ /^[ \t]*$/) { if (cur) pending = pending $0 "\n"; next }
      if (!cur) { dropped++; next }
      bodies[cur] = bodies[cur] pending $0 "\n"
      pending = ""
      next
    }
    { print }
    END {
      if (dropped) printf "%d unlabeled line(s) dropped from the dotfiles section\n", dropped > "/dev/stderr"
    }
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
