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

# Outputs: features, every feature with a feature_<name> function in install/features.
scan_features() {
  local features
  features="$(sed -n 's/^feature_\([a-z0-9_]*\)() *{.*/\1/p' "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/features/*/*.sh \
    | tr '\n' ' ')"
  f_return features="$features"
}

# Print the directory under install/features holding feature $1's function: empty for the top level, else its
# subdirectory's name.
feature_dir() {
  local file
  file="$(grep -l "^$(feature_function "$1")()" "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/features/*/*.sh | head -1)"
  file="${file#"$INSTALL_DIR"/features/}"
  [[ "$file" != */* ]] || printf '%s' "${file%%/*}"
}

# Outputs: problems, a line if feature $1, for machines $2 and OSes $3, isn't where its tags put it: features for any
# machine at the top of install/features, the others in a subdirectory named <os>_<machine> after their single
# @os and @machine values.
check_feature_dir() {
  local feature="$1" machine="$2" os="$3" dir problems=""
  dir="$(feature_dir "$feature")"
  if [[ "$machine" == any ]]; then
    [[ -z "$dir" ]] || problems="--$feature: is for any machine, so belongs in install/features, not $dir/"$'\n'
  elif [[ "$machine" == *" "* || "$os" == *" "* ]]; then
    problems="--$feature: a feature for specific hardware needs a single @os and @machine, to sit in <os>_<machine>/"$'\n'
  elif [[ "$dir" != "${os}_$machine" ]]; then
    problems="--$feature: belongs in install/features/${os}_$machine/ (its @os and @machine), not ${dir:-the top level}"$'\n'
  fi
  f_return problems="$problems"
}

# Outputs: problems, one line per problem with value list $3 of tag @$2 on feature $1, given allowed values $4.
check_tag() {
  local feature="$1" tag="$2" values="$3" allowed="$4" nl=$'\n' problems="" v
  [[ -n "$values" ]] || problems+="--$feature: missing @$tag tag above $(feature_function "$feature")$nl"
  for v in $values; do
    list_contains "$allowed" "$v" || problems+="--$feature: @$tag '$v' is not one of: $allowed$nl"
  done
  f_return problems="$problems"
}

# Outputs: problems, one line per problem with the layout of doc $2 of feature $1: description lines, a bare '#'
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
  f_return problems="$problems"
}

# Outputs: problems, one line per problem with the documentation of feature $1. $2 is every known feature.
check_feature_docs() {
  local feature="$1" known="$2" problems="" dep doc found machine os gui requires
  [[ -n "$(feature_description "$feature")" ]] \
    || problems+="--$feature: no feature_description entry"$'\n'

  f_call feature_doc doc -- "$feature"
  f_call check_doc_layout found=problems -- "$feature" "$doc"
  problems+="$found"

  f_call feature_requirements machine os gui requires -- "$feature"
  f_call check_tag found=problems -- "$feature" machine "$machine" "$FEATURE_MACHINES"
  problems+="$found"
  f_call check_tag found=problems -- "$feature" os "$os" "$FEATURE_OSES"
  problems+="$found"
  f_call check_tag found=problems -- "$feature" gui "$gui" "$FEATURE_GUIS"
  problems+="$found"
  if [[ -n "$machine" && -n "$os" ]]; then
    f_call check_feature_dir found=problems -- "$feature" "$machine" "$os"
    problems+="$found"
  fi
  for dep in $requires; do
    list_contains "$known" "$dep" || problems+="--$feature: @requires '$dep' is not a feature"$'\n'
  done

  f_return problems="$problems"
}

# Outputs: problems, one line per problem with feature $2 in OS and profile $1 (as os/profile), which target
# platforms $3, GUI $4 and machines $5. $6 is the features that run before this one.
check_feature() {
  local setup="$1" feature="$2" platforms="$3" gui="$4" os_machines="$5" earlier="$6" nl=$'\n' problems="" v dep suited
  local machine os feature_gui requires

  if ! declare -F "$(feature_function "$feature")" >/dev/null; then
    f_return problems="$setup: --$feature has no $(feature_function "$feature") function$nl"
    return
  fi

  # Missing tags are reported once by check_feature_docs.
  f_call feature_requirements machine os feature_gui=gui requires -- "$feature"
  [[ -n "$os" ]] || platforms=""
  [[ -n "$feature_gui" ]] || gui=""
  for v in $platforms; do
    os_supported "$os" "$v" || problems+="$setup: --$feature supports os '$os', not '$v'$nl"
  done
  for v in $gui; do
    gui_supported "$feature_gui" "$v" || problems+="$setup: --$feature supports gui '$feature_gui', not '$v'$nl"
  done
  if [[ -n "$machine" ]]; then
    suited=false
    for v in $os_machines; do
      machine_supported "$machine" "$v" && suited=true
    done
    $suited || problems+="$setup: --$feature is for machine '$machine', which the OS doesn't support ($os_machines)$nl"
  fi
  for dep in $requires; do
    list_contains "$earlier" "$dep" || problems+="$setup: --$feature requires --$dep earlier in its features$nl"
  done

  f_return problems="$problems"
}

# Outputs: problems, one line per problem with OS $1 with profile $2.
check_setup() {
  local os="$1" profile="$2" setup="$1/$2" problems="" earlier=" " feature k path found
  # shellcheck disable=SC2034 # git_fsmonitor isn't read: asking for it checks every OS and profile returns it
  local features optional platforms gui os_machines link_paths git_fsmonitor
  f_call os_profile_config features optional platforms gui os_machines=machines link_paths git_fsmonitor -- \
    "$os" "$profile"

  for feature in $features; do
    f_call check_feature found=problems -- "$setup" "$feature" "$platforms" "$gui" "$os_machines" "$earlier"
    problems+="$found"
    earlier+="$feature "
  done
  for k in $optional; do
    list_contains "$features" "$k" || problems+="$setup: optional names unknown feature '$k'"$'\n'
  done
  # Features copy some files under root/ into place, so a linked directory there could link them too.
  for path in $link_paths; do
    if [[ ! -e "$REPO_ROOT/$path" ]]; then
      problems+="$setup: link path $path does not exist"$'\n'
    elif [[ "$path" == root/* && ! -f "$REPO_ROOT/$path" ]]; then
      problems+="$setup: link path $path is a directory; list the files under root/ to link one by one"$'\n'
    fi
  done

  f_return problems="$problems"
}

# Outputs: problems, one line per problem with OS $1: its platforms and machines must be known values, and it must
# support some profile.
check_os() {
  local os="$1" problems="" v platforms os_machines
  f_call os_config platforms os_machines=machines -- "$os"
  [[ -n "$platforms" ]] || problems+="os $os: returns no platforms"$'\n'
  for v in $platforms; do
    list_contains "$FEATURE_OSES" "$v" || problems+="os $os: platform '$v' is not one of: $FEATURE_OSES"$'\n'
  done
  [[ -n "$os_machines" ]] || problems+="os $os: returns no machines"$'\n'
  for v in $os_machines; do
    list_contains "$MACHINES" "$v" || problems+="os $os: machine '$v' is not one of: $MACHINES"$'\n'
  done
  [[ -n "$(os_profiles "$os")" ]] || problems+="os $os: defines no os_${os}_<profile> function"$'\n'
  f_return problems="$problems"
}

# Outputs: problems, a line if variant $1 doesn't name an OS and profile that go together.
check_variant() {
  local os profile problems=""
  f_call variant_config os profile -- "$1"
  os_supports_profile "$os" "$profile" \
    || problems="variant $1: OS '$os' with profile '$profile' isn't defined (no os_${os}_$profile)"$'\n'
  f_return problems="$problems"
}

main() {
  local variant os profile problems="" known feature k found
  f_call scan_features known=features

  for feature in $known; do
    f_call check_feature_docs found=problems -- "$feature" "$known"
    problems+="$found"
  done
  for os in $(available_names os); do
    f_call check_os found=problems -- "$os"
    problems+="$found"
    for profile in $(os_profiles "$os"); do
      f_call check_setup found=problems -- "$os" "$profile"
      problems+="$found"
    done
  done
  for variant in $(available_names variants); do
    f_call check_variant found=problems -- "$variant"
    problems+="$found"
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
