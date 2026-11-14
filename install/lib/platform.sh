# Platform detection and GitHub release lookup.

# --- Platform detection ---

# Detect this machine's OS and architecture, as pinned downloads name them.
# Usage: f_call detect_os_arch os arch
# Returns: os arch
#   os: linux or macos
#   arch: x86_64 or arm64
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
