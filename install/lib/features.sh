# Feature, OS, profile and variant registry helpers.

# Print the --help text of feature <feature> (or all, for --all), or an empty line for an unknown one.
# Usage: feature_description <feature>
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
    desktop)     echo "enable bluetooth and the GDM login screen, and boot into it (sudo)" ;;
    manual)      echo "make manual substitutions to files in-place" ;;
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
    steamos_arch_vm) echo "create a GNOME Boxes VM for testing Arch installs: the Arch ISO as a read-only install medium and a blank 40G disk to install onto" ;;
    steamos_vm) echo "create a virt-manager VM running SteamOS with GPU acceleration, installed unattended from Valve's recovery image; start it with steamos-vm" ;;
    steamos_xclip) echo "install xclip to ~/.local/bin by copying it out of the 'arch' distrobox (created if missing, then kept)" ;;
    steam)       echo "write Steam settings (game mode menu hotkeys) into localconfig.vdf, while Steam is closed" ;;
    webterm)     echo "download ttyd and install the webterm systemd user units into /etc (browser shell on localhost)" ;;
    hdmi_audio_fix) echo "install hdmi-audio-fix.service into /etc (sudo): a socclk floor on the Framework 16 780M, for HDMI audio" ;;
    gamescope_screenshot) echo "install systemd user units into /etc (sudo) that save a Gaming Mode screenshot on Print Screen or Shift+Meta+4" ;;
    desktop_settings) echo "load desktop settings: dump/dconf/arch.dconf on GNOME, home/.config KDE files merged with kwriteconfig on KDE" ;;
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

# Read the doc comment of feature or implementation <feature>: the comment block directly above its feature_<name>
# (or feature_<name>__<dir>) function in install/features. A feature's doc is a description, a bare '#' line, then
# its tags:
#   # Install the thing for x.
#   #
#   # @machine any
#   # @os linux
#   # @gui gnome
# Usage: f_call feature_doc doc -- <feature>
# Returns: doc
#   doc: the comment block, with each line's leading '#' and one space removed
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
  f_return doc
}

# Where feature <feature> works and which features it needs, read from the tags in its doc (see feature_doc), each a
# space-separated list, empty when the tag is missing. Each OS returns the platforms (@os values) and each OS and
# profile the gui it targets; tests/validation/features.sh requires the description and tags on every feature,
# checks the features of every OS and profile against them and that each feature's requires come earlier in its
# features.
# Usage: f_call feature_requirements machine os gui requires -- <feature>
# Returns: machine os gui requires
#   machine: @machine, hardware it is for: any, laptop, framework16. Features for specific hardware live in
#     install/features/<os>_<machine>/ (see implementation_dir) and are left out of --all on other machines (see
#     machine_supported)
#   os: @os, any, linux, macos, arch, steamos (linux covers arch and steamos)
#   gui: @gui, any (also headless), desktop (any graphical session), gnome, kde
#   requires: @requires (optional), features that must run before it in the same OS and profile
feature_requirements() {
  local line machine="" os="" gui="" requires="" doc
  f_call feature_doc doc -- "$1"
  while IFS= read -r line; do
    case "$line" in
      "@machine "*)  machine="${line#@machine }" ;;
      "@os "*)       os="${line#@os }" ;;
      "@gui "*)      gui="${line#@gui }" ;;
      "@requires "*) requires="${line#@requires }" ;;
    esac
  done <<< "$doc"
  f_return machine os gui requires
}

# Return 0 if a feature for OSes $1 works on platform $2 (one of an OS's platforms).
# Usage: os_supported <oses> <platform>
os_supported() {
  list_contains "$1" any || list_contains "$1" "$2" \
    || { list_contains "$1" linux && list_contains "arch steamos" "$2"; }
}

# Return 0 if a feature for machines $1 suits machine $2 (one of MACHINES, in install/lib/infer.sh).
# Usage: machine_supported <machines> <machine>
machine_supported() {
  list_contains "$1" any || list_contains "$1" "$2" \
    || { list_contains "$1" laptop && [[ "$2" == framework16 ]]; }
}

# Return 0 if a feature for GUIs $1 works with GUI $2 (none for headless).
# Usage: gui_supported <guis> <gui>
gui_supported() {
  list_contains "$1" any || list_contains "$1" "$2" \
    || { list_contains "$1" desktop && [[ "$2" != none ]]; }
}

# A feature has one implementation, feature_<name>, or several, each feature_<name>__<dir> in
# install/features/<dir>/<name>.sh, where <dir> is named after the implementation's single @os, @machine and @gui (see
# implementation_dir). install.sh runs the one whose tags suit the OS, profile and machine. An implementation's id
# (<name>, or <name>__<dir>) stands in for a feature name in feature_function, uninstall_function, capture_function,
# feature_doc and feature_requirements, so each implementation has its own doc, tags, uninstall and capture.

# Print the subdirectory of install/features that holds a feature or implementation for machine <machine>, OS <os> and
# GUI <gui> (each a single tag value): <os>, then _<machine> and _<gui> unless they are any, e.g. linux_framework16 or
# linux_kde.
# Usage: implementation_dir <machine> <os> <gui>
implementation_dir() {
  local machine="$1" os="$2" gui="$3"
  printf '%s' "$os"
  [[ "$machine" == any ]] || printf '_%s' "$machine"
  [[ "$gui" == any ]] || printf '_%s' "$gui"
}

# Print the base feature name of implementation id <impl>: <impl> without its __<dir> suffix.
# Usage: implementation_feature <impl>
implementation_feature() {
  printf '%s' "${1%%__*}"
}

# Print the ids of feature <feature>'s implementations, space-separated: <feature> when feature_<feature> is defined,
# then each <feature>__<dir> whose feature_<feature>__<dir> is.
# Usage: feature_implementations <feature>
feature_implementations() {
  local fn ids="" line
  fn="$(feature_function "$1")"
  fn_defined "$fn" && ids="$1"
  while IFS= read -r line; do
    line="${line#declare -f }"
    [[ "$line" == "${fn}__"* ]] || continue
    ids+="${ids:+ }$1__${line#"${fn}__"}"
  done < <(declare -F)
  printf '%s' "$ids"
}

# Return 0 if an implementation with tags @machine <impl_machine>, @os <impl_os> and @gui <impl_gui> suits every
# platform in <platforms> (an OS's @os values), GUI <gui> and, unless <machine> is empty, machine <machine>.
# Usage: tags_suit <impl_machine> <impl_os> <impl_gui> <platforms> <gui> [<machine>]
tags_suit() {
  local impl_machine="$1" impl_os="$2" impl_gui="$3" platforms="$4" gui="$5" machine="${6:-}" v
  for v in $platforms; do
    os_supported "$impl_os" "$v" || return 1
  done
  gui_supported "$impl_gui" "$gui" || return 1
  [[ -z "$machine" ]] || machine_supported "$impl_machine" "$machine"
}

# Return 0 if implementation <impl> suits every platform in <platforms>, GUI <gui> and, unless <machine> is empty,
# machine <machine> (see tags_suit).
# Usage: implementation_suits <impl> <platforms> <gui> [<machine>]
implementation_suits() {
  local impl_machine impl_os impl_gui
  f_call feature_requirements impl_machine=machine impl_os=os impl_gui=gui -- "$1"
  tags_suit "$impl_machine" "$impl_os" "$impl_gui" "$2" "$3" "${4:-}"
}

# Pick the implementation of feature <feature> to run for platforms <platforms> (an OS's @os values), GUI <gui> and
# machine <machine>. When none suits <machine>, falls back to the one implementation that suits the platforms and GUI
# on some other machine, which runs only when its feature is named.
# Usage: f_call resolve_implementation impl suited problem -- <feature> <platforms> <gui> <machine>
# Returns: impl suited problem
#   impl: the implementation's id, or empty when none can run
#   suited: true when impl suits <machine>, false when it is for another machine or empty
#   problem: why impl is empty, or empty
resolve_implementation() {
  local feature="$1" platforms="$2" gui="$3" machine="$4" id candidates="" matches="" impl="" suited=false problem=""
  local impl_machine impl_os impl_gui
  for id in $(feature_implementations "$feature"); do
    f_call feature_requirements impl_machine=machine impl_os=os impl_gui=gui -- "$id"
    tags_suit "$impl_machine" "$impl_os" "$impl_gui" "$platforms" "$gui" || continue
    candidates+="${candidates:+ }$id"
    tags_suit "$impl_machine" "$impl_os" "$impl_gui" "$platforms" "$gui" "$machine" && matches+="${matches:+ }$id"
  done
  if [[ -n "$matches" && "$matches" != *" "* ]]; then
    impl="$matches" suited=true
  elif [[ -n "$matches" ]]; then
    problem="--$feature has several implementations for machine $machine: $matches"
  elif [[ -n "$candidates" && "$candidates" != *" "* ]]; then
    impl="$candidates"
  elif [[ -n "$candidates" ]]; then
    problem="--$feature has no implementation for machine $machine, only for other machines: $candidates"
  else
    problem="--$feature has no implementation for platforms '$platforms' with GUI '$gui'"
  fi
  f_return impl suited problem
}

# Feature lists the OSes' profiles share (install/os/*.sh), so that they stay in step. The order each profile runs
# its features in is its own, so a profile lists these where its other features need them.
# Hardware-specific system files copied into /etc (for laptops or the framework16 machine): --all skips them on
# other machines.
FEATURES_SYSTEM="udev tmpfiles logind hdmi_audio_fix"
# The terminal tools the terminal setups share: tmux, the Claude config and the git config.
FEATURES_TOOLS="tmux claude gitconfig"
# What the portable profiles share before their last features.
FEATURES_PORTABLE="binaries link zsh shell starship tmux"

# Features that honor --dry-run (all of a listed feature's implementations must); others are only announced.
DRY_RUN_FEATURES=" pacman yay terminal font printer logiops link desktop manual tmux gitconfig desktop_settings xdg info neovim steamos_xclip steamos_make steamos_arch_vm steamos_vm flatpak steam udev tmpfiles logind webterm hdmi_audio_fix orei_switch light_sleep gamescope_screenshot distrobox "

# Print the name of feature <feature>'s function, feature_<name> with any - as _.
# Usage: feature_function <feature>
feature_function() {
  fn_name feature_ "$1"
}

# Features can define uninstall_feature_<name>, run by --uninstall and before
# feature_<name> by --reinstall. It must be idempotent and honor --dry-run.
# Usage: uninstall_function <feature>
uninstall_function() {
  fn_name uninstall_feature_ "$1"
}

# Return 0 if feature $1 defines an uninstall function.
# Usage: feature_uninstallable <feature>
feature_uninstallable() {
  fn_defined "$(uninstall_function "$1")"
}

# Features can define capture_feature_<name>, run by --capture to copy settings changed on this system (e.g. in a settings app)
# back into the repo's files. It must honor --dry-run.
# Usage: capture_function <feature>
capture_function() {
  fn_name capture_feature_ "$1"
}

# Return 0 if feature $1 defines a capture function.
# Usage: feature_capturable <feature>
feature_capturable() {
  fn_defined "$(capture_function "$1")"
}

# Print the names of the definitions in install/$1 (variants, os or profiles), from their file names.
# Usage: available_names <dir>
available_names() {
  local f names=""
  for f in "$INSTALL_DIR/$1"/*.sh; do
    f="$(basename "$f" .sh)"
    names+="${names:+ }$f"
  done
  printf '%s' "$names"
}

# Return 0 if a variant_<name> function is defined.
# Usage: variant_exists <variant>
variant_exists() {
  [[ -n "$1" ]] && fn_defined "variant_$1"
}

# Return 0 if an os_<name> function is defined.
# Usage: os_exists <os>
os_exists() {
  [[ -n "$1" ]] && fn_defined "os_$1"
}

# Return 0 if a profile_<name> function is defined.
# Usage: profile_exists <profile>
profile_exists() {
  [[ -n "$1" ]] && fn_defined "profile_$1"
}

# Return 0 if OS $1 supports profile $2, which it does by defining os_<os>_<profile>.
# Usage: os_supports_profile <os> <profile>
os_supports_profile() {
  os_exists "$1" && profile_exists "$2" && fn_defined "os_$1_$2"
}

# Print the profiles OS $1 supports.
# Usage: os_profiles <os>
os_profiles() {
  local profile profiles=""
  for profile in $(available_names profiles); do
    os_supports_profile "$1" "$profile" && profiles+="${profiles:+ }$profile"
  done
  printf '%s' "$profiles"
}

# Call variant_<variant>, which returns the OS and profile it stands for.
# Usage: f_call variant_config os profile -- <variant>
# Returns: os profile
variant_config() {
  variant_exists "$1" || error "Unknown variant '$1'"
  "variant_$1"
}

# Call os_<os>, which returns its config.
# Usage: f_call os_config description platforms machines -- <os>
# Returns: description platforms machines
#   platforms: the @os values its features must suit
#   machines: the machines it supports, from MACHINES
os_config() {
  os_exists "$1" || error "Unknown OS '$1'"
  "os_$1"
}

# Call profile_<profile>, which returns its config.
# Usage: f_call profile_config description git_fsmonitor -- <profile>
# Returns: description git_fsmonitor
profile_config() {
  profile_exists "$1" || error "Unknown profile '$1'"
  "profile_$1"
}

# Read the config of OS <os> with profile <profile>: what profile_config, os_config and os_<os>_<profile> return.
# Usage: f_call os_profile_config description git_fsmonitor platforms machines features gui optional link_paths -- \
#   <os> <profile>
# Returns: description git_fsmonitor platforms machines features gui optional link_paths
#   description: the OS's
#   features: in the order they run
#   gui: the GUI they target, none for headless
#   optional: the ones --all skips
#   link_paths: what the link feature links
os_profile_config() {
  os_supports_profile "$1" "$2" || error "OS '$1' has no profile '$2'"
  "profile_$2"
  "os_$1"
  "os_$1_$2"
}

# Pick the implementation of feature <feature> to run for OS <os> with profile <profile> on machine <machine>, with
# resolve_implementation and the OS's platforms and the profile's GUI.
# Usage: f_call feature_implementation impl suited problem -- <feature> <os> <profile> <machine>
# Returns: impl suited problem
feature_implementation() {
  local feature="$1" os="$2" profile="$3" machine="$4" platforms gui
  f_call os_profile_config platforms gui -- "$os" "$profile"
  resolve_implementation "$feature" "$platforms" "$gui" "$machine"
}
