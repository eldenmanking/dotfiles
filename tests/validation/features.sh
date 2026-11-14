#!/usr/bin/env bash
# Validate the feature, OS, profile and variant registry without installing anything: every feature has a
# feature_description entry and every implementation of it (feature_<name>, or each feature_<name>__<dir>) a doc comment
# with a description and @machine, @os and @gui tags, no feature function is defined twice, every feature for specific
# hardware and every implementation sits in the install/features/<dir>/ its tags name, every OS names known platforms
# and machines, the features of every OS and profile exist, have exactly one implementation that suits its platforms,
# GUI and each of its machines (or, for hardware-specific ones, some of them), and come after the features they
# require, its link paths exist, naming single files under root/, and every variant names an OS and profile that go
# together, and every one-time install in install/oti defines its function and description and no uninstall. Run via
# `make validate`.

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
  "$INSTALL_DIR"/os/*.sh "$INSTALL_DIR"/profiles/*.sh "$INSTALL_DIR"/variants/*.sh "$INSTALL_DIR"/oti/*.sh; do
  # shellcheck source=/dev/null
  source "$f"
done

# Find every feature with a feature_<name> function, or feature_<name>__<dir> implementations, in install/features.
# Usage: f_call scan_features features
# Returns: features
#   features: each feature name once, without the __<dir> of its implementations
scan_features() {
  local features="" name
  while IFS= read -r name; do
    name="$(implementation_feature "$name")"
    list_contains "$features" "$name" || features+="${features:+ }$name"
  done < <(sed -n 's/^feature_\([a-z0-9_]*\)() *{.*/\1/p' "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/features/*/*.sh)
  f_return features
}

# Check that no feature, uninstall or capture function is defined in more than one place in install/features: bash
# would quietly keep the last one sourced.
# Usage: f_call check_duplicates problems
# Returns: problems
#   problems: a line for each function defined more than once
check_duplicates() {
  local problems="" fn
  for fn in $(sed -n 's/^\(\(uninstall_\|capture_\)\{0,1\}feature_[a-z0-9_]*\)() *{.*/\1/p' \
    "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/features/*/*.sh | sort | uniq -d); do
    problems+="$fn is defined more than once in install/features"$'\n'
  done
  f_return problems
}

# Print the directory under install/features holding the function of feature or implementation <impl>: empty for the
# top level, else its subdirectory's name.
# Usage: feature_dir <impl>
feature_dir() {
  local file
  file="$(grep -l "^$(feature_function "$1")()" "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/features/*/*.sh | head -1)"
  file="${file#"$INSTALL_DIR"/features/}"
  [[ "$file" != */* ]] || printf '%s' "${file%%/*}"
}

# Check that feature or implementation <impl>, for machines <machine>, OSes <os> and GUIs <gui>, is where its tags
# put it: a feature with one implementation for any machine at the top of install/features, and the others (features
# for specific hardware, and each feature_<name>__<dir> implementation) in the subdirectory implementation_dir names
# after their single @os, @machine and @gui values, which an implementation's id also ends with (__<dir>).
# Usage: f_call check_feature_dir problems -- <impl> <machine> <os> <gui>
# Returns: problems
#   problems: a line if it isn't
check_feature_dir() {
  local impl="$1" machine="$2" os="$3" gui="$4" dir want problems="" nl=$'\n'
  dir="$(feature_dir "$impl")"
  if [[ "$impl" != *__* && "$machine" == any ]]; then
    [[ -z "$dir" ]] || problems="--$impl: is for any machine, so belongs in install/features, not $dir/$nl"
  elif [[ "$machine" == *" "* || "$os" == *" "* || "$gui" == *" "* ]]; then
    problems="--$impl: a feature for specific hardware or an implementation needs a single @os, @machine and @gui,"
    problems+=" to sit in install/features/<os>[_<machine>][_<gui>]/$nl"
  else
    want="$(implementation_dir "$machine" "$os" "$gui")"
    if [[ "$dir" != "$want" ]]; then
      problems="--$impl: belongs in install/features/$want/ (its @os, @machine and @gui), not ${dir:-the top level}$nl"
    elif [[ "$impl" == *__* && "${impl#*__}" != "$want" ]]; then
      problems="--$impl: an implementation in $want/ is named feature_$(implementation_feature "$impl")__$want$nl"
    fi
  fi
  f_return problems
}

# Check value list <values> of tag @<tag> on feature <feature> against allowed values <allowed>.
# Usage: f_call check_tag problems -- <feature> <tag> <values> <allowed>
# Returns: problems
#   problems: one line per problem
check_tag() {
  local feature="$1" tag="$2" values="$3" allowed="$4" nl=$'\n' problems="" v
  [[ -n "$values" ]] || problems+="--$feature: missing @$tag tag above $(feature_function "$feature")$nl"
  for v in $values; do
    list_contains "$allowed" "$v" || problems+="--$feature: @$tag '$v' is not one of: $allowed$nl"
  done
  f_return problems
}

# Check the layout of doc <doc> of feature <feature>: description lines, a bare '#' line, then only tags.
# Usage: f_call check_doc_layout problems -- <feature> <doc>
# Returns: problems
#   problems: one line per problem
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
  f_return problems
}

# Check the documentation of feature <feature>: its feature_description entry, and the doc, tags and place of each of
# its implementations. A feature has either a single feature_<name> or feature_<name>__<dir> implementations, not both.
# Usage: f_call check_feature_docs problems -- <feature> <known>
#   <known>: every known feature
# Returns: problems
#   problems: one line per problem
check_feature_docs() {
  local feature="$1" known="$2" problems="" dep doc found machine os gui requires impl impls
  [[ -n "$(feature_description "$feature")" ]] \
    || problems+="--$feature: no feature_description entry"$'\n'
  impls="$(feature_implementations "$feature")"
  if list_contains "$impls" "$feature" && [[ "$impls" == *" "* ]]; then
    problems+="--$feature: has implementations ($impls), so defines no plain $(feature_function "$feature")"$'\n'
  fi

  for impl in $impls; do
    f_call feature_doc doc -- "$impl"
    f_call check_doc_layout found=problems -- "$impl" "$doc"
    problems+="$found"

    f_call feature_requirements machine os gui requires -- "$impl"
    f_call check_tag found=problems -- "$impl" machine "$machine" "$FEATURE_MACHINES"
    problems+="$found"
    f_call check_tag found=problems -- "$impl" os "$os" "$FEATURE_OSES"
    problems+="$found"
    f_call check_tag found=problems -- "$impl" gui "$gui" "$FEATURE_GUIS"
    problems+="$found"
    if [[ -n "$machine" && -n "$os" && -n "$gui" ]]; then
      f_call check_feature_dir found=problems -- "$impl" "$machine" "$os" "$gui"
      problems+="$found"
    fi
    for dep in $requires; do
      list_contains "$known" "$dep" || problems+="--$impl: @requires '$dep' is not a feature"$'\n'
    done
  done

  f_return problems
}

# Check that implementation <impl> suits platforms <platforms>, GUI <gui> and some machine in <machines>.
# Usage: f_call check_suits problems -- <setup> <impl> <platforms> <gui> <machines>
# Returns: problems
#   problems: one line per tag that doesn't suit
check_suits() {
  local setup="$1" impl="$2" platforms="$3" gui="$4" os_machines="$5" nl=$'\n' problems="" v suited
  local machine os impl_gui
  # Missing tags are reported once by check_feature_docs.
  f_call feature_requirements machine os impl_gui=gui -- "$impl"
  [[ -n "$os" ]] || platforms=""
  [[ -n "$impl_gui" ]] || gui=""
  for v in $platforms; do
    os_supported "$os" "$v" || problems+="$setup: --$impl supports os '$os', not '$v'$nl"
  done
  for v in $gui; do
    gui_supported "$impl_gui" "$v" || problems+="$setup: --$impl supports gui '$impl_gui', not '$v'$nl"
  done
  if [[ -n "$machine" ]]; then
    suited=false
    for v in $os_machines; do
      machine_supported "$machine" "$v" && suited=true
    done
    $suited || problems+="$setup: --$impl is for machine '$machine', which the OS doesn't support ($os_machines)$nl"
  fi
  f_return problems
}

# Check feature <feature> in OS and profile <setup> (as os/profile), which target platforms <platforms>, GUI <gui>
# and machines <machines>: a feature with one implementation must suit them (some of the machines, for hardware-specific
# ones), and of a feature's several implementations, exactly one must suit the platforms and GUI on each machine that
# any of them suits. Each implementation that can run must come after the features it requires.
# Usage: f_call check_feature problems -- <setup> <feature> <platforms> <gui> <machines> <earlier>
#   <earlier>: the features that run before this one
# Returns: problems
#   problems: one line per problem
check_feature() {
  local setup="$1" feature="$2" platforms="$3" gui="$4" os_machines="$5" earlier="$6" nl=$'\n' problems="" dep
  local impls impl candidates="" matches m runs="" requires found

  impls="$(feature_implementations "$feature")"
  if [[ -z "$impls" ]]; then
    f_return problems="$setup: --$feature has no $(feature_function "$feature") function or implementations$nl"
    return
  fi

  if [[ "$impls" != *" "* ]]; then
    f_call check_suits found=problems -- "$setup" "$impls" "$platforms" "$gui" "$os_machines"
    problems+="$found"
    runs="$impls"
  else
    for impl in $impls; do
      implementation_suits "$impl" "$platforms" "$gui" && candidates+="${candidates:+ }$impl"
    done
    [[ -n "$candidates" ]] \
      || problems+="$setup: --$feature has no implementation for platforms '$platforms' with gui '$gui' ($impls)$nl"
    for m in $os_machines; do
      matches=""
      for impl in $candidates; do
        implementation_suits "$impl" "$platforms" "$gui" "$m" && matches+="${matches:+ }$impl"
      done
      [[ "$matches" != *" "* ]] || problems+="$setup: --$feature has several implementations for machine $m: $matches$nl"
      for impl in $matches; do
        list_contains "$runs" "$impl" || runs+="${runs:+ }$impl"
      done
    done
    [[ -z "$candidates" || -n "$runs" ]] \
      || problems+="$setup: --$feature has no implementation for a machine the OS supports ($os_machines)$nl"
  fi
  for impl in $runs; do
    f_call feature_requirements requires -- "$impl"
    for dep in $requires; do
      list_contains "$earlier" "$dep" || problems+="$setup: --$impl requires --$dep earlier in its features$nl"
    done
  done

  f_return problems
}

# Check OS <os> with profile <profile>.
# Usage: f_call check_setup problems -- <os> <profile>
# Returns: problems
#   problems: one line per problem
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

  f_return problems
}

# Check OS <os>: its platforms and machines must be known values, and it must support some profile.
# Usage: f_call check_os problems -- <os>
# Returns: problems
#   problems: one line per problem
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
  f_return problems
}

# Check that variant <variant> names an OS and profile that go together.
# Usage: f_call check_variant problems -- <variant>
# Returns: problems
#   problems: a line if it doesn't
check_variant() {
  local os profile problems=""
  f_call variant_config os profile -- "$1"
  os_supports_profile "$os" "$profile" \
    || problems="variant $1: OS '$os' with profile '$profile' isn't defined (no os_${os}_$profile)"$'\n'
  f_return problems
}

# Check one-time install <oti> (install/oti/<oti>.sh): it must define oti_<name> and oti_config_<name> (which
# returns a description), and no uninstall functions, since one-time installs can't be undone.
# Usage: f_call check_oti problems -- <oti>
# Returns: problems
#   problems: one line per problem
check_oti() {
  local oti="$1" fn file="$INSTALL_DIR/oti/$1.sh" problems="" description
  fn="$(oti_function "$oti")"
  grep -q "^$fn() *{" "$file" || problems+="oti $oti: $file defines no $fn"$'\n'
  if grep -q "^oti_config_${fn#oti_}() *{" "$file"; then
    f_call oti_config description -- "$oti"
    [[ -n "$description" ]] || problems+="oti $oti: oti_config_${fn#oti_} returns no description"$'\n'
  else
    problems+="oti $oti: $file defines no oti_config_${fn#oti_}"$'\n'
  fi
  ! grep -q '^uninstall_' "$file" || problems+="oti $oti: can't be undone, so it defines no uninstall_ functions"$'\n'
  f_return problems
}

# Run every check, then fail with all the problems found, if any.
# Usage: main
main() {
  local variant os profile problems="" known feature k found oti
  f_call scan_features known=features
  f_call check_duplicates problems

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
  for oti in $(available_names oti); do
    f_call check_oti found=problems -- "$oti"
    problems+="$found"
  done
  for k in $DRY_RUN_FEATURES; do
    list_contains "$known" "$k" || problems+="DRY_RUN_FEATURES names unknown feature '$k'"$'\n'
  done

  if [[ -n "$problems" ]]; then
    printf '%s' "$problems" | while IFS= read -r line; do warn "$line"; done
    error "validation failed"
  fi
  info "All OSes, profiles, variants, features and one-time installs are valid."
}

main "$@"
