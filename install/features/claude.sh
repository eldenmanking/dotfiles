# Feature: Claude Code config (CLAUDE.md, scripts, commands, settings).

# --- Link Claude scripts/commands directories ---
configure_claude_dirs() {
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
      make_symlink "$src_file" "$dst_dir/$filename"
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
      make_symlink "$src" "$dst"
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
# Copy the content between the dotfiles markers in the repo's CLAUDE.md into
# the claude subblock of the target CLAUDE.md.
configure_claude_md() {
  local src="$DOTFILES_ROOT/.claude/CLAUDE.md"
  local dst="$HOME/git/.claude/CLAUDE.md"

  if [[ ! -f "$src" ]]; then
    warn "Source CLAUDE.md not found at $src"
    return
  fi

  local content
  content="$(awk -v ms="$DOTFILES_BLOCK_START" -v me="$DOTFILES_BLOCK_END" '
    $0==me { found=0 }
    found  { print }
    $0==ms { found=1 }
  ' "$src")"

  if [[ -z "$content" ]]; then
    warn "No '$DOTFILES_BLOCK_START' ... '$DOTFILES_BLOCK_END' block found in $src"
    return
  fi

  upsert_block "$dst" claude "$content" '</system-prompt>'
}

# --- Configure Claude Code (orchestrator) ---
feature_claude() {
  configure_claude_md
  configure_claude_dirs
  configure_claude_settings
}
