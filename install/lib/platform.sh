# TODO(andywang): add comment

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
