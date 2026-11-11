#!/usr/bin/env bash

################################################################################
# Program: install.sh
# Description: Installs essential packages for configuration and creates
#              symlinks in the proper locations. Installs for an OS, profile
#              and machine (see install/os/, install/profiles/ and the
#              variants naming an OS and profile in install/variants/) and
#              toggles features with flags.
# Location: ~/dotfiles/install.sh
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR/install"
DOTFILES_ROOT="$HOME/dotfiles"
BACKUPS_ROOT="$DOTFILES_ROOT/.backup"
LOCAL_PREFIX="$HOME/.local"
LOCAL_BIN="$LOCAL_PREFIX/bin"
INSTALL_CONFIG="${DOTFILES_INSTALL_CONFIG:-$HOME/.config/dotfiles/install.conf}"
# A directory of downloads named by SHA-256, read and filled by download_verified (see Download Cache in README.md).
DOWNLOAD_CACHE="${DOTFILES_DOWNLOAD_CACHE:-}"

# install.sh only runs from a dotfiles checkout, beside its install/ directory; to install from scratch, use the
# bootstrap on the repo's install branch (see README.md). From a git checkout elsewhere, clone_checkout_to_root moves
# the install to $DOTFILES_ROOT. Runs before install/lib is loaded, so it prints its own messages.
bootstrap() {
  if [[ ! -f "$INSTALL_DIR/lib/fn.sh" ]]; then
    printf '[error] install.sh must run from a dotfiles checkout. To install from scratch, use the install.sh on\n' >&2
    printf '        the install branch instead (see Installation in README.md).\n' >&2
    exit 1
  fi
  clone_checkout_to_root "$@"
}

# When run from a git checkout elsewhere (e.g. Coder's ~/.config/coderv2/dotfiles) and $DOTFILES_ROOT doesn't exist,
# clone that checkout's current commit to $DOTFILES_ROOT, point its origin at the checkout's origin, then re-run its
# install.sh with the same arguments. Uncommitted changes aren't copied. Anything else is left to enter_dotfiles_root.
clone_checkout_to_root() {
  local top head branch origin
  [[ ! -e "$DOTFILES_ROOT" && ! -L "$DOTFILES_ROOT" ]] || return 0
  command -v git >/dev/null || return 0
  top="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" || return 0
  [[ "$(cd "$top" && pwd -P)" == "$(cd "$SCRIPT_DIR" && pwd -P)" ]] || return 0

  head="$(git -C "$SCRIPT_DIR" rev-parse HEAD)"
  branch="$(git -C "$SCRIPT_DIR" symbolic-ref --short -q HEAD || true)"
  origin="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)"
  [[ -z "$(git -C "$SCRIPT_DIR" status --porcelain)" ]] \
    || printf '[warn] %s has uncommitted changes, which are not copied to %s\n' "$SCRIPT_DIR" "$DOTFILES_ROOT" >&2
  printf '[info] Cloning %s (%s) into %s\n' "$SCRIPT_DIR" "${branch:-${head:0:12}}" "$DOTFILES_ROOT"
  git -c advice.detachedHead=false clone --quiet --no-checkout "$SCRIPT_DIR" "$DOTFILES_ROOT"
  if [[ -n "$branch" ]]; then
    git -C "$DOTFILES_ROOT" checkout --quiet -B "$branch" "$head"
  else
    git -C "$DOTFILES_ROOT" checkout --quiet --detach "$head"
  fi
  [[ -z "$origin" ]] || git -C "$DOTFILES_ROOT" remote set-url origin "$origin"
  exec "${BASH:-bash}" "$DOTFILES_ROOT/install.sh" "$@"
}

# Source install/lib, features, OSes, profiles and variants. They only define functions and constants, so their
# globals stay global.
load_install_deps() {
  local f
  for f in "$INSTALL_DIR"/lib/*.sh "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/features/*/*.sh \
    "$INSTALL_DIR"/os/*.sh "$INSTALL_DIR"/profiles/*.sh "$INSTALL_DIR"/variants/*.sh \
    "$INSTALL_DIR"/oti/*.sh; do
    # shellcheck source=/dev/null
    source "$f"
  done
}

# Print feature $1's --help line, with the machines it is for and the features it requires.
usage_feature() {
  local machine requires
  f_call feature_requirements machine requires -- "$1"
  [[ "$machine" != any ]] || machine=""
  printf '  --%-14s %s%s%s\n' "$1" "$(feature_description "$1")" "${machine:+ (machine: $machine)}" \
    "${requires:+ (requires: --${requires// / --})}"
}

# Print the variants, OSes and profiles, then the options of OS $1 with profile $2 on machine $3 if they can run.
usage() {
  local os="$1" profile="$2" machine="${3:-generic}" v features optional other="" uninstallable="" capturable=""
  local variant_os variant_profile description os_machines feature_machine
  cat <<EOF
Usage: $(basename "$0") [--variant NAME | --os NAME --profile NAME] [--machine NAME] [--infer] [OPTIONS]
       $(basename "$0") --oti NAME [--dry-run]

dotfiles installation and configuration script. All operations are idempotent.
An install is for an OS, a profile (how the machine is used) and a machine
(the hardware, default generic). --variant names an OS and profile, which
--os and --profile override; --infer guesses whichever isn't given from this
system. Run with them and --help to list their options. Without them,
DOTFILES_VARIANT, DOTFILES_OS, DOTFILES_PROFILE and DOTFILES_MACHINE name
them; without options, DOTFILES_FEATURES lists them (feature names, or all
for --all). Set them in the environment or in $INSTALL_CONFIG.
--oti runs a one-time install instead, which sets up a machine once (e.g.
installing Arch from its live ISO): it asks its questions up front, prints
each command it runs, resumes where an earlier run stopped, and can't be undone.
See README.md for more information.

Variants:
EOF
  for v in $(available_names variants); do
    f_call variant_config variant_os=os variant_profile=profile -- "$v"
    printf '  %-10s --os %s --profile %s\n' "$v" "$variant_os" "$variant_profile"
  done
  printf '\nOSes (profiles; machines):\n'
  for v in $(available_names os); do
    f_call os_config description os_machines=machines -- "$v"
    printf '  %-10s %s (%s; %s)\n' "$v" "$description" "$(os_profiles "$v")" "$os_machines"
  done
  printf '\nProfiles:\n'
  for v in $(available_names profiles); do
    f_call profile_config description -- "$v"
    printf '  %-10s %s\n' "$v" "$description"
  done
  printf '\nOne-time installs (--oti NAME):\n'
  for v in $(available_names oti); do
    f_call oti_config description -- "$v"
    printf '  %-12s %s\n' "$v" "$description"
  done
  os_supports_profile "$os" "$profile" || return 0

  f_call os_profile_config features optional -- "$os" "$profile"
  cat <<EOF

Options for OS '$os' with profile '$profile' on machine '$machine':
  --variant NAME   select an OS and profile
  --os NAME        select the OS
  --profile NAME   select the profile
  --machine NAME   select the machine (the hardware)
  --infer          infer the OS, profile or machine not given from this system
  --all            install all default options
EOF
  for v in $features; do
    feature_uninstallable "$v" && uninstallable+="${uninstallable:+ }$v"
    feature_capturable "$v" && capturable+="${capturable:+ }$v"
    f_call feature_requirements feature_machine=machine -- "$v"
    if list_contains "$optional" "$v"; then
      continue
    elif machine_supported "$feature_machine" "$machine"; then
      usage_feature "$v"
    else
      other+="${other:+ }$v"
    fi
  done
  if [[ -n "$optional" ]]; then
    printf '\nOptional (not included in --all):\n'
    for v in $optional; do
      usage_feature "$v"
    done
  fi
  if [[ -n "$other" ]]; then
    printf "\nFor other machines (not included in --all on '%s'):\n" "$machine"
    for v in $other; do
      usage_feature "$v"
    done
  fi
  [[ -z "$optional$other" ]] || echo
  if [[ -n "$uninstallable" ]]; then
    printf '  --%-14s %s (%s)\n' reinstall "uninstall the selected options, then install them" "$uninstallable"
    printf '  --%-14s %s (%s)\n' uninstall "uninstall the selected options" "$uninstallable"
  fi
  if [[ -n "$capturable" ]]; then
    printf '  --%-14s %s (%s)\n' capture "capture the selected options' settings from this system into the repo" "$capturable"
  fi
  cat <<EOF
  --dry-run        print what would happen without making changes
  --help, -h       show this help page
EOF
}

# Warn with message $1, print usage (of OS $2 with profile $3 on machine $4, if given) and exit.
usage_error() {
  local message="$1" os="${2:-}" profile="${3:-}" machine="${4:-}"
  warn "$message"
  usage "$os" "$profile" "$machine" >&2
  exit 1
}

parse_args() {
  local variant="" os="" profile="" machine="" infer=false flags=" " mode=install all=false dry_run=false help=false
  local oti="" opt value

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --variant|--os|--profile|--machine|--oti|--variant=*|--os=*|--profile=*|--machine=*|--oti=*)
        opt="${1%%=*}"
        if [[ "$1" == *=* ]]; then
          value="${1#*=}"
          shift
        else
          [[ $# -ge 2 ]] || usage_error "$opt requires a value"
          value="$2"
          shift 2
        fi
        [[ -n "$value" ]] || usage_error "$opt requires a non-empty value"
        [[ "$value" != --* ]] || usage_error "$opt requires a value, but got the option $value"
        case "$opt" in
          --oti)     [[ -z "$oti" ]] || usage_error "$opt was given twice"; oti="$value" ;;
          --variant) [[ -z "$variant" ]] || usage_error "$opt was given twice"; variant="$value" ;;
          --os)      [[ -z "$os" ]] || usage_error "$opt was given twice"; os="$value" ;;
          --profile) [[ -z "$profile" ]] || usage_error "$opt was given twice"; profile="$value" ;;
          --machine) [[ -z "$machine" ]] || usage_error "$opt was given twice"; machine="$value" ;;
        esac
        ;;
      --infer)     infer=true; shift ;;
      --all)       all=true; shift ;;
      --dry-run)   dry_run=true; shift ;;
      --reinstall|--uninstall|--capture)
        [[ "$mode" == install || "$mode" == "${1#--}" ]] \
          || usage_error "--reinstall, --uninstall and --capture are mutually exclusive"
        mode="${1#--}"
        shift
        ;;
      --help|-h)   help=true; shift ;;
      *)
        # Feature names only, so later word splitting of the flags can't glob.
        [[ "$1" =~ ^--[a-z0-9_-]+$ ]] || usage_error "Unexpected argument: $1"
        flags+="${1#--} "
        shift
        ;;
    esac
  done

  f_return variant os profile machine infer flags mode all dry_run help oti
}

# Outputs: default_variant, default_os, default_profile, default_machine and default_features, from
# DOTFILES_VARIANT, DOTFILES_OS, DOTFILES_PROFILE, DOTFILES_MACHINE and DOTFILES_FEATURES in the environment or, for
# each one unset there, in config file $1. The file is sourced in a subshell so it can't change this shell's state.
load_install_defaults() {
  local conf="$1" file_variant="" file_os="" file_profile="" file_machine="" file_features=""
  if [[ -f "$conf" ]]; then
    { IFS= read -r -d '' file_variant && IFS= read -r -d '' file_os && IFS= read -r -d '' file_profile \
      && IFS= read -r -d '' file_machine && IFS= read -r -d '' file_features; } < <(
      unset DOTFILES_VARIANT DOTFILES_OS DOTFILES_PROFILE DOTFILES_MACHINE DOTFILES_FEATURES
      # shellcheck source=/dev/null
      source "$conf" >&2 || exit 1
      printf '%s\0%s\0%s\0%s\0%s\0' "${DOTFILES_VARIANT:-}" "${DOTFILES_OS:-}" "${DOTFILES_PROFILE:-}" \
        "${DOTFILES_MACHINE:-}" "${DOTFILES_FEATURES:-}"
    ) || error "Could not read $conf"
  fi
  f_return \
    default_variant="${DOTFILES_VARIANT:-$file_variant}" \
    default_os="${DOTFILES_OS:-$file_os}" \
    default_profile="${DOTFILES_PROFILE:-$file_profile}" \
    default_machine="${DOTFILES_MACHINE:-$file_machine}" \
    default_features="${DOTFILES_FEATURES:-$file_features}"
}

# Outputs: os and profile, OS $2 and profile $3, with each one left empty filled in from variant $1 (if given). $4
# says where the variant came from, for the error if it doesn't exist.
variant_dimensions() {
  local variant="$1" os="$2" profile="$3" origin="${4:-}" variant_os variant_profile
  if [[ -n "$variant" ]]; then
    variant_exists "$variant" \
      || usage_error "Unknown variant '$variant'${origin:+ (from $origin)}. Available variants: $(available_names variants)"
    f_call variant_config variant_os=os variant_profile=profile -- "$variant"
    [[ -n "$os" ]] || os="$variant_os"
    [[ -n "$profile" ]] || profile="$variant_profile"
  fi
  f_return os profile
}

# Outputs: flags and all, flags $1 and --all $2 with default features $4 (feature names, and all for --all) added
# when the command line selects none, unless mode $3 is uninstall or the OS and profile to install for ($5, $6) aren't
# the ones the defaults name ($7, $8; both empty when the defaults name none).
apply_default_features() {
  local flags="$1" all="$2" mode="$3" default_features="$4" os="$5" profile="$6" default_os="$7"
  local default_profile="$8" word
  if [[ "$flags" == " " ]] && ! $all && [[ "$mode" != uninstall ]] \
    && [[ -z "$default_os$default_profile" || "$os $profile" == "$default_os $default_profile" ]]; then
    for word in $default_features; do
      word="${word#--}"
      [[ "$word" =~ ^[a-z0-9_-]+$ ]] || usage_error "Invalid feature '$word' in DOTFILES_FEATURES"
      if [[ "$word" == all ]]; then all=true; else flags+="$word "; fi
    done
  fi
  f_return flags all
}

# Outputs: os, profile and machine to install for: OS $1, profile $2 and machine $3 as given (by options or
# defaults), with each one left empty inferred from this system when $4 (--infer) is true, to suit the given ones:
# an OS that lacks the given profile becomes portable if that has it (portable runs anywhere), and a machine the OS
# doesn't support becomes generic. Without --infer, an empty machine is generic and an empty OS or profile stays
# empty, for exit_with_usage_unless_runnable to report.
resolve_dimensions() {
  local os="$1" profile="$2" machine="$3" infer="$4" inferred="" system_os system_machine coder reason os_machines
  if $infer && [[ -z "$os" || -z "$profile" || -z "$machine" ]]; then
    f_call infer_system system_os=os system_machine=machine coder reason
    if [[ -z "$os" ]]; then
      [[ -n "$system_os" ]] || error "Could not infer an OS for this system ($reason); pass --os or --variant"
      os="$system_os"
      if [[ -n "$profile" ]] && ! os_supports_profile "$os" "$profile" && os_supports_profile portable "$profile"; then
        os=portable
      fi
      inferred+="OS '$os'"
    fi
    if [[ -z "$profile" ]]; then
      profile="$(profile_for_system "$os" "$coder")"
      inferred+="${inferred:+, }profile '$profile'"
    fi
    if [[ -z "$machine" ]]; then
      machine="$system_machine"
      if os_exists "$os"; then
        f_call os_config os_machines=machines -- "$os"
        list_contains "$os_machines" "$machine" || machine=generic
      fi
      inferred+="${inferred:+, }machine '$machine'"
    fi
    info "Inferred $inferred from: $reason"
  fi
  f_return os profile machine="${machine:-generic}"
}

# Print usage and exit unless OS $5 with profile $6 can run on machine $7: with no OS and profile, or with no
# features selected ($1 flags, $2 --all) or --help ($3). Without an OS and profile this is an error unless --help was
# given or there were no arguments ($4), as is an OS, profile or machine that doesn't exist or doesn't go together.
exit_with_usage_unless_runnable() {
  local flags="$1" all="$2" help="$3" no_args="$4" os="$5" profile="$6" machine="$7" os_machines
  list_contains "$MACHINES" "$machine" || usage_error "Unknown machine '$machine'. Available machines: $MACHINES"
  if [[ -z "$os" && -z "$profile" ]]; then
    $help || $no_args || usage_error "--variant, or --os and --profile, is required (or --infer)"
    usage "" "" "$machine"
    exit 0
  fi
  [[ -z "$os" ]] || os_exists "$os" || usage_error "Unknown OS '$os'. Available OSes: $(available_names os)"
  [[ -z "$profile" ]] || profile_exists "$profile" \
    || usage_error "Unknown profile '$profile'. Available profiles: $(available_names profiles)"
  if $help && [[ -z "$os" || -z "$profile" ]]; then
    usage "" "" "$machine"
    exit 0
  fi
  [[ -n "$os" ]] || usage_error "--profile $profile needs --os (or --infer)"
  [[ -n "$profile" ]] || usage_error "--os $os needs --profile, one of: $(os_profiles "$os") (or --infer)"
  os_supports_profile "$os" "$profile" \
    || usage_error "OS '$os' has no profile '$profile'; it has: $(os_profiles "$os")"
  f_call os_config os_machines=machines -- "$os"
  list_contains "$os_machines" "$machine" \
    || usage_error "OS '$os' doesn't support machine '$machine'; it supports: $os_machines"
  if $help || { [[ "$flags" == " " ]] && ! $all; }; then
    usage "$os" "$profile" "$machine"
    exit 0
  fi
}

# Outputs: enabled, the selected features of OS $1 with profile $2 on machine $6. --all leaves out optional features
# and those whose @machine doesn't suit $6; named features run either way (with a warning for the latter). Under
# --uninstall, features without an uninstall function are dropped (with a warning if named), and under --capture those
# without a capture function.
resolve_features() {
  local os="$1" profile="$2" flags="$3" all="$4" mode="$5" machine="$6" features optional enabled=" " k default
  local feature_machine

  f_call os_profile_config features optional -- "$os" "$profile"

  for k in $flags; do
    list_contains "$features" "$k" \
      || usage_error "Unknown option for OS '$os' with profile '$profile': --$k" "$os" "$profile" "$machine"
  done
  for k in $features; do
    f_call feature_requirements feature_machine=machine -- "$k"
    default=false
    if ! list_contains "$optional" "$k" && machine_supported "$feature_machine" "$machine"; then
      default=true
    elif list_contains "$flags" "$k" && ! list_contains "$optional" "$k"; then
      warn "--$k is for machine $feature_machine, not $machine; running it since it was named"
    fi
    if list_contains "$flags" "$k" || { $all && $default; }; then
      if [[ "$mode" == capture ]]; then
        if ! feature_capturable "$k"; then
          list_contains "$flags" "$k" && warn "--$k has no capture step; skipping it"
          continue
        fi
      elif [[ "$mode" != install ]] && ! feature_uninstallable "$k"; then
        if list_contains "$flags" "$k"; then
          if [[ "$mode" == uninstall ]]; then
            warn "--$k has no uninstall step; skipping it"
          else
            warn "--$k has no uninstall step; installing it without uninstalling first"
          fi
        fi
        [[ "$mode" == uninstall ]] && continue
      fi
      enabled+="$k "
    fi
  done

  f_return enabled
}

# Run one-time install $1 and exit, after checking that nothing else was asked for: --oti can't be combined with a
# variant, OS, profile, machine, --infer ($2, a list of those given), features or --all ($3, $4), or --reinstall or
# --uninstall ($5). --help ($6) prints the usage instead. Defaults from the environment and install.conf don't apply.
run_oti_and_exit() {
  local oti="$1" dimensions="$2" flags="$3" all="$4" mode="$5" help="$6"
  ! $help || { usage "" ""; exit 0; }
  oti_exists "$oti" || usage_error "Unknown one-time install '$oti'. Available: $(available_names oti)"
  [[ -z "$dimensions" ]] || usage_error "--oti can't be combined with$dimensions"
  [[ "$flags" == " " && "$all" == false ]] || usage_error "--oti can't be combined with features or --all"
  [[ "$mode" == install ]] || usage_error "--oti can't be undone, so it takes no --$mode"
  enter_dotfiles_root
  run_oti "$oti"
  exit 0
}

# Print why install.sh in $1 can't install from $2, or nothing if it can. Everything it links points into $2, so it
# must run from that checkout ($2 may be a symlink to it), and the checkout must be named dotfiles, which the startup
# files and lint (.shellcheckrc) rely on.
explain_checkout_problem() {
  local script_dir="$1" root="$2" script_real root_real
  script_real="$(cd "$script_dir" && pwd -P)"
  if [[ ! -d "$root" ]]; then
    printf 'dotfiles must be checked out at %s' "$root"
    return
  fi
  root_real="$(cd "$root" && pwd -P)"
  if [[ "$script_real" != "$root_real" ]]; then
    printf 'this checkout (%s) is not %s (%s); run %s/install.sh instead' "$script_real" "$root" "$root_real" "$root"
  elif [[ "${root_real##*/}" != dotfiles ]]; then
    printf "the checkout must be a directory named dotfiles, not '%s' (%s links to %s)" \
      "${root_real##*/}" "$root" "$root_real"
  fi
}

enter_dotfiles_root() {
  local problem
  problem="$(explain_checkout_problem "$SCRIPT_DIR" "$DOTFILES_ROOT")"
  [[ -z "$problem" ]] || error "$problem"
  # No subshell, so the cwd persists.
  cd "$DOTFILES_ROOT"
}

# Print the words of $1 in reverse order.
reverse_words() {
  local word reversed=""
  for word in $1; do
    reversed="$word${reversed:+ $reversed}"
  done
  printf '%s' "$reversed"
}

# Run the enabled features ($3, already in the order of OS $1 with profile $2): install runs feature_<name> in order,
# uninstall runs uninstall_feature_<name> (where defined) in reverse order, and reinstall does the uninstalls then
# the installs. capture runs capture_feature_<name> instead. Each gets the OS, the profile and the enabled features.
run_features() {
  local os="$1" profile="$2" enabled="$3" mode="$4" machine="$5" feature

  info "Beginning dotfiles $mode (os: $os, profile: $profile, machine: $machine)..."
  if [[ "$mode" == capture ]]; then
    for feature in $enabled; do
      info "Capturing feature: $feature"
      "$(capture_function "$feature")" "$os" "$profile" "$enabled"
    done
  fi
  if [[ "$mode" == uninstall || "$mode" == reinstall ]]; then
    for feature in $(reverse_words "$enabled"); do
      feature_uninstallable "$feature" || continue
      info "Uninstalling feature: $feature"
      "$(uninstall_function "$feature")" "$os" "$profile" "$enabled"
    done
  fi
  if [[ "$mode" == install || "$mode" == reinstall ]]; then
    for feature in $enabled; do
      if $DRY_RUN && ! list_contains "$DRY_RUN_FEATURES" "$feature"; then
        info "[dry-run] would run feature: $feature"
        continue
      fi
      "$(feature_function "$feature")" "$os" "$profile" "$enabled"
    done
  fi
  info "dotfiles $mode complete."
}

main() {
  bootstrap "$@"
  load_install_deps

  local variant os profile machine infer flags mode all dry_run help oti enabled
  local default_variant default_os default_profile default_machine default_features
  f_call parse_args variant os profile machine infer flags mode all dry_run help oti -- "$@"
  readonly DRY_RUN="$dry_run"
  if [[ -n "$oti" ]]; then
    run_oti_and_exit "$oti" "${variant:+ --variant}${os:+ --os}${profile:+ --profile}${machine:+ --machine}$(
      $infer && echo ' --infer')" "$flags" "$all" "$mode" "$help"
  fi
  f_call variant_dimensions os profile -- "$variant" "$os" "$profile"

  # Each dimension the command line leaves out comes from the defaults, where DOTFILES_OS and DOTFILES_PROFILE override
  # DOTFILES_VARIANT's.
  f_call load_install_defaults default_variant default_os default_profile default_machine default_features \
    -- "$INSTALL_CONFIG"
  # An unknown default variant is only an error when it would have filled in an OS or profile that neither the command
  # line nor the other defaults give.
  if variant_exists "$default_variant" || [[ -z "${os:-$default_os}" || -z "${profile:-$default_profile}" ]]; then
    f_call variant_dimensions default_os=os default_profile=profile -- \
      "$default_variant" "$default_os" "$default_profile" "DOTFILES_VARIANT in the environment or $INSTALL_CONFIG"
  fi
  os="${os:-$default_os}"
  profile="${profile:-$default_profile}"
  machine="${machine:-$default_machine}"
  f_call apply_default_features flags all -- \
    "$flags" "$all" "$mode" "$default_features" "$os" "$profile" "$default_os" "$default_profile"

  f_call resolve_dimensions os profile machine -- "$os" "$profile" "$machine" "$infer"
  exit_with_usage_unless_runnable "$flags" "$all" "$help" "$([[ $# -eq 0 ]] && echo true || echo false)" \
    "$os" "$profile" "$machine"

  f_call resolve_features enabled -- "$os" "$profile" "$flags" "$all" "$mode" "$machine"
  enter_dotfiles_root
  run_features "$os" "$profile" "$enabled" "$mode" "$machine"
}

main "$@"
