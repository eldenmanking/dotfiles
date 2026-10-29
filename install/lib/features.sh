# Feature, OS, profile and variant registry helpers.

feature_description() {
  case "$1" in
    all)         echo "install all options" ;;
    pacman)      echo "install pacman packages" ;;
    yay)         echo "install yay packages" ;;
    terminal)    echo "install terminal packages" ;;
    font)        echo "install JetBrainsMono Nerd Font to ~/.local/share/fonts" ;;
    printer)     echo "install and set up HP printer drivers" ;;
    logiops)     echo "install and configure logitech software" ;;
    link)        echo "symlink the OS and profile's dotfiles into ~ (root/ into /)" ;;
    services)    echo "enable and start bluetooth (sudo)" ;;
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
    logind)      echo "copy root/etc/systemd/logind.conf.d drop-ins into /etc (not symlinked; no lid suspend on external power) and reload logind" ;;
    steamos_make) echo "install make to ~/.local/bin by copying it out of the 'arch' distrobox (created if missing, then kept)" ;;
    steamos_xclip) echo "install xclip to ~/.local/bin by copying it out of the 'arch' distrobox (created if missing, then kept)" ;;
    steam)       echo "write Steam settings (game mode menu hotkeys) into localconfig.vdf, while Steam is closed" ;;
    webterm)     echo "download ttyd and install the webterm systemd user units into /etc (browser shell on localhost)" ;;
    hdmi_audio_fix) echo "install hdmi-audio-fix.service into /etc (sudo): a socclk floor on the Framework 16 780M, for HDMI audio" ;;
    gamescope_screenshot) echo "install systemd user units into /etc (sudo) that save a Gaming Mode screenshot on Print Screen or Shift+Meta+4" ;;
    kde)         echo "merge partial KDE config files (e.g. home/.config/kcminputrc) into ~/.config with kwriteconfig" ;;
    light_sleep) echo "install light-sleep into /etc (sudo): idle with the displays off instead of suspending while an eGPU is on the expansion bay" ;;
    orei_switch) echo "download framework_tool and install the OREI HDMI switch sleep/wake handoff into /etc (sudo)" ;;
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
  ' "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/features/*/*.sh)
  _doc="$doc"
}

# Where feature $1 works and which features it needs, read from the tags in its doc (see feature_doc). Outputs
# (space-separated lists, empty when the tag is missing):
#  _machine: @machine, hardware it is for: any, laptop, framework16. Features for specific hardware live in
#             install/features/<os>_<machine>/ and are left out of --all on other machines (see machine_supported)
#  _os: @os, any, linux, macos, arch, steamos (linux covers arch and steamos)
#  _gui: @gui, any (also headless), desktop (any graphical session), gnome, kde
#  _requires: @requires (optional), features that must run before it in the same OS and profile
# Each OS sets the _platforms (@os values) and each OS and profile the _gui it targets; tests/validation/features.sh
# requires the description and tags on every feature, checks the features of every OS and profile against them and
# that each feature's _requires come earlier in its _features.
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

# Return 0 if a feature for OSes $1 works on platform $2 (one of an OS's _platforms).
os_supported() {
  list_contains "$1" any || list_contains "$1" "$2" \
    || { list_contains "$1" linux && list_contains "arch steamos" "$2"; }
}

# Return 0 if a feature for machines $1 suits machine $2 (one of MACHINES, in install/lib/infer.sh).
machine_supported() {
  list_contains "$1" any || list_contains "$1" "$2" \
    || { list_contains "$1" laptop && [[ "$2" == framework16 ]]; }
}

# Return 0 if a feature for GUIs $1 works with GUI $2 (none for headless).
gui_supported() {
  list_contains "$1" any || list_contains "$1" "$2" \
    || { list_contains "$1" desktop && [[ "$2" != none ]]; }
}

# Features that honor --dry-run; others are only announced.
DRY_RUN_FEATURES=" pacman yay terminal font printer logiops link services manual tmux gitconfig dconf xdg info neovim steamos_xclip steamos_make flatpak kde steam udev tmpfiles logind webterm hdmi_audio_fix orei_switch light_sleep gamescope_screenshot distrobox "

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

# Print the names of the definitions in install/$1 (variants, os or profiles), from their file names.
available_names() {
  local f names=""
  for f in "$INSTALL_DIR/$1"/*.sh; do
    f="$(basename "$f" .sh)"
    names+="${names:+ }$f"
  done
  printf '%s' "$names"
}

# Return 0 if a variant_<name> function is defined.
variant_exists() {
  [[ -n "$1" ]] && declare -F "variant_$1" >/dev/null
}

# Return 0 if an os_<name> function is defined.
os_exists() {
  [[ -n "$1" ]] && declare -F "os_$1" >/dev/null
}

# Return 0 if a profile_<name> function is defined.
profile_exists() {
  [[ -n "$1" ]] && declare -F "profile_$1" >/dev/null
}

# Return 0 if OS $1 supports profile $2, which it does by defining os_<os>_<profile>.
os_supports_profile() {
  os_exists "$1" && profile_exists "$2" && declare -F "os_$1_$2" >/dev/null
}

# Print the profiles OS $1 supports.
os_profiles() {
  local profile profiles=""
  for profile in $(available_names profiles); do
    os_supports_profile "$1" "$profile" && profiles+="${profiles:+ }$profile"
  done
  printf '%s' "$profiles"
}

# Call variant_<name>, which sets _os and _profile, the OS and profile it stands for.
variant_config() {
  variant_exists "$1" || error "Unknown variant '$1'"
  "variant_$1"
}

# Call os_<name>, which sets _description, _platforms (the @os values its features must suit) and _machines (the
# machines it supports, from MACHINES).
os_config() {
  os_exists "$1" || error "Unknown OS '$1'"
  "os_$1"
}

# Call profile_<name>, which sets _description and _git_fsmonitor.
profile_config() {
  profile_exists "$1" || error "Unknown profile '$1'"
  "profile_$1"
}

# Outputs the config of OS $1 with profile $2: os_config's and profile_config's outputs (_description is the OS's),
# then os_<os>_<profile>'s: _features (in the order they run), _optional (the ones --all skips), _gui (the GUI they
# target, none for headless) and _link_paths (what the link feature links).
os_profile_config() {
  os_supports_profile "$1" "$2" || error "OS '$1' has no profile '$2'"
  "profile_$2"
  "os_$1"
  "os_$1_$2"
}
