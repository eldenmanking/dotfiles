#!/bin/bash

################################################################################
# Program: light-install.sh
# Description: Lightweight terminal setup for any Linux/macOS system.
#              Configures shell aliases, installs tmux plugins, and optionally
#              installs neovim/tmux from GitHub releases without a package manager.
# Location: ~/dotfiles/light-install.sh
################################################################################

set -euo pipefail

DOTFILES_ROOT="$HOME/dotfiles"
LOCAL_PREFIX="$HOME/.local"
LOCAL_BIN="$LOCAL_PREFIX/bin"

# --- Output helpers ---
info()  { printf '\033[32m[info]\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m[warn]\033[0m %s\n' "$*" >&2; }
error() { printf '\033[31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Lightweight terminal setup script. All operations are idempotent.

Options:
  -s, --shell       Configure shell keybindings (source aliases in shell rc)
  -p, --starship    Add the starship prompt init line to the shell rc
  -z, --zsh         Clone zsh plugins into ~/.zsh and source them in .zshrc
  -t, --tmux        Install tmux plugin manager and plugins
  -i, --install     Install neovim and tmux to ~/.local/bin from GitHub
  -l, --link-config        Symlink neovim and tmux configs into ~
  -b, --link-bin    Symlink executables into $LOCAL_BIN (requires sudo)
  -G, --gng         Install gng (Gradle wrapper) to ~/.local
  -r, --tre         Build and install tre (tree alternative) from source
  -c, --claude      Configure CLAUDE.md, hooks, scripts, and commands
  -g, --gitconfig   Set up default global git config
  -a, --all         Run all of the above
  -h, --help        Show this help message
EOF
}

# --- Flag parsing ---
DO_SHELL=false
DO_STARSHIP=false
DO_ZSH=false
DO_TMUX=false
DO_INSTALL=false
DO_LINK_CONFIG=false
DO_LINK_BIN=false
DO_GNG=false
DO_TRE=false
DO_CLAUDE=false
DO_GITCONFIG=false

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--shell)   DO_SHELL=true;   shift ;;
    -p|--starship) DO_STARSHIP=true; shift ;;
    -z|--zsh)     DO_ZSH=true;     shift ;;
    -t|--tmux)    DO_TMUX=true;    shift ;;
    -i|--install) DO_INSTALL=true; shift ;;
    -l|--link-config)      DO_LINK_CONFIG=true;      shift ;;
    -b|--link-bin)  DO_LINK_BIN=true;  shift ;;
    -G|--gng)       DO_GNG=true;       shift ;;
    -r|--tre)       DO_TRE=true;       shift ;;
    -c|--claude)    DO_CLAUDE=true;    shift ;;
    -g|--gitconfig) DO_GITCONFIG=true; shift ;;
    -a|--all)     DO_SHELL=true; DO_STARSHIP=true; DO_ZSH=true; DO_TMUX=true; DO_INSTALL=true; DO_LINK_CONFIG=true; DO_LINK_BIN=true; DO_GNG=true; DO_TRE=true; DO_CLAUDE=true; DO_GITCONFIG=true; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# --- Platform detection ---
detect_os_arch() {
  OS="$(uname -s)"
  ARCH="$(uname -m)"
  case "$OS" in
    Linux)  OS=linux ;;
    Darwin) OS=macos ;;
    *)      error "Unsupported OS: $OS" ;;
  esac
  case "$ARCH" in
    x86_64)        ARCH=x86_64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    *)             error "Unsupported architecture: $ARCH" ;;
  esac
}

# Fetch the browser_download_url for a GitHub release asset matching a pattern.
# Prefers `gh` CLI (authenticated, higher rate limit) and falls back to curl.
# Usage: github_release_url <owner/repo> <grep-pattern>
github_release_url() {
  local repo="$1" pattern="$2" json
  if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    json="$(gh api "repos/$repo/releases/latest" 2>/dev/null)" || json=""
  fi
  if [[ -z "${json:-}" ]]; then
    json="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null)" || json=""
  fi
  [[ -n "$json" ]] || { warn "Failed to fetch release info for $repo"; return 1; }
  echo "$json" \
    | grep "browser_download_url" \
    | grep -E "$pattern" \
    | head -1 \
    | cut -d'"' -f4
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

# Resolve the login shell's name and rc file into globals SHELL_NAME / RC_FILE.
detect_shell_rc() {
  SHELL_NAME="$(basename "$SHELL")"
  case "$SHELL_NAME" in
    zsh)  RC_FILE="$HOME/.zshrc" ;;
    bash) RC_FILE="$HOME/.bashrc" ;;
    *)    warn "Unrecognized shell '$SHELL_NAME', defaulting to bash/.bashrc"
          SHELL_NAME=bash; RC_FILE="$HOME/.bashrc" ;;
  esac
}

# --- Shell keybindings ---
configure_shell() {
  local all_shell_config=$(cat <<EOF
# global config
source ~/dotfiles/.config/sh/aliases.sh
source ~/dotfiles/.config/sh/env.sh
EOF
)
  local zsh_shell_config=$(cat <<EOF
# zsh config
source ~/dotfiles/.config/zsh/keybindings.zsh
source ~/dotfiles/.config/zsh/settings.zsh
EOF
)

  detect_shell_rc

  local content="$all_shell_config"
  if [[ "$SHELL_NAME" == zsh ]]; then
    content+=$'\n'"$zsh_shell_config"
  fi

  upsert_block "$RC_FILE" shell "$content"
}

# --- Starship prompt ---
# Add the starship init line to the shell rc as a managed block. Assumes the
# starship binary is installed separately (see install.sh --terminal).
configure_starship() {
  if command -v starship &>/dev/null; then
    info "starship already available: $(command -v starship)"
    return
  else
    curl -sS https://starship.rs/install.sh | sh -s -- -y -b $LOCAL_BIN
  fi

  detect_shell_rc
  upsert_block "$RC_FILE" starship "eval \"\$(starship init $SHELL_NAME)\""
}

# --- Zsh plugins ---
# Clone popular zsh plugins into ~/.zsh/plugins and source them from .zshrc.
# Portable: no package manager or root required. Safe to re-run.
configure_zsh_plugins() {
  local plugins_dir="$HOME/.zsh/plugins"

  # Each repo's main script shares the repo's basename (e.g. zsh-autosuggestions.zsh).
  # Order matters: syntax-highlighting must precede history-substring-search.
  local repos=(
    zsh-users/zsh-autosuggestions
    zsh-users/zsh-syntax-highlighting
    zsh-users/zsh-history-substring-search
  )

  mkdir -p "$plugins_dir"

  local content="" repo name
  for repo in "${repos[@]}"; do
    name="${repo##*/}"
    if [[ -d "$plugins_dir/$name" ]]; then
      info "zsh plugin already cloned: $name"
    else
      info "Cloning $name..."
      git clone --depth 1 "https://github.com/$repo" "$plugins_dir/$name"
    fi
    [[ -n "$content" ]] && content+=$'\n'
    content+="source ~/.zsh/plugins/$name/$name.zsh"
  done

  [[ -n "$content" ]] && content+=$'\n'
  content+=$(cat <<EOF
autoload -Uz compinit colors                                    # Autoload these zsh functions when called
compinit -d                                                     # Initialize zsh completion
colors                                                          # Activate color-coding for completion
EOF
)

  upsert_block "$HOME/.zshrc" zsh_plugins "$content"
}

# --- Tmux plugins ---
install_tmux_plugins() {
  local tpm_dir="$HOME/.tmux/plugins/tpm"

  if [[ ! -d "$tpm_dir" ]]; then
    info "Cloning tpm..."
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
  else
    info "tpm already installed"
  fi

  if ! "$tpm_dir/bin/install_plugins" 2>/dev/null; then
    warn "Plugin install failed. Open tmux and press 'prefix + I' to bootstrap plugins, then re-run this script."
  fi
}

# --- Symlink helper ---
# Usage: make_symlink <src> <target> [sudo_cmd]
# Creates a symlink at <target> pointing to <src>. Idempotent.
# Pass "sudo" as the third argument for privileged targets.
make_symlink() {
  local src="$1" target="$2" sudo_cmd="${3:-}"

  if [[ ! -e "$src" ]]; then
    warn "Source does not exist, skipping: $src"
    return
  fi

  if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$src" ]]; then
    info "Already linked: $target"
    return
  fi

  $sudo_cmd mkdir -p "$(dirname "$target")"

  if [[ -e "$target" || -L "$target" ]]; then
    warn "Backing up existing $target to ${target}.bak"
    $sudo_cmd mv "$target" "${target}.bak"
  fi

  $sudo_cmd ln -sv "$src" "$target"
  info "Linked $target -> $src"
}

# --- Link configs ---
link_configs() {
  local paths=(
    .tmux.conf
    .tmux/resurrect/saferestore.sh
    .config/nvim/core/autocommands.vim
    .config/nvim/core/commands.vim
    .config/nvim/core/filetypes.vim
    .config/nvim/core/mappings.vim
    .config/nvim/core/options.vim
    .config/nvim/core/plugins.vim
    .config/nvim/core/plugmaps.vim
    .config/nvim/init.vim
    .config/starship.toml
  )

  for rel in "${paths[@]}"; do
    make_symlink "$DOTFILES_ROOT/$rel" "$HOME/$rel"
  done
}

# --- Link executables ---
link_bin() {
  local paths=(
    .local/bin/vis
    .local/bin/clip
  )

  for rel in "${paths[@]}"; do
    make_symlink "$DOTFILES_ROOT/$rel" "$HOME/$rel"
  done
}

# --- Git config ---
configure_git() {
  if ! command -v git &>/dev/null; then
    warn "git not found, skipping git config"
    return
  fi

  info "Configuring global git settings..."
  git config --global core.excludesFile "$DOTFILES_ROOT/.config/git/ignore"
  # git config --global core.fsmonitor true # This is not compatible with coder
  git config --global core.untrackedCache true
  git config --global credential.helper store
  git config --global feature.manyFiles true
  git config --global fetch.prune true
  git config --global pull.rebase false
  git config --global push.autoSetupRemote true
}

# --- Install neovim ---
install_neovim() {
  if command -v nvim &>/dev/null; then
    info "neovim already available: $(command -v nvim)"
    return
  fi

  detect_os_arch

  # Use direct GitHub release URL (no API call needed, avoids rate limits).
  # Format: https://github.com/neovim/neovim/releases/latest/download/nvim-<os>-<arch>.tar.gz
  local asset_name
  case "${OS}-${ARCH}" in
    linux-x86_64)  asset_name="nvim-linux-x86_64.tar.gz" ;;
    linux-arm64)   asset_name="nvim-linux-arm64.tar.gz" ;;
    macos-arm64)   asset_name="nvim-macos-arm64.tar.gz" ;;
    macos-x86_64)  asset_name="nvim-macos-x86_64.tar.gz" ;;
    *)             error "No neovim binary available for ${OS}-${ARCH}" ;;
  esac

  local download_url="https://github.com/neovim/neovim/releases/latest/download/${asset_name}"

  local tmp
  tmp="$(mktemp -d)"

  info "Downloading neovim from $download_url ..."
  if ! curl -fSL -o "$tmp/nvim.tar.gz" "$download_url"; then
    warn "Direct download failed, trying GitHub API fallback..."
    local api_pattern="nvim-${OS}.*(${ARCH}|64)\\.tar\\.gz\""
    download_url="$(github_release_url neovim/neovim "$api_pattern")"
    [[ -n "$download_url" ]] || error "Could not find neovim release for ${OS}-${ARCH}"
    curl -fSL -o "$tmp/nvim.tar.gz" "$download_url"
  fi

  info "Extracting to $LOCAL_PREFIX..."
  mkdir -p "$LOCAL_PREFIX"
  tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"

  # Merge extracted directory contents into ~/.local/
  local extracted_dir
  extracted_dir="$(find "$tmp" -maxdepth 1 -mindepth 1 -type d | head -1)"
  cp -r "$extracted_dir"/bin "$LOCAL_PREFIX/"
  cp -r "$extracted_dir"/lib "$LOCAL_PREFIX/" 2>/dev/null || true
  cp -r "$extracted_dir"/share "$LOCAL_PREFIX/"

  rm -rf "$tmp"
  info "neovim installed to $LOCAL_BIN/nvim"
}

# --- Install tmux ---
install_tmux_binary() {
  if command -v tmux &>/dev/null; then
    info "tmux already available: $(command -v tmux)"
    return
  fi

  # tmux only provides source tarballs — we need to build from source.
  local missing=()
  for cmd in gcc make pkg-config; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing build dependencies for tmux: ${missing[*]}
Install them first (e.g. apt install build-essential pkg-config libevent-dev ncurses-dev)."
  fi

  info "Fetching latest tmux release URL..."
  local download_url
  download_url="$(github_release_url tmux/tmux "\\.tar\\.gz\"")"
  [[ -n "$download_url" ]] || error "Could not find tmux release tarball"

  local tmp
  tmp="$(mktemp -d)"

  info "Downloading tmux..."
  curl -fSL -o "$tmp/tmux.tar.gz" "$download_url"

  info "Building tmux (prefix=$LOCAL_PREFIX)..."
  tar -xzf "$tmp/tmux.tar.gz" -C "$tmp"

  local src_dir
  src_dir="$(find "$tmp" -maxdepth 1 -mindepth 1 -type d | head -1)"

  (
    cd "$src_dir"
    ./configure --prefix="$LOCAL_PREFIX"
    make
    make install
  )

  rm -rf "$tmp"
  info "tmux installed to $LOCAL_BIN/tmux"
}

# --- Install gng ---
install_gng() {
  if command -v gw &>/dev/null; then
    info "gng already available: $(command -v gw)"
    return
  fi

  local gng_dir="$LOCAL_PREFIX/gng"

  if [[ -d "$gng_dir" ]]; then
    info "gng repo already cloned at $gng_dir"
  else
    info "Cloning gng..."
    git clone https://github.com/gdubw/gng.git "$gng_dir"
  fi

  info "Running gng install script..."
  sudo "$gng_dir/install.sh"

  info "gng installed"
}

# --- Install tre ---
install_tre() {
  if command -v tre &>/dev/null; then
    info "tre already available: $(command -v tre)"
    return
  fi

  # tre is built from source with cargo.
  if ! command -v cargo &>/dev/null; then
    error "cargo not found, required to build tre.
Install Rust and Cargo first (e.g. https://rustup.rs)."
  fi

  local tmp
  tmp="$(mktemp -d)"

  info "Cloning tre..."
  git clone https://github.com/dduan/tre.git "$tmp/tre"

  info "Building tre (cargo build --release)..."
  (
    cd "$tmp/tre"
    cargo build --release
  )

  mkdir -p "$LOCAL_BIN"
  mv "$tmp/tre/target/release/tre" "$LOCAL_BIN/tre"

  rm -rf "$tmp"
  info "tre installed to $LOCAL_BIN/tre"
}

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
configure_claude() {
  configure_claude_md
  configure_claude_dirs
  configure_claude_settings
}

# --- Main ---
if $DO_INSTALL; then
  install_neovim
  install_tmux_binary
fi

if $DO_LINK_CONFIG; then
  link_configs
fi

if $DO_LINK_BIN; then
  link_bin
fi

# Plugins must be configured before the shell block: keybindings.zsh binds keys
# to widgets (e.g. history-substring-search-up) that the plugin block defines,
# and zsh-syntax-highlighting warns about "unhandled ZLE widget" if a keybinding
# references a widget that has not been sourced yet.
if $DO_ZSH; then
  configure_zsh_plugins
fi

if $DO_SHELL; then
  configure_shell
fi

if $DO_STARSHIP; then
  configure_starship
fi

if $DO_TMUX; then
  install_tmux_plugins
fi

if $DO_GNG; then
  install_gng
fi

if $DO_TRE; then
  install_tre
fi

if $DO_CLAUDE; then
  configure_claude
fi

if $DO_GITCONFIG; then
  configure_git
fi

info "Done."
