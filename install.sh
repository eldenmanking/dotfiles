#!/usr/bin/env bash

################################################################################
# Program: install.sh
# Description: Installs essential packages for configuration and creates
#              symlinks in the proper locations. Supports several variants
#              (see install/variants/) and toggles features with flags.
# Location: ~/dotfiles/install.sh
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR/install"
DOTFILES_ROOT="$HOME/dotfiles"
BACKUPS_ROOT="$DOTFILES_ROOT/.backup"
LOCAL_PREFIX="$HOME/.local"
LOCAL_BIN="$LOCAL_PREFIX/bin"

DRY_RUN=false
VARIANT_NAME=""
ENABLED=" "

for f in "$INSTALL_DIR"/lib/*.sh "$INSTALL_DIR"/features/*.sh; do
  # shellcheck source=/dev/null
  source "$f"
done

available_variants() {
  local f names=""
  for f in "$INSTALL_DIR"/variants/*.sh; do
    f="$(basename "$f" .sh)"
    names+="${names:+ }$f"
  done
  printf '%s' "$names"
}

variant_file() {
  printf '%s/variants/%s.sh' "$INSTALL_DIR" "$1"
}

feature_enabled() {
  list_contains "$ENABLED" "$1"
}

usage() {
  local f
  cat <<EOF
Usage: $(basename "$0") --variant NAME [OPTIONS]

dotfiles installation and configuration script. All operations are idempotent.
Run '$(basename "$0") --variant NAME --help' to list the options of a variant.
See README.md for more information.

Variants:
EOF
  for f in $(available_variants); do
    printf '  %-10s %s\n' "$f" "$(. "$(variant_file "$f")" && printf '%s' "$VARIANT_DESCRIPTION")"
  done
  [[ -n "$VARIANT_NAME" ]] || return 0
  cat <<EOF

Options for variant '$VARIANT_NAME':
  --variant NAME   select the variant
  --all            install all options${VARIANT_ALL_EXCLUDE:+ (except: $VARIANT_ALL_EXCLUDE)}
EOF
  for f in $VARIANT_FEATURES; do
    printf '  --%-14s %s\n' "$f" "$(feature_description "$f")"
  done
  cat <<EOF
  --dry-run        print what would happen without making changes
  --help           show this help page
EOF
}

usage_error() {
  warn "$1"
  usage >&2
  exit 1
}

parse_args() {
  f_begin "$FUNCNAME" variant flags all dry_run help
  local variant="" flags=" " all=false dry_run=false help=false

  [[ $# -gt 0 ]] || help=true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --variant)
        [[ $# -ge 2 ]] || usage_error "--variant requires a value"
        variant="$2"
        shift 2
        ;;
      --variant=*) variant="${1#--variant=}"; shift ;;
      --all)       all=true; shift ;;
      --dry-run)   dry_run=true; shift ;;
      --help|-h)   help=true; shift ;;
      --?*)        flags+="${1#--} "; shift ;;
      *)           usage_error "Unexpected argument: $1" ;;
    esac
  done

  f_parse_args_variant="$variant"
  f_parse_args_flags="$flags"
  f_parse_args_all="$all"
  f_parse_args_dry_run="$dry_run"
  f_parse_args_help="$help"
  f_end "$FUNCNAME" variant flags all dry_run help
}

load_variant() {
  local name="$1" help="$2"
  if [[ -z "$name" ]]; then
    $help || usage_error "--variant is required"
    usage
    exit 0
  fi
  [[ -f "$(variant_file "$name")" ]] \
    || usage_error "Unknown variant '$name'. Available variants: $(available_variants)"
  # shellcheck source=/dev/null
  source "$(variant_file "$name")"
  VARIANT_NAME="$name"
}

exit_with_usage_if_nothing_to_do() {
  local help="$1" flags="$2" all="$3"
  if $help || { [[ "$flags" == " " ]] && ! $all; }; then
    usage
    exit 0
  fi
}

resolve_features() {
  f_begin "$FUNCNAME" enabled
  local flags="$1" all="$2" enabled=" " k

  for k in $flags; do
    list_contains "$VARIANT_FEATURES" "$k" \
      || usage_error "Unknown option for variant '$VARIANT_NAME': --$k"
  done
  for k in $VARIANT_FEATURES; do
    if list_contains "$flags" "$k" || { $all && ! list_contains "$VARIANT_ALL_EXCLUDE" "$k"; }; then
      enabled+="$k "
    fi
  done

  f_resolve_features_enabled="$enabled"
  f_end "$FUNCNAME" enabled
}

enter_dotfiles_root() {
  # Ensure dotfiles dir exists and switch to it (no subshell, so cwd persists).
  [[ -d "$DOTFILES_ROOT" ]] || error "dotfiles must be at $DOTFILES_ROOT."
  cd "$DOTFILES_ROOT"
}

run_features() {
  local feature
  info "Beginning dotfiles installation (variant: $VARIANT_NAME)..."
  for feature in $VARIANT_FEATURES; do
    feature_enabled "$feature" || continue
    if $DRY_RUN && ! list_contains "$DRY_RUN_FEATURES" "$feature"; then
      info "[dry-run] would run feature: $feature"
      continue
    fi
    "$(feature_function "$feature")"
  done
  info "dotfiles installation complete."
}

main() {
  f_prepare_args parse_args variant flags all dry_run help
  parse_args "$@"
  DRY_RUN="$f_parse_args_dry_run"

  load_variant "$f_parse_args_variant" "$f_parse_args_help"
  exit_with_usage_if_nothing_to_do "$f_parse_args_help" "$f_parse_args_flags" "$f_parse_args_all"

  f_prepare_args resolve_features enabled
  resolve_features "$f_parse_args_flags" "$f_parse_args_all"
  ENABLED="$f_resolve_features_enabled"

  enter_dotfiles_root
  run_features
}

main "$@"
