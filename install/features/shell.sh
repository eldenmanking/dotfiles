# Features: shell startup file blocks, starship prompt and zsh plugins.

# Write managed blocks into the profiles, .bashrc and .zshrc that source the shared config in home/.config/sh
# and home/.config/zsh.
#
# @machine any
# @os any
# @gui any
feature_shell() {
  local sh_files=(home/.config/sh/env.sh home/.config/sh/aliases.sh)
  local zsh_files=(home/.config/zsh/keybindings.zsh home/.config/zsh/settings.zsh home/.config/zsh/external.zsh)

  # Login shells load the environment from a profile; bash ignores ~/.profile when ~/.bash_profile exists.
  upsert_sources "$HOME/.profile" shell home/.config/sh/env.sh
  upsert_sources "$HOME/.zprofile" shell home/.config/sh/env.sh
  if [[ -f "$HOME/.bash_profile" ]]; then
    upsert_sources "$HOME/.bash_profile" shell home/.config/sh/env.sh
  fi

  # rc files source env.sh too, for shells with no login shell above them. Write both rc files so switching shells
  # keeps the config.
  upsert_sources "$HOME/.bashrc" shell "${sh_files[@]}"
  upsert_sources "$HOME/.zshrc" shell "${sh_files[@]}" "${zsh_files[@]}"
}

STARSHIP_VERSION=v1.27.0

# Look up the pinned starship release asset for <os> and <arch>.
# Usage: f_call starship_asset asset sha256 -- <os> <arch>
# Returns: asset sha256
starship_asset() {
  case "$1-$2" in
    linux-x86_64) f_return asset=starship-x86_64-unknown-linux-musl.tar.gz sha256=10c8eb4cb3b761d9bf59ea828444c2dab36c900b7d69a69e08814b286969df89 ;;
    linux-arm64)  f_return asset=starship-aarch64-unknown-linux-musl.tar.gz sha256=341f5cbf24699fa0b27ec88965ad25f862ea09e15d35a543fd6ffdff1d2aa00d ;;
    macos-x86_64) f_return asset=starship-x86_64-apple-darwin.tar.gz sha256=344e4d38787e0aa86dd522ae5462e6fb6da1227691f81a79ffed480a4563ccb3 ;;
    macos-arm64)  f_return asset=starship-aarch64-apple-darwin.tar.gz sha256=5362da8cb2928f98f3ce0ffda697cf0f8de70081db000dae316d6d3a404f6cf0 ;;
    *)            error "No starship binary available for $1-$2" ;;
  esac
}

# Download the verified starship release $1 (asset name) with SHA-256 $2 into the temp dir $4 and install it into the
# directory $3.
# Usage: _install_starship_in <asset> <sha256> <bin_dir> <tmp>
_install_starship_in() {
  local asset="$1" sha256="$2" bin_dir="$3" tmp="$4"
  download_verified "https://github.com/starship/starship/releases/download/$STARSHIP_VERSION/$asset" \
    "$sha256" "$tmp/starship.tar.gz" starship || error "could not download starship"
  tar -xzf "$tmp/starship.tar.gz" -C "$tmp" starship
  mkdir -p "$bin_dir"
  install -m 755 "$tmp/starship" "$bin_dir/starship"
}

# Install the pinned starship into the directory $1 if it's missing.
# Usage: install_starship_binary <bin_dir>
install_starship_binary() {
  local bin_dir="$1" os arch asset sha256
  if command -v starship &>/dev/null; then
    info "starship already available: $(command -v starship)"
    return
  fi
  f_call detect_os_arch os arch
  f_call starship_asset asset sha256 -- "$os" "$arch"
  if $DRY_RUN; then
    info "[dry-run] would install starship $STARSHIP_VERSION ($asset) to $bin_dir"
    return
  fi
  info "Downloading starship $STARSHIP_VERSION ($asset)..."
  with_tmpdir _install_starship_in "$asset" "$sha256" "$bin_dir"
}

# Install starship to ~/.local/bin if missing and start it from .bashrc and .zshrc.
#
# @machine any
# @os any
# @gui any
feature_starship() {
  install_starship_binary "$LOCAL_BIN"

  upsert_sources "$HOME/.bashrc" starship home/.config/sh/starship.sh
  upsert_sources "$HOME/.zshrc" starship home/.config/sh/starship.sh
}

# Clone popular zsh plugins into ~/.zsh/plugins and source plugins.zsh (which loads them) from .zshrc. Portable:
# no package manager or root required.
#
# @machine any
# @os any
# @gui any
feature_zsh() {
  local plugins_dir="$HOME/.zsh/plugins"

  # Keep in sync with the plugin list in home/.config/zsh/plugins.zsh.
  local repos=(
    zsh-users/zsh-autosuggestions
    zsh-users/zsh-syntax-highlighting
    zsh-users/zsh-history-substring-search
  )

  mkdir -p "$plugins_dir"

  local repo name
  for repo in "${repos[@]}"; do
    name="${repo##*/}"
    if [[ -d "$plugins_dir/$name" ]]; then
      info "zsh plugin already cloned: $name"
    else
      info "Cloning $name..."
      git clone --depth 1 "https://github.com/$repo" "$plugins_dir/$name"
    fi
  done

  upsert_sources "$HOME/.zshrc" zsh home/.config/zsh/plugins.zsh
}
