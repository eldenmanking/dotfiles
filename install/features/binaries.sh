# Features: install binaries into ~/.local without a package manager.

NEOVIM_VERSION=v0.12.6
TMUX_VERSION=3.8
TMUX_SHA256=e79c699c7e949dccd0a4a125e17b8d1261e311b16979dbc8eb34542f3966d82e

# Look up the pinned neovim release asset for <os> and <arch>.
# Usage: f_call neovim_asset asset sha256 -- <os> <arch>
# Returns: asset sha256
neovim_asset() {
  case "$1-$2" in
    linux-x86_64) f_return asset=nvim-linux-x86_64.tar.gz sha256=474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87 ;;
    linux-arm64)  f_return asset=nvim-linux-arm64.tar.gz  sha256=8f1f64a0bdb97247034038c3823c6cbad5bdf9ecd5751b85494b71c3ee04c815 ;;
    macos-arm64)  f_return asset=nvim-macos-arm64.tar.gz  sha256=1dbd148222b051ba6c307c4d17a318ed083df018a4f6a5a0ce46955ffc9ab87b ;;
    macos-x86_64) f_return asset=nvim-macos-x86_64.tar.gz sha256=481424f1dbc85f637d57e47d27d042aa9c883e5a4fe9ee64fc4ee9573b221998 ;;
    *)            error "No neovim binary available for $1-$2" ;;
  esac
}

# Download the verified neovim release $1 (asset name) with SHA-256 $2 into the temp dir $3 and merge it into
# $LOCAL_PREFIX.
# Usage: _install_neovim_in <asset> <sha256> <tmp>
_install_neovim_in() {
  local asset="$1" sha256="$2" tmp="$3"
  info "Downloading neovim $NEOVIM_VERSION ($asset)..."
  download_verified "https://github.com/neovim/neovim/releases/download/$NEOVIM_VERSION/$asset" \
    "$sha256" "$tmp/nvim.tar.gz" neovim || error "could not download neovim"

  info "Extracting to $LOCAL_PREFIX..."
  mkdir -p "$LOCAL_PREFIX"
  tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"

  # Merge extracted directory contents into ~/.local/
  local extracted_dir
  extracted_dir="$(find "$tmp" -maxdepth 1 -mindepth 1 -type d | head -1)"
  cp -r "$extracted_dir"/bin "$LOCAL_PREFIX/"
  cp -r "$extracted_dir"/lib "$LOCAL_PREFIX/" 2>/dev/null || true
  cp -r "$extracted_dir"/share "$LOCAL_PREFIX/"
}

# --- Install neovim ---

# Install the pinned neovim release into ~/.local, unless nvim is already available.
# Usage: install_neovim
install_neovim() {
  if command -v nvim &>/dev/null; then
    info "neovim already available: $(command -v nvim)"
    return
  fi

  local os arch asset sha256
  f_call detect_os_arch os arch
  f_call neovim_asset asset sha256 -- "$os" "$arch"

  if $DRY_RUN; then
    info "[dry-run] would download neovim $NEOVIM_VERSION ($asset) and install it to $LOCAL_PREFIX"
    return
  fi

  with_tmpdir _install_neovim_in "$asset" "$sha256"
  info "neovim installed to $LOCAL_BIN/nvim"
}

# Download the verified tmux source tarball into the temp dir $1, then build and install it into $LOCAL_PREFIX.
# Usage: _install_tmux_in <tmp>
_install_tmux_in() {
  local tmp="$1"
  info "Downloading tmux $TMUX_VERSION..."
  download_verified "https://github.com/tmux/tmux/releases/download/$TMUX_VERSION/tmux-$TMUX_VERSION.tar.gz" \
    "$TMUX_SHA256" "$tmp/tmux.tar.gz" tmux || error "could not download tmux"

  info "Building tmux (prefix=$LOCAL_PREFIX)..."
  tar -xzf "$tmp/tmux.tar.gz" -C "$tmp"

  local src_dir
  src_dir="$(find "$tmp" -maxdepth 1 -mindepth 1 -type d | head -1)"

  (
    cd "$src_dir" || exit
    ./configure --prefix="$LOCAL_PREFIX"
    make
    make install
  )
}

# --- Install tmux ---

# Build tmux from its source release into ~/.local, unless it is already available.
# Usage: install_tmux_binary
install_tmux_binary() {
  if command -v tmux &>/dev/null; then
    info "tmux already available: $(command -v tmux)"
    return
  fi

  if $DRY_RUN; then
    info "[dry-run] would download tmux $TMUX_VERSION and build it into $LOCAL_PREFIX"
    return
  fi

  # tmux only provides source tarballs — we need to build from source.
  local cmd missing=()
  for cmd in gcc make pkg-config; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing build dependencies for tmux: ${missing[*]}
Install them first (e.g. apt install build-essential pkg-config libevent-dev ncurses-dev)."
  fi

  with_tmpdir _install_tmux_in
  info "tmux installed to $LOCAL_BIN/tmux"
}

# Install neovim (prebuilt) and tmux (built from source) into ~/.local when they aren't already on the PATH.
#
# @machine any
# @os linux macos
# @gui any
feature_binaries() {
  install_neovim
  install_tmux_binary
}

# Install just neovim (prebuilt) into ~/.local, for installs whose tmux comes from elsewhere (building it needs gcc).
#
# @machine any
# @os linux macos
# @gui any
feature_neovim() {
  install_neovim
}

GNG_VERSION=v1.0.5
GNG_COMMIT=317f7717e1470d22f0c6a26e30534e33b8ad4e52
TRE_VERSION=v0.4.0
TRE_COMMIT=2caab2805d14340b71118d7d6c02b8ff340d8e54

# Clone gng (a Gradle wrapper launcher, run as gw) at a pinned commit into ~/.local/gng and run its installer with sudo.
#
# @machine any
# @os any
# @gui any
feature_gng() {
  if command -v gw &>/dev/null; then
    info "gng already available: $(command -v gw)"
    return
  fi

  local gng_dir="$LOCAL_PREFIX/gng"

  if $DRY_RUN; then
    info "[dry-run] would fetch gng $GNG_VERSION into $gng_dir and run its install script with sudo"
    return
  fi

  # Whatever is cloned is checked out at the pinned commit before its installer runs as root.
  info "Fetching gng $GNG_VERSION..."
  clone_pinned https://github.com/gdubw/gng.git "$GNG_COMMIT" "$gng_dir"

  info "Running gng install script..."
  run sudo "$gng_dir/install.sh"

  info "gng installed"
}

# Build tre from a pinned commit cloned into the temp dir $1 and install it to $LOCAL_BIN.
# Usage: _install_tre_in <tmp>
_install_tre_in() {
  local tmp="$1"
  info "Cloning tre $TRE_VERSION..."
  clone_pinned https://github.com/dduan/tre.git "$TRE_COMMIT" "$tmp/tre"

  info "Building tre (cargo build --release)..."
  (
    cd "$tmp/tre" || exit
    cargo build --release
  )

  mkdir -p "$LOCAL_BIN"
  mv "$tmp/tre/target/release/tre" "$LOCAL_BIN/tre"
}

# Build tre (a tree alternative) from a pinned commit with cargo and install it to ~/.local/bin.
#
# @machine any
# @os any
# @gui any
feature_tre() {
  if command -v tre &>/dev/null; then
    info "tre already available: $(command -v tre)"
    return
  fi

  # tre is built from source with cargo.
  if $DRY_RUN && ! command -v cargo &>/dev/null; then
    warn "cargo not found; a real install would fail"
  elif ! command -v cargo &>/dev/null; then
    error "cargo not found, required to build tre.
Install Rust and Cargo first (e.g. https://rustup.rs)."
  fi

  if $DRY_RUN; then
    info "[dry-run] would build tre $TRE_VERSION with cargo and install it to $LOCAL_BIN/tre"
    return
  fi

  with_tmpdir _install_tre_in
  info "tre installed to $LOCAL_BIN/tre"
}
