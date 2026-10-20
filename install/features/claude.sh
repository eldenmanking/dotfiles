# Feature: Claude Code config (CLAUDE.md, skills, scripts, settings) from the tools repo.

TOOLS_DEFAULT_REPO="https://github.com/eldenmanking/tools.git"

# --- Resolve which tools repo instance to use ---
# Outputs _repo, _dir and _ref. DOTFILES_TOOLS_{REPO,DIR,REF} in the environment win over the same variables set in
# the config file ($DOTFILES_TOOLS_CONFIG, default ~/.config/dotfiles/tools.conf).
load_tools_config() {
  local conf="${DOTFILES_TOOLS_CONFIG:-$HOME/.config/dotfiles/tools.conf}"
  local file_repo="" file_dir="" file_ref="" dir

  if [[ -f "$conf" ]]; then
    # Source in a subshell so the config file can't change this shell's state.
    { IFS= read -r file_repo; IFS= read -r file_dir; IFS= read -r file_ref; } < <(
      unset DOTFILES_TOOLS_REPO DOTFILES_TOOLS_DIR DOTFILES_TOOLS_REF
      # shellcheck source=/dev/null
      source "$conf"
      printf '%s\n%s\n%s\n' "${DOTFILES_TOOLS_REPO:-}" "${DOTFILES_TOOLS_DIR:-}" "${DOTFILES_TOOLS_REF:-}"
    )
  fi

  dir="${DOTFILES_TOOLS_DIR:-${file_dir:-$HOME/tools}}"
  _repo="${DOTFILES_TOOLS_REPO:-${file_repo:-$TOOLS_DEFAULT_REPO}}"
  _dir="${dir/#\~/$HOME}"
  _ref="${DOTFILES_TOOLS_REF:-$file_ref}"
}

# Print a git remote URL as host/path so https and ssh forms of the same repo compare equal.
normalize_git_url() {
  local url="${1%.git}"
  url="${url#*://}"
  url="${url#*@}"
  printf '%s' "${url/://}"
}

# --- Clone or update the tools repo ---
# A tools_dir that exists but isn't a git checkout is used as-is, so a local copy can stand in for the repo.
sync_tools_repo() {
  local tools_repo="$1" tools_dir="$2" tools_ref="$3"
  if [[ -d "$tools_dir/.git" ]]; then
    local origin
    origin="$(git -C "$tools_dir" remote get-url origin 2>/dev/null || true)"
    if [[ "$(normalize_git_url "$origin")" != "$(normalize_git_url "$tools_repo")" ]]; then
      warn "$tools_dir tracks '$origin', not '$tools_repo'; using it without updating"
      return
    fi
    info "Updating tools repo at $tools_dir"
    if [[ -n "$tools_ref" ]]; then
      git -C "$tools_dir" fetch --quiet origin "$tools_ref" \
        && git -C "$tools_dir" checkout --quiet "$tools_ref" \
        || warn "Failed to check out '$tools_ref' in $tools_dir"
    fi
    git -C "$tools_dir" pull --quiet --ff-only 2>/dev/null \
      || warn "Could not fast-forward $tools_dir; using it as-is"
  elif [[ -d "$tools_dir" ]]; then
    info "Using tools directory $tools_dir as-is (not a git checkout)"
  else
    info "Cloning $tools_repo into $tools_dir"
    git clone --quiet ${tools_ref:+--branch "$tools_ref"} "$tools_repo" "$tools_dir" \
      || error "Failed to clone $tools_repo"
  fi
}

# --- Link Claude scripts and skills ---
configure_claude_dirs() {
  local tools_dir="$1"
  # Symlink each entry within scripts/ and skills/ so that environment-specific entries in ~/.claude are preserved.
  local dirs=(scripts skills) dir
  for dir in "${dirs[@]}"; do
    local src_dir="$tools_dir/claude/$dir"
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
      if [[ "$target" == "$tools_dir/claude/"* || "$target" == "$DOTFILES_ROOT/.claude/"* ]]; then
        info "Removing stale symlink: $link -> $target"
        rm "$link"
      fi
    done
  done
}

# --- Merge hooks and permissions into ~/.claude/settings.json ---
configure_claude_settings() {
  local tools_dir="$1"
  local src="$tools_dir/claude/settings.json"
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
  local tools_dir="$1"
  local src="$tools_dir/claude/CLAUDE.md"
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
  f_write_args load_tools_config _repo _dir _ref
  sync_tools_repo "$_repo" "$_dir" "$_ref"
  configure_claude_md "$_dir"
  configure_claude_dirs "$_dir"
  configure_claude_settings "$_dir"
}
