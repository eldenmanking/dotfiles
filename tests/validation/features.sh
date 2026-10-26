#!/usr/bin/env bash
# Validate the feature, OS, profile and variant registry without installing anything: every feature_<name> function in
# install/features is documented (a feature_description entry, and a doc comment with a description and @machine, @os
# and @gui tags), every feature for specific hardware sits in install/features/<os>_<machine>/, every OS names known
# platforms and machines, the features of every OS and profile exist, suit its platforms, GUI and machines, and come
# after the features they require, its link paths exist, naming single files under root/, and every variant names an
# OS and profile that go together. Run via `make validate`.

set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

INSTALL_DIR="$REPO_ROOT/install"
# Feature files read these at load time; point them at this checkout.
DOTFILES_ROOT="$REPO_ROOT"
BACKUPS_ROOT="$DOTFILES_ROOT/.backup"
LOCAL_PREFIX="$HOME/.local"
LOCAL_BIN="$LOCAL_PREFIX/bin"
DRY_RUN=true

for f in "$INSTALL_DIR"/lib/*.sh "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/features/*/*.sh \
  "$INSTALL_DIR"/os/*.sh "$INSTALL_DIR"/profiles/*.sh "$INSTALL_DIR"/variants/*.sh; do
  # shellcheck source=/dev/null
  source "$f"
done

# Outputs: _features, every feature with a feature_<name> function in install/features.
scan_features() {
  _features="$(sed -n 's/^feature_\([a-z0-9_]*\)() *{.*/\1/p' "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/features/*/*.sh \
    | tr '\n' ' ')"
}

# Print the directory under install/features holding feature $1's function: empty for the top level, else its
# subdirectory's name.
feature_dir() {
  local file
  file="$(grep -l "^$(feature_function "$1")()" "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/features/*/*.sh | head -1)"
  file="${file#"$INSTALL_DIR"/features/}"
  [[ "$file" != */* ]] || printf '%s' "${file%%/*}"
}

# Outputs: _problems, a line if feature $1, for machines $2 and OSes $3, isn't where its tags put it: features for any
# machine at the top of install/features, the others in a subdirectory named <os>_<machine> after their single
# @os and @machine values.
check_feature_dir() {
  local feature="$1" machine="$2" os="$3" dir
  dir="$(feature_dir "$feature")"
  _problems=""
  if [[ "$machine" == any ]]; then
    [[ -z "$dir" ]] || _problems="--$feature: is for any machine, so belongs in install/features, not $dir/"$'\n'
  elif [[ "$machine" == *" "* || "$os" == *" "* ]]; then
    _problems="--$feature: a feature for specific hardware needs a single @os and @machine, to sit in <os>_<machine>/"$'\n'
  elif [[ "$dir" != "${os}_$machine" ]]; then
    _problems="--$feature: belongs in install/features/${os}_$machine/ (its @os and @machine), not ${dir:-the top level}"$'\n'
  fi
}

# Outputs: _problems, one line per problem with value list $3 of tag @$2 on feature $1, given allowed values $4.
check_tag() {
  local feature="$1" tag="$2" values="$3" allowed="$4" nl=$'\n' problems="" v
  [[ -n "$values" ]] || problems+="--$feature: missing @$tag tag above $(feature_function "$feature")$nl"
  for v in $values; do
    list_contains "$allowed" "$v" || problems+="--$feature: @$tag '$v' is not one of: $allowed$nl"
  done
  _problems="$problems"
}

# Outputs: _problems, one line per problem with the layout of doc $2 of feature $1: description lines, a bare '#'
# line, then only tags.
check_doc_layout() {
  local feature="$1" doc="$2" nl=$'\n' problems="" line state=start
  while IFS= read -r line; do
    case "$state:$line" in
      start:)                state=start ;;
      start:@*)              problems+="--$feature: doc has no description before its tags$nl"; state=tags ;;
      start:*)               state=description ;;
      description:)          state=blank ;;
      description:@*)        problems+="--$feature: doc needs a bare '#' line between description and tags$nl"
                             state=tags ;;
      description:*|blank:)  ;;
      blank:@*)              state=tags ;;
      blank:*)               state=description ;;
      tags:@*)               ;;
      tags:*)                problems+="--$feature: doc has '$line' after its tags; tags go last$nl"; break ;;
    esac
  done <<< "$doc"
  [[ "$state" != start ]] || problems+="--$feature: no doc comment above $(feature_function "$feature")$nl"
  _problems="$problems"
}

# Outputs: _problems, one line per problem with the documentation of feature $1. $2 is every known feature.
check_feature_docs() {
  local feature="$1" known="$2" problems="" dep
  [[ -n "$(feature_description "$feature")" ]] \
    || problems+="--$feature: no feature_description entry"$'\n'

  f_write_args feature_doc _doc -- "$feature"
  f_write_args check_doc_layout _problems -- "$feature" "$_doc"
  problems+="$_problems"

  f_write_args feature_requirements _machine _os _gui _requires -- "$feature"
  local machine="$_machine" os="$_os" gui="$_gui" requires="$_requires"
  f_write_args check_tag _problems -- "$feature" machine "$machine" "$FEATURE_MACHINES"
  problems+="$_problems"
  f_write_args check_tag _problems -- "$feature" os "$os" "$FEATURE_OSES"
  problems+="$_problems"
  f_write_args check_tag _problems -- "$feature" gui "$gui" "$FEATURE_GUIS"
  problems+="$_problems"
  if [[ -n "$machine" && -n "$os" ]]; then
    f_write_args check_feature_dir _problems -- "$feature" "$machine" "$os"
    problems+="$_problems"
  fi
  for dep in $requires; do
    list_contains "$known" "$dep" || problems+="--$feature: @requires '$dep' is not a feature"$'\n'
  done

  _problems="$problems"
}

# Outputs: _problems, one line per problem with feature $2 in OS and profile $1 (as os/profile), which target
# platforms $3, GUI $4 and machines $5. $6 is the features that run before this one.
check_feature() {
  local setup="$1" feature="$2" platforms="$3" gui="$4" os_machines="$5" earlier="$6" nl=$'\n' problems="" v dep suited

  if ! declare -F "$(feature_function "$feature")" >/dev/null; then
    _problems="$setup: --$feature has no $(feature_function "$feature") function$nl"
    return
  fi

  # Missing tags are reported once by check_feature_docs.
  f_write_args feature_requirements _machine _os _gui _requires -- "$feature"
  [[ -n "$_os" ]] || platforms=""
  [[ -n "$_gui" ]] || gui=""
  for v in $platforms; do
    os_supported "$_os" "$v" || problems+="$setup: --$feature supports os '$_os', not '$v'$nl"
  done
  for v in $gui; do
    gui_supported "$_gui" "$v" || problems+="$setup: --$feature supports gui '$_gui', not '$v'$nl"
  done
  if [[ -n "$_machine" ]]; then
    suited=false
    for v in $os_machines; do
      machine_supported "$_machine" "$v" && suited=true
    done
    $suited || problems+="$setup: --$feature is for machine '$_machine', which the OS doesn't support ($os_machines)$nl"
  fi
  for dep in $_requires; do
    list_contains "$earlier" "$dep" || problems+="$setup: --$feature requires --$dep earlier in _features$nl"
  done

  _problems="$problems"
}

# Outputs: _problems, one line per problem with OS $1 with profile $2.
check_setup() {
  local os="$1" profile="$2" setup="$1/$2" problems="" earlier=" " feature k path
  f_write_args os_profile_config _features _optional _platforms _gui _machines _link_paths _git_fsmonitor -- \
    "$os" "$profile"
  local features="$_features" optional="$_optional" platforms="$_platforms" gui="$_gui" os_machines="$_machines"
  local link_paths="$_link_paths"

  for feature in $features; do
    f_write_args check_feature _problems -- "$setup" "$feature" "$platforms" "$gui" "$os_machines" "$earlier"
    problems+="$_problems"
    earlier+="$feature "
  done
  for k in $optional; do
    list_contains "$features" "$k" || problems+="$setup: _optional names unknown feature '$k'"$'\n'
  done
  # Features copy some files under root/ into place, so a linked directory there could link them too.
  for path in $link_paths; do
    if [[ ! -e "$REPO_ROOT/$path" ]]; then
      problems+="$setup: link path $path does not exist"$'\n'
    elif [[ "$path" == root/* && ! -f "$REPO_ROOT/$path" ]]; then
      problems+="$setup: link path $path is a directory; list the files under root/ to link one by one"$'\n'
    fi
  done

  _problems="$problems"
}

# Outputs: _problems, one line per problem with OS $1: its platforms and machines must be known values, and it must
# support some profile.
check_os() {
  local os="$1" problems="" v
  f_write_args os_config _platforms _machines -- "$os"
  [[ -n "$_platforms" ]] || problems+="os $os: no _platforms"$'\n'
  for v in $_platforms; do
    list_contains "$FEATURE_OSES" "$v" || problems+="os $os: platform '$v' is not one of: $FEATURE_OSES"$'\n'
  done
  [[ -n "$_machines" ]] || problems+="os $os: no _machines"$'\n'
  for v in $_machines; do
    list_contains "$MACHINES" "$v" || problems+="os $os: machine '$v' is not one of: $MACHINES"$'\n'
  done
  [[ -n "$(os_profiles "$os")" ]] || problems+="os $os: defines no os_${os}_<profile> function"$'\n'
  _problems="$problems"
}

# Outputs: _problems, a line if variant $1 doesn't name an OS and profile that go together.
check_variant() {
  f_write_args variant_config _os _profile -- "$1"
  _problems=""
  os_supports_profile "$_os" "$_profile" \
    || _problems="variant $1: OS '$_os' with profile '$_profile' isn't defined (no os_${_os}_$_profile)"$'\n'
}

main() {
  local variant os profile problems="" known feature k
  f_write_args scan_features _features
  known="$_features"

  for feature in $known; do
    f_write_args check_feature_docs _problems -- "$feature" "$known"
    problems+="$_problems"
  done
  for os in $(available_names os); do
    f_write_args check_os _problems -- "$os"
    problems+="$_problems"
    for profile in $(os_profiles "$os"); do
      f_write_args check_setup _problems -- "$os" "$profile"
      problems+="$_problems"
    done
  done
  for variant in $(available_names variants); do
    f_write_args check_variant _problems -- "$variant"
    problems+="$_problems"
  done
  for k in $DRY_RUN_FEATURES; do
    list_contains "$known" "$k" || problems+="DRY_RUN_FEATURES names unknown feature '$k'"$'\n'
  done

  if [[ -n "$problems" ]]; then
    printf '%s' "$problems" | while IFS= read -r line; do warn "$line"; done
    error "validation failed"
  fi
  info "All OSes, profiles, variants and features are valid."
}

main "$@"
