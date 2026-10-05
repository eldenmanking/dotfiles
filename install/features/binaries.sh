# Features: install binaries into ~/.local without a package manager.

# --- Install neovim ---
install_neovim() {
  if command -v nvim &>/dev/null; then
    info "neovim already available: $(command -v nvim)"
    return
  fi

  f_with_args detect_os_arch os arch
  local os="$_os" arch="$_arch"

  # Use direct GitHub release URL (no API call needed, avoids rate limits).
  # Format: https://github.com/neovim/neovim/releases/latest/download/nvim-<os>-<arch>.tar.gz
  local asset_name
  case "${os}-${arch}" in
    linux-x86_64)  asset_name="nvim-linux-x86_64.tar.gz" ;;
    linux-arm64)   asset_name="nvim-linux-arm64.tar.gz" ;;
    macos-arm64)   asset_name="nvim-macos-arm64.tar.gz" ;;
    macos-x86_64)  asset_name="nvim-macos-x86_64.tar.gz" ;;
    *)             error "No neovim binary available for ${os}-${arch}" ;;
  esac

  local download_url="https://github.com/neovim/neovim/releases/latest/download/${asset_name}"

  local tmp
  tmp="$(mktemp -d)"

  info "Downloading neovim from $download_url ..."
  if ! curl -fSL -o "$tmp/nvim.tar.gz" "$download_url"; then
    warn "Direct download failed, trying GitHub API fallback..."
    local api_pattern="nvim-${os}.*(${arch}|64)\\.tar\\.gz\""
    download_url="$(github_release_url neovim/neovim "$api_pattern")"
    [[ -n "$download_url" ]] || error "Could not find neovim release for ${os}-${arch}"
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

feature_binaries() {
  install_neovim
  install_tmux_binary
}

# --- Install gng ---
feature_gng() {
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
feature_tre() {
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
