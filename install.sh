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

DEFAULT_VARIANT="coder"
DRY_RUN=false

for f in "$INSTALL_DIR"/lib/*.sh "$INSTALL_DIR"/features/*.sh; do
  # shellcheck source=/dev/null
  source "$f"
done

# Exclude paths beginning with these prefixes when linking.
# Each entry is matched against `find` output exactly, or as a directory prefix.
EXCLUDE_PATHS=(
  "./.git"                          # dotfiles git repository information
  "./dump"                          # manually loaded configuration files
  "./.gitignore"
  "./install.sh"                    # this script!
  "./install"                       # the pieces of this script!
  "./README.md"                     # dotfiles readme
  "./.backup"                       # temporary backup file of modified files
  "./Sessionx.vim"                  # vim Obsession session file
  "./.claude/settings.local.json"   # needs to be merged with user settings, rather than replacing it
  "./.claude/CLAUDE.md"             # needs to be merged with user CLAUDE.md, rather than replacing it
  "./tests"                         # dotfiles tests
  "./docs"                          # dotfile docs
)

available_variants() {
  local f names=""
  for f in "$INSTALL_DIR"/variants/*.sh; do
    f="$(basename "$f" .sh)"
    names+="${names:+ }$f"
  done
  printf '%s' "$names"
}

feature_enabled() {
  case " $ENABLED " in
    *" $1 "*) return 0 ;;
    *)        return 1 ;;
  esac
}

is_variant_feature() {
  case " $VARIANT_FEATURES " in
    *" $1 "*) return 0 ;;
    *)        return 1 ;;
  esac
}

usage() {
  local f
  cat <<EOF
Usage: $(basename "$0") [--variant NAME] [OPTIONS]

dotfiles installation and configuration script. All operations are idempotent.
With no arguments, runs '--variant $DEFAULT_VARIANT --all'. See README.md for more information.

Variants (default: $DEFAULT_VARIANT):
EOF
  for f in $(available_variants); do
    printf '  %-10s %s\n' "$f" "$(. "$INSTALL_DIR/variants/$f.sh" && printf '%s' "$VARIANT_DESCRIPTION")"
  done
  cat <<EOF

Options for variant '$VARIANT':
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

# --- Flag parsing ---
if [[ $# -eq 0 ]]; then
  set -- --all
fi

# First pass: the variant decides which feature flags are valid.
VARIANT="$DEFAULT_VARIANT"
WANT_HELP=false
args=("$@")
i=0
while [[ $i -lt ${#args[@]} ]]; do
  case "${args[$i]}" in
    --variant)   i=$((i + 1)); VARIANT="${args[$i]:-}" ;;
    --variant=*) VARIANT="${args[$i]#--variant=}" ;;
    --help|-h)   WANT_HELP=true ;;
  esac
  i=$((i + 1))
done

[[ -f "$INSTALL_DIR/variants/$VARIANT.sh" ]] \
  || error "Unknown variant '$VARIANT'. Available variants: $(available_variants)"
# shellcheck source=/dev/null
source "$INSTALL_DIR/variants/$VARIANT.sh"

if $WANT_HELP; then
  usage
  exit 0
fi

# Second pass: feature flags. Order of ENABLED is irrelevant; VARIANT_FEATURES determines run order.
ENABLED=" "
while [[ $# -gt 0 ]]; do
  case "$1" in
    --variant)   shift 2 ;;
    --variant=*) shift ;;
    --all)
      for k in $VARIANT_FEATURES; do
        case " $VARIANT_ALL_EXCLUDE " in
          *" $k "*) ;;
          *)        ENABLED+="$k " ;;
        esac
      done
      shift
      ;;
    --dry-run) DRY_RUN=true; shift ;;
    --*)
      key="${1#--}"
      if ! is_variant_feature "$key"; then
        warn "Unknown option for variant '$VARIANT': $1"
        usage
        exit 1
      fi
      ENABLED+="$key "
      shift
      ;;
    *) usage; exit 1 ;;
  esac
done

if [[ "$ENABLED" == " " ]]; then
  usage
  exit 0
fi

# Ensure dotfiles dir exists and switch to it (no subshell, so cwd persists).
[[ -d "$DOTFILES_ROOT" ]] || error "dotfiles must be at $DOTFILES_ROOT."
cd "$DOTFILES_ROOT"

# --- Main ---
info "Beginning dotfiles installation (variant: $VARIANT)..."

for feature in $VARIANT_FEATURES; do
  feature_enabled "$feature" || continue
  if $DRY_RUN && ! feature_supports_dry_run "$feature"; then
    info "[dry-run] would run feature: $feature"
    continue
  fi
  "$(feature_function "$feature")"
done

info "dotfiles installation complete."
