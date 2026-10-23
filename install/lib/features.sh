# Feature and variant registry helpers.

feature_description() {
  case "$1" in
    all)         echo "install all options" ;;
    pacman)      echo "install pacman packages" ;;
    yay)         echo "install yay packages" ;;
    terminal)    echo "install terminal packages" ;;
    font)        echo "install JetBrainsMono Nerd Font to ~/.local/share/fonts" ;;
    printer)     echo "install and set up HP printer drivers" ;;
    logiops)     echo "install and configure logitech software" ;;
    link)        echo "symlink the variant's dotfiles into ~ (root/ into /)" ;;
    services)    echo "enable and start custom services" ;;
    manual)      echo "make manual substitutions to files in-place" ;;
    dconf)       echo "load dconf configuration" ;;
    xdg)         echo "load default xdg configuration" ;;
    info)        echo "provide info on manual configuration tasks" ;;
    shell)       echo "source the shared shell config from the profiles, .bashrc and .zshrc" ;;
    starship)    echo "install starship and add its init line to .bashrc and .zshrc" ;;
    zsh)         echo "clone zsh plugins into ~/.zsh and source them in .zshrc" ;;
    tmux)        echo "install tmux plugin manager and plugins" ;;
    binaries)    echo "install neovim and tmux to ~/.local/bin from GitHub" ;;
    neovim)      echo "install neovim to ~/.local/bin from GitHub" ;;
    gng)         echo "install gng (Gradle wrapper) to ~/.local" ;;
    tre)         echo "build and install tre (tree alternative) from source" ;;
    claude)      echo "install CLAUDE.md, skills, scripts, and settings from the tools repos" ;;
    gitconfig)   echo "set up default global git config" ;;
    flatpak)     echo "install flatpak apps from flathub (per-user)" ;;
    udev)        echo "copy root/etc/udev rules into /etc (not symlinked) and reload udev" ;;
    tmpfiles)    echo "copy root/etc/tmpfiles.d configs into /etc (not symlinked) and apply them" ;;
    steamos_xclip) echo "install xclip to ~/.local/bin by copying it out of the 'arch' distrobox (created if missing, then kept)" ;;
    webterm)     echo "download ttyd and install the webterm systemd user units (browser shell on localhost)" ;;
    home_units)  echo "install home-units.service into /etc (sudo, only if the home is encrypted with dirlock)" ;;
    kde)         echo "merge partial KDE config files (e.g. home/.config/kcminputrc) into ~/.config with kwriteconfig" ;;
    distrobox)   echo "create an 'arch' distrobox from archlinux:latest and enter it" ;;
    *)           echo "" ;;
  esac
}

# Values the requirement tags may use.
FEATURE_MACHINES="any laptop framework16"
FEATURE_OSES="any linux macos arch steamos"
FEATURE_GUIS="any desktop gnome kde"

# Outputs: _doc, the comment block directly above feature $1's feature_<name> function in install/features, with
# each line's leading '#' and one space removed. A feature's doc is a description, a bare '#' line, then its tags:
#   # Install the thing for x.
#   #
#   # @machine any
#   # @os linux
#   # @gui gnome
feature_doc() {
  local fn line doc="" nl=$'\n' first=true
  fn="$(feature_function "$1")"
  while IFS= read -r line; do
    line="${line#\#}"
    $first || doc+="$nl"
    doc+="${line# }"
    first=false
  done < <(awk -v fn="$fn" '
    FNR == 1 { block = "" }
    /^#/ { block = block $0 "\n"; next }
    index($0, fn "()") == 1 { printf "%s", block; exit }
    { block = "" }
  ' "$INSTALL_DIR"/features/*.sh)
  _doc="$doc"
}

# Where feature $1 works and which features it needs, read from the tags in its doc (see feature_doc). Outputs
# (space-separated lists, empty when the tag is missing):
#  _machine: @machine, hardware it is for: any, laptop, framework16
#  _os: @os, any, linux, macos, arch, steamos (linux covers arch and steamos)
#  _gui: @gui, any (also headless), desktop (any graphical session), gnome, kde
#  _requires: @requires (optional), features that must run before it in the same variant
# Each variant sets the _os and _gui it targets (lists, each entry is checked); tests/validation/features.sh requires the
# description and tags on every feature, checks every variant's features against them and that each feature's
# _requires come earlier in its _features.
feature_requirements() {
  local line machine="" os="" gui="" requires=""
  f_write_args feature_doc _doc -- "$1"
  while IFS= read -r line; do
    case "$line" in
      "@machine "*)  machine="${line#@machine }" ;;
      "@os "*)       os="${line#@os }" ;;
      "@gui "*)      gui="${line#@gui }" ;;
      "@requires "*) requires="${line#@requires }" ;;
    esac
  done <<< "$_doc"
  _machine="$machine"
  _os="$os"
  _gui="$gui"
  _requires="$requires"
}

# Return 0 if a feature for OSes $1 works on a variant targeting OS $2.
os_supported() {
  list_contains "$1" any || list_contains "$1" "$2" \
    || { list_contains "$1" linux && list_contains "arch steamos" "$2"; }
}

# Return 0 if a feature for GUIs $1 works on a variant targeting GUI $2 (none for headless).
gui_supported() {
  list_contains "$1" any || list_contains "$1" "$2" \
    || { list_contains "$1" desktop && [[ "$2" != none ]]; }
}

# Features that honor --dry-run; others are only announced.
DRY_RUN_FEATURES=" pacman yay terminal font printer logiops link services manual tmux gitconfig dconf xdg info neovim steamos_xclip flatpak kde udev tmpfiles webterm home_units distrobox "

feature_function() {
  printf 'feature_%s' "${1//-/_}"
}

# Features can define uninstall_feature_<name>, run by --uninstall and before
# feature_<name> by --reinstall. It must be idempotent and honor --dry-run.
uninstall_function() {
  printf 'uninstall_feature_%s' "${1//-/_}"
}

# Return 0 if feature $1 defines an uninstall function.
feature_uninstallable() {
  declare -F "$(uninstall_function "$1")" >/dev/null
}

# Return 0 if a variant_<name> function is defined.
variant_exists() {
  [[ -n "$1" ]] && declare -F "variant_$1" >/dev/null
}

# Call variant_<name>, which sets the variant's _* config outputs.
variant_config() {
  variant_exists "$1" || error "Unknown variant '$1'"
  "variant_$1"
}
