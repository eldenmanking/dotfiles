# Shared helpers for tests/install.sh, tests/lint and tests/validation.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$TEST_DIR")"
TOOLS_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-test"

# shellcheck source=../install/lib/output.sh
source "$REPO_ROOT/install/lib/output.sh"
# shellcheck source=../install/lib/fn.sh
source "$REPO_ROOT/install/lib/fn.sh"
# shellcheck source=../install/lib/platform.sh
source "$REPO_ROOT/install/lib/platform.sh"
# shellcheck source=versions.env
source "$TEST_DIR/versions.env"

# Print the SHA-256 of $1 (sha256sum on Linux, shasum on macOS).
sha256_of() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# Outputs: _url and _sha256 of the release archive of pinned tool $1 (shellcheck or actionlint) for os $2, arch $3.
tool_release() {
  local tool="$1" os="$2" arch="$3" version sha_var sc_os sc_arch al_arch
  case "$os" in linux) sc_os=linux ;; macos) sc_os=darwin ;; esac
  case "$arch" in x86_64) sc_arch=x86_64 al_arch=amd64 ;; arm64) sc_arch=aarch64 al_arch=arm64 ;; esac
  case "$tool" in
    shellcheck)
      version="$SHELLCHECK_VERSION"
      sha_var="SHELLCHECK_SHA256_${os}_${arch}"
      _url="https://github.com/koalaman/shellcheck/releases/download/v$version/shellcheck-v$version.$sc_os.$sc_arch.tar.xz"
      ;;
    actionlint)
      version="$ACTIONLINT_VERSION"
      sha_var="ACTIONLINT_SHA256_${os}_${arch}"
      _url="https://github.com/rhysd/actionlint/releases/download/v$version/actionlint_${version}_${sc_os}_$al_arch.tar.gz"
      ;;
    *) error "tool_release: unknown tool '$tool'" ;;
  esac
  _sha256="${!sha_var:-}"
  [[ -n "$_sha256" ]] || error "tool_release: no checksum for $tool on $os-$arch in tests/versions.env"
}

# Outputs: _path, the pinned tool $1, downloaded and checksummed into TOOLS_CACHE on first use.
pinned_tool() {
  local tool="$1" version_var dir bin tmp
  version_var="$(printf '%s' "$tool" | tr '[:lower:]' '[:upper:]')_VERSION"
  dir="$TOOLS_CACHE/$tool-${!version_var}"
  bin="$dir/$tool"
  if [[ ! -x "$bin" ]]; then
    f_write_args detect_os_arch _os _arch
    f_write_args tool_release _url _sha256 -- "$tool" "$_os" "$_arch"
    info "Downloading $tool ${!version_var}..."
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/archive" "$_url" || error "could not download $_url"
    [[ "$(sha256_of "$tmp/archive")" == "$_sha256" ]] || error "$tool checksum mismatch for $_url"
    tar -xf "$tmp/archive" -C "$tmp"
    mkdir -p "$dir"
    mv "$(find "$tmp" -type f -name "$tool" | head -1)" "$bin"
    rm -rf "$tmp"
  fi
  _path="$bin"
}

# Return 0 if command $1 exists. Otherwise warn that check $2 is skipped and return 1, or fail under CI, where every
# check must run.
have_or_skip() {
  command -v "$1" >/dev/null && return 0
  [[ -z "${CI:-}" ]] || error "$1 is required for $2"
  warn "$1 not found; skipping $2"
  return 1
}
