# Feature: Claude Code config (CLAUDE.md, skills, scripts, settings) from the tools repo.

TOOLS_DEFAULT_REPO="https://github.com/eldenmanking/tools.git"

# --- Resolve which tools repo instance to use ---
# Sets TOOLS_REPO, TOOLS_DIR and TOOLS_REF. DOTFILES_TOOLS_{REPO,DIR,REF} in the environment win over the same
# variables set in the config file ($DOTFILES_TOOLS_CONFIG, default ~/.config/dotfiles/tools.conf).
load_tools_config() {
  local conf="${DOTFILES_TOOLS_CONFIG:-$HOME/.config/dotfiles/tools.conf}"
  local env_repo="${DOTFILES_TOOLS_REPO:-}" env_dir="${DOTFILES_TOOLS_DIR:-}" env_ref="${DOTFILES_TOOLS_REF:-}"

  if [[ -f "$conf" ]]; then
    # shellcheck source=/dev/null
    source "$conf"
  fi

  TOOLS_REPO="${env_repo:-${DOTFILES_TOOLS_REPO:-$TOOLS_DEFAULT_REPO}}"
  TOOLS_DIR="${env_dir:-${DOTFILES_TOOLS_DIR:-$HOME/tools}}"
  TOOLS_REF="${env_ref:-${DOTFILES_TOOLS_REF:-}}"
  TOOLS_DIR="${TOOLS_DIR/#\~/$HOME}"
}

# Print a git remote URL as host/path so https and ssh forms of the same repo compare equal.
normalize_git_url() {
  local url="${1%.git}"
  url="${url#*://}"
  url="${url#*@}"
  printf '%s' "${url/://}"
}

# --- Clone or update the tools repo ---
# A TOOLS_DIR that exists but isn't a git checkout is used as-is, so a local copy can stand in for the repo.
sync_tools_repo() {
  if [[ -d "$TOOLS_DIR/.git" ]]; then
    local origin
    origin="$(git -C "$TOOLS_DIR" remote get-url origin 2>/dev/null || true)"
    if [[ "$(normalize_git_url "$origin")" != "$(normalize_git_url "$TOOLS_REPO")" ]]; then
      warn "$TOOLS_DIR tracks '$origin', not '$TOOLS_REPO'; using it without updating"
      return
    fi
    info "Updating tools repo at $TOOLS_DIR"
    if [[ -n "$TOOLS_REF" ]]; then
      git -C "$TOOLS_DIR" fetch --quiet origin "$TOOLS_REF" \
        && git -C "$TOOLS_DIR" checkout --quiet "$TOOLS_REF" \
        || warn "Failed to check out '$TOOLS_REF' in $TOOLS_DIR"
    fi
    git -C "$TOOLS_DIR" pull --quiet --ff-only 2>/dev/null \
      || warn "Could not fast-forward $TOOLS_DIR; using it as-is"
  elif [[ -d "$TOOLS_DIR" ]]; then
    info "Using tools directory $TOOLS_DIR as-is (not a git checkout)"
  else
    info "Cloning $TOOLS_REPO into $TOOLS_DIR"
    git clone --quiet ${TOOLS_REF:+--branch "$TOOLS_REF"} "$TOOLS_REPO" "$TOOLS_DIR" \
      || error "Failed to clone $TOOLS_REPO"
  fi
}

# --- Link Claude scripts and skills ---
configure_claude_dirs() {
  # Symlink each entry within scripts/ and skills/ so that environment-specific entries in ~/.claude are preserved.
  local dirs=(scripts skills) dir
  for dir in "${dirs[@]}"; do
    local src_dir="$TOOLS_DIR/claude/$dir"
    local dst_dir="$HOME/.claude/$dir"
    [[ -d "$src_dir" ]] || continue

    # Migrate from old directory-level symlink to per-entry symlinks
    if [[ -L "$dst_dir" ]]; then
      info "Replacing directory symlink $dst_dir with real directory"
      rm "$dst_dir"
    fi
    mkdir -p "$dst_dir"

    local src
    for src in "$src_dir"/*; do
      [[ -e "$src" ]] || continue
      make_symlink "$src" "$dst_dir/$(basename "$src")"
    done
  done

  # Clean up broken symlinks into the tools repo (e.g. deleted skills) or the old dotfiles/.claude location.
  local link target
  for dir in scripts skills commands; do
    for link in "$HOME/.claude/$dir"/*; do
      [[ -L "$link" && ! -e "$link" ]] || continue
      target="$(readlink "$link")"
      if [[ "$target" == "$TOOLS_DIR/claude/"* || "$target" == "$DOTFILES_ROOT/.claude/"* ]]; then
        info "Removing stale symlink: $link -> $target"
        rm "$link"
      fi
    done
  done
}

# --- Merge hooks and permissions into ~/.claude/settings.json ---
configure_claude_settings() {
  local src="$TOOLS_DIR/claude/settings.json"
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
  local src="$TOOLS_DIR/claude/CLAUDE.md"
  local dst="$HOME/git/.claude/CLAUDE.md"
  local marker_start="# Added by dotfiles"
  local marker_end="# /Added by dotfiles"

  if [[ ! -f "$src" ]]; then
    warn "Source CLAUDE.md not found at $src"
    return
  fi

  mkdir -p "$(dirname "$dst")"

  local src_content block
  src_content="$(cat "$src")"
  block="$(printf '%s\n%s\n%s' "$marker_start" "$src_content" "$marker_end")"

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
  load_tools_config
  sync_tools_repo
  configure_claude_md
  configure_claude_dirs
  configure_claude_settings
}
