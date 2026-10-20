# Feature: Claude Code config (CLAUDE.md, skills, scripts, settings) from one or more tools repos.

TOOLS_DEFAULT_REPO="https://github.com/eldenmanking/tools.git"

# --- Resolve which tools repos to use ---
# Outputs _tools: one "repo<TAB>dir<TAB>ref" line per tools repo, highest priority first. DOTFILES_TOOLS lists any
# number of repos; without it, DOTFILES_TOOLS_{REPO,DIR,REF} describe a single one. Each variable in the environment
# wins over the same variable set in the config file ($DOTFILES_TOOLS_CONFIG, default ~/.config/dotfiles/tools.conf).
load_tools_config() {
  local conf="${DOTFILES_TOOLS_CONFIG:-$HOME/.config/dotfiles/tools.conf}"
  local file_tools="" file_repo="" file_dir="" file_ref="" spec dir

  if [[ -f "$conf" ]]; then
    # Source in a subshell so the config file can't change this shell's state. DOTFILES_TOOLS may span several lines,
    # so it is printed last and read to the end.
    {
      IFS= read -r file_repo; IFS= read -r file_dir; IFS= read -r file_ref
      file_tools="$(cat)"
    } < <(
      unset DOTFILES_TOOLS DOTFILES_TOOLS_REPO DOTFILES_TOOLS_DIR DOTFILES_TOOLS_REF
      # shellcheck source=/dev/null
      source "$conf"
      printf '%s\n%s\n%s\n%s\n' "${DOTFILES_TOOLS_REPO:-}" "${DOTFILES_TOOLS_DIR:-}" "${DOTFILES_TOOLS_REF:-}" \
        "${DOTFILES_TOOLS:-}"
    )
  fi

  spec="${DOTFILES_TOOLS:-$file_tools}"
  if [[ -n "${spec//[[:space:]]/}" ]]; then
    f_write_args parse_tools_spec _tools -- "$spec"
    return
  fi

  dir="${DOTFILES_TOOLS_DIR:-${file_dir:-$HOME/tools}}"
  _tools="$(printf '%s\t%s\t%s' "${DOTFILES_TOOLS_REPO:-${file_repo:-$TOOLS_DEFAULT_REPO}}" "${dir/#\~/$HOME}" \
    "${DOTFILES_TOOLS_REF:-$file_ref}")"
}

# Parse a DOTFILES_TOOLS list into _tools (see load_tools_config). Each line is "<repo> [dir] [ref]"; blank lines and
# '#' comments are ignored. dir defaults to ~/<repo name>, and "-" keeps that default while still giving a ref.
parse_tools_spec() {
  local spec="$1" nl=$'\n' line repo dir ref extra name dirs="" out=""
  while IFS= read -r line; do
    line="${line%%#*}"
    repo="" dir="" ref="" extra=""
    read -r repo dir ref extra <<< "$line"
    [[ -n "$repo" ]] || continue
    [[ -z "$extra" ]] || error "DOTFILES_TOOLS: expected '<repo> [dir] [ref]', got '$line'"
    if [[ -z "$dir" || "$dir" == "-" ]]; then
      name="${repo%/}"
      name="${name%.git}"
      name="${name##*[/:]}"
      dir="$HOME/$name"
    fi
    dir="${dir/#\~/$HOME}"
    dir="${dir%/}"
    list_contains "$dirs" "$dir" && error "DOTFILES_TOOLS: more than one repo uses $dir; give each its own dir"
    dirs+=" $dir"
    out+="${out:+$nl}$(printf '%s\t%s\t%s' "$repo" "$dir" "$ref")"
  done <<< "$spec"
  _tools="$out"
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
# Takes the tools dirs in priority order: when two repos ship an entry with the same name, the earlier one is linked.
configure_claude_dirs() {
  # Symlink each entry within scripts/ and skills/ so that environment-specific entries in ~/.claude are preserved.
  local dirs=(scripts skills) dir tools_dir
  for dir in "${dirs[@]}"; do
    local dst_dir="$HOME/.claude/$dir" linked="" src name
    for tools_dir in "$@"; do
      local src_dir="$tools_dir/claude/$dir"
      [[ -d "$src_dir" ]] || continue

      # Migrate from old directory-level symlink to per-entry symlinks
      if [[ -L "$dst_dir" ]]; then
        info "Replacing directory symlink $dst_dir with real directory"
        rm "$dst_dir"
      fi
      mkdir -p "$dst_dir"

      for src in "$src_dir"/*; do
        [[ -e "$src" ]] || continue
        name="$(basename "$src")"
        if list_contains "$linked" "$name"; then
          warn "Skipping $src: $dir/$name is already provided by an earlier tools repo"
          continue
        fi
        linked+=" $name"
        make_symlink "$src" "$dst_dir/$name"
      done
    done
  done

  # Clean up broken symlinks into a tools repo (e.g. deleted skills) or the old dotfiles/.claude location.
  local link target
  for dir in scripts skills commands; do
    for link in "$HOME/.claude/$dir"/*; do
      [[ -L "$link" && ! -e "$link" ]] || continue
      target="$(readlink "$link")"
      local stale=false
      [[ "$target" == "$DOTFILES_ROOT/.claude/"* ]] && stale=true
      for tools_dir in "$@"; do
        [[ "$target" == "$tools_dir/claude/"* ]] && stale=true
      done
      if $stale; then
        info "Removing stale symlink: $link -> $target"
        rm "$link"
      fi
    done
  done
}

# --- Merge hooks and permissions into ~/.claude/settings.json ---
# Takes the tools dirs in priority order. Their settings are combined first (earlier repos win scalar conflicts), then
# merged into ~/.claude/settings.json, where the tools values win.
configure_claude_settings() {
  local dst="$HOME/.claude/settings.json" srcs=() tools_dir
  for tools_dir in "$@"; do
    [[ -f "$tools_dir/claude/settings.json" ]] && srcs+=("$tools_dir/claude/settings.json")
  done

  if [[ ${#srcs[@]} -eq 0 ]]; then
    warn "No claude/settings.json found in the tools repos"
    return
  fi

  if ! command -v python3 &>/dev/null; then
    warn "python3 not found, skipping settings merge"
    return
  fi

  mkdir -p "$HOME/.claude"

  python3 - "$dst" "${srcs[@]}" <<'EOF' && info "Settings merged successfully" || warn "Failed to merge settings"
import json, os, shutil, sys

dst_path, src_paths = sys.argv[1], sys.argv[2:]

def deep_merge(src, dst, overwrite, path=''):
    """Recursively merge src into dst and return whether dst changed. Missing keys are added and lists are unioned;
    on a scalar conflict src wins if overwrite, otherwise dst keeps its value."""
    changed = False
    for key, val in src.items():
        current = path + '.' + key if path else key
        if key not in dst:
            dst[key] = val
            changed = True
        elif isinstance(val, dict) and isinstance(dst[key], dict):
            changed = deep_merge(val, dst[key], overwrite, current) or changed
        elif isinstance(val, list) and isinstance(dst[key], list):
            for item in val:
                if item not in dst[key]:
                    dst[key].append(item)
                    changed = True
        elif dst[key] != val:
            if overwrite:
                print(f'[warn] {current}: overwriting with tools repo value', file=sys.stderr)
                dst[key] = val
                changed = True
            else:
                print(f'[warn] {current}: tools repos disagree; keeping the earlier repo\'s value', file=sys.stderr)
    return changed

source = {}
for path in src_paths:
    with open(path) as f:
        deep_merge(json.load(f), source, overwrite=False)

def write(settings):
    with open(dst_path, 'w') as f:
        json.dump(settings, f, indent=2)
        f.write('\n')

if not os.path.exists(dst_path):
    print(f'[info] Creating {dst_path} from the tools repos', file=sys.stderr)
    write(source)
    sys.exit()

with open(dst_path) as f:
    settings = json.load(f)

if deep_merge(source, settings, overwrite=True):
    shutil.copy2(dst_path, dst_path + '.bak')
    print(f'[info] Backed up existing settings to {dst_path}.bak', file=sys.stderr)
    write(settings)
else:
    print('[info] Settings already up to date', file=sys.stderr)
EOF
}

# --- Merge CLAUDE.md block ---
# Takes the tools dirs in priority order and joins their claude/CLAUDE.md files, in that order, into the claude
# subblock of the target CLAUDE.md.
configure_claude_md() {
  local dst="$HOME/git/.claude/CLAUDE.md"

  local tools_dir nl=$'\n' content=""
  for tools_dir in "$@"; do
    [[ -f "$tools_dir/claude/CLAUDE.md" ]] || continue
    content+="${content:+$nl$nl}$(cat "$tools_dir/claude/CLAUDE.md")"
  done

  if [[ -z "$content" ]]; then
    warn "No non-empty claude/CLAUDE.md found in the tools repos"
    return
  fi

  upsert_block "$dst" claude "$content" '</system-prompt>'
}

# --- Configure Claude Code (orchestrator) ---
feature_claude() {
  f_write_args load_tools_config _tools
  if [[ -z "$_tools" ]]; then
    warn "No tools repos configured; skipping Claude Code setup"
    return
  fi

  local repo dir ref tools_dirs=()
  while IFS=$'\t' read -r -u 3 repo dir ref; do
    sync_tools_repo "$repo" "$dir" "$ref"
    tools_dirs+=("$dir")
  done 3<<< "$_tools"

  configure_claude_md "${tools_dirs[@]}"
  configure_claude_dirs "${tools_dirs[@]}"
  configure_claude_settings "${tools_dirs[@]}"
}
