# Platform and shell detection.

# --- Platform detection ---
detect_os_arch() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os" in
    Linux)  _os=linux ;;
    Darwin) _os=macos ;;
    *)      error "Unsupported OS: $os" ;;
  esac
  case "$arch" in
    x86_64)        _arch=x86_64 ;;
    aarch64|arm64) _arch=arm64 ;;
    *)             error "Unsupported architecture: $arch" ;;
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

# Resolve the login shell into _name and _rc_file.
detect_shell_rc() {
  local name
  name="$(basename "$SHELL")"
  case "$name" in
    zsh)  _name=zsh;  _rc_file="$HOME/.zshrc" ;;
    bash) _name=bash; _rc_file="$HOME/.bashrc" ;;
    *)    warn "Unrecognized shell '$name', defaulting to bash/.bashrc"
          _name=bash; _rc_file="$HOME/.bashrc" ;;
  esac
}
