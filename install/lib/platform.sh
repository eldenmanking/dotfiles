# TODO(andywang): add comment

# --- Platform detection ---
detect_os_arch() {
  f_begin "$FUNCNAME" os arch
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os" in
    Linux)  f_detect_os_arch_os=linux ;;
    Darwin) f_detect_os_arch_os=macos ;;
    *)      error "Unsupported OS: $os" ;;
  esac
  case "$arch" in
    x86_64)        f_detect_os_arch_arch=x86_64 ;;
    aarch64|arm64) f_detect_os_arch_arch=arm64 ;;
    *)             error "Unsupported architecture: $arch" ;;
  esac
  f_end "$FUNCNAME" os arch
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

# TODO(andywang): update comment
detect_shell_rc() {
  f_begin "$FUNCNAME" name rc_file
  local name
  name="$(basename "$SHELL")"
  case "$name" in
    zsh)  f_detect_shell_rc_name=zsh;  f_detect_shell_rc_rc_file="$HOME/.zshrc" ;;
    bash) f_detect_shell_rc_name=bash; f_detect_shell_rc_rc_file="$HOME/.bashrc" ;;
    *)    warn "Unrecognized shell '$name', defaulting to bash/.bashrc"
          f_detect_shell_rc_name=bash; f_detect_shell_rc_rc_file="$HOME/.bashrc" ;;
  esac
  f_end "$FUNCNAME" name rc_file
}
