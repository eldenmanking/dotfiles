# Platform detection and GitHub release lookup.

# --- Platform detection ---
detect_os_arch() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os" in
    Linux)  f_return os=linux ;;
    Darwin) f_return os=macos ;;
    *)      error "Unsupported OS: $os" ;;
  esac
  case "$arch" in
    x86_64)        f_return arch=x86_64 ;;
    aarch64|arm64) f_return arch=arm64 ;;
    *)             error "Unsupported architecture: $arch" ;;
  esac
}
