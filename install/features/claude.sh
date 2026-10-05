# Feature: Claude Code config (CLAUDE.md, scripts, commands, settings).

# --- Link Claude scripts/commands directories ---
configure_claude_dirs() {
  local dry_run="$1"
  # Symlink individual files within scripts/ and commands/ so that
  # environment-specific files in ~/.claude/{scripts,commands} are preserved.
  local dirs=(scripts commands)
  for dir in "${dirs[@]}"; do
    local src_dir="$DOTFILES_ROOT/.claude/$dir"
    local dst_dir="$HOME/.claude/$dir"
    [[ -d "$src_dir" ]] || continue

    # Migrate from old directory-level symlink to per-file symlinks
    if [[ -L "$dst_dir" ]]; then
      info "Replacing directory symlink $dst_dir with real directory"
      rm "$dst_dir"
    fi
    mkdir -p "$dst_dir"

    for src_file in "$src_dir"/*; do
      [[ -e "$src_file" ]] || continue
      local filename
      filename="$(basename "$src_file")"
      make_symlink "$dry_run" "$src_file" "$dst_dir/$filename"
    done

    # Clean up broken symlinks that point into dotfiles (e.g. deleted commands)
    for link in "$dst_dir"/*; do
      [[ -L "$link" ]] || continue
      local target
      target="$(readlink "$link")"
      if [[ "$target" == "$src_dir"/* ]] && [[ ! -e "$link" ]]; then
        info "Removing stale symlink: $link -> $target"
        rm "$link"
      fi
    done
  done

  # Symlink individual files
  local files=(settings.local.json)
  for file in "${files[@]}"; do
    local src="$DOTFILES_ROOT/.claude/$file"
    local dst="$HOME/.claude/$file"
    if [[ -f "$src" ]]; then
      make_symlink "$dry_run" "$src" "$dst"
    fi
  done
}

# --- Merge hooks and permissions into ~/.claude/settings.json ---
configure_claude_settings() {
  local src="$DOTFILES_ROOT/dump/claude/settings.json"
  local dst="$HOME/.claude/settings.json"

  if [[ ! -f "$src" ]]; then
    warn "Settings source not found at $src"
    return
  fi

  if ! command -v python3 &>/dev/null; then
    warn "python3 not found, skipping settings merge"
    return
  fi

  mkdir -p "$HOME/.claude"

  if [[ ! -f "$dst" ]]; then
    info "Creating $dst from dotfiles"
    cp "$src" "$dst"
    return
  fi

  info "Merging settings from dotfiles into $dst"
  python3 -c "
import json, sys

changed = False

def deep_merge(src, dst, path=''):
    \"\"\"Recursively merge src into dst. Dotfiles values win on conflict.\"\"\"
    global changed
    for key, val in src.items():
        current = path + '.' + key if path else key
        if key not in dst:
            dst[key] = val
            changed = True
        elif isinstance(val, dict) and isinstance(dst[key], dict):
            deep_merge(val, dst[key], current)
        elif isinstance(val, list) and isinstance(dst[key], list):
            for item in val:
                if item not in dst[key]:
                    dst[key].append(item)
                    changed = True
        elif dst[key] != val:
            print(f'[warn] {current}: overwriting with dotfiles value', file=sys.stderr)
            dst[key] = val
            changed = True

with open('$dst') as f:
    settings = json.load(f)
with open('$src') as f:
    source = json.load(f)

deep_merge(source, settings)

if changed:
    import shutil
    shutil.copy2('$dst', '${dst}.bak')
    print('[info] Backed up existing settings to ${dst}.bak', file=sys.stderr)
    with open('$dst', 'w') as f:
        json.dump(settings, f, indent=2)
        f.write('\n')
else:
    print('[info] Settings already up to date', file=sys.stderr)
" && info "Settings merged successfully" || warn "Failed to merge settings"
}

# --- Merge CLAUDE.md block ---
configure_claude_md() {
  local src="$DOTFILES_ROOT/.claude/CLAUDE.md"
  local dst="$HOME/git/.claude/CLAUDE.md"
  local marker_start="# Added by dotfiles"
  local marker_end="# /Added by dotfiles"

  if [[ ! -f "$src" ]]; then
    warn "Source CLAUDE.md not found at $src"
    return
  fi

  mkdir -p "$(dirname "$dst")"

  # Extract just the marked block from the dotfiles CLAUDE.md (inclusive of markers).
  local block
  block="$(awk -v ms="$marker_start" -v me="$marker_end" '
    $0==ms { found=1 }
    found  { print }
    $0==me { found=0 }
  ' "$src")"

  if [[ -z "$block" ]]; then
    warn "No '$marker_start' ... '$marker_end' block found in $src"
    return
  fi

  # Content between the markers (without the markers themselves), for comparison.
  local src_content
  src_content="$(awk -v ms="$marker_start" -v me="$marker_end" '
    $0==me { found=0 }
    found  { print }
    $0==ms { found=1 }
  ' "$src")"

  # If markers already exist, check whether the content needs updating.
  if [[ -f "$dst" ]] && grep -qF "$marker_start" "$dst"; then
    local existing
    existing="$(awk -v ms="$marker_start" -v me="$marker_end" '
      $0==ms { found=1; next }
      $0==me { found=0; next }
      found  { print }
    ' "$dst")"
    if [[ "$existing" == "$src_content" ]]; then
      info "CLAUDE.md already up to date in $dst"
      return
    fi
    # Content differs — replace the existing block.
    info "Updating dotfiles CLAUDE.md block in $dst"
    local tmp block_file
    tmp="$(mktemp)"
    block_file="$(mktemp)"
    printf '%s\n' "$block" > "$block_file"
    awk -v ms="$marker_start" -v me="$marker_end" -v bf="$block_file" '
      $0 == ms {
        while ((getline line < bf) > 0) print line
        close(bf)
        skip = 1
        next
      }
      skip && $0 == me { skip = 0; next }
      !skip { print }
    ' "$dst" > "$tmp"
    rm "$block_file"
    mv "$tmp" "$dst"
    return
  fi

  # Fresh insert — no markers present yet.
  if [[ -f "$dst" ]] && grep -q '</system-prompt>' "$dst"; then
    info "Inserting dotfiles CLAUDE.md before </system-prompt> in $dst"
    local tmp
    tmp="$(mktemp)"
    awk -v block="$block" '
      !inserted && /<\/system-prompt>/ {
        print block
        print ""
        inserted=1
      }
      { print }
    ' "$dst" > "$tmp"
    mv "$tmp" "$dst"
  elif [[ -f "$dst" ]]; then
    info "Appending dotfiles CLAUDE.md to $dst"
    printf '\n%s\n' "$block" >> "$dst"
  else
    info "Creating $dst"
    printf '%s\n' "$block" > "$dst"
  fi
}

# --- Configure Claude Code (orchestrator) ---
feature_claude() {
  configure_claude_md
  local dry_run="$3"
  configure_claude_dirs "$dry_run"
  configure_claude_settings
}
