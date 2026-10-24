#!/usr/bin/env bash
# Fixture tests: run install.sh in a container on a home that starts out holding a fixture's before/ files, and check
# the files it leaves against the fixture's after/. Run via `make fixtures` (needs docker); `--update` rewrites after/
# from the results instead, for review with git diff. Name fixtures to run only those. Each tests/fixtures/<name>/
# holds:
#   case.sh  IMAGE, the image to run in (a directory under tests/images); ARGS, install.sh's arguments; and optionally
#            FILES, the paths under ~ to compare (it starts out as the shell startup files, so a case can add to it). ~/dotfiles/.backup, where
#            install.sh moves files it replaces, is always compared.
#   before/  files copied into the home first
#   after/   the compared files once install.sh has run, symlinks kept as symlinks (missing files are left out)
# install.sh runs twice, and the second run must leave the compared files as the first did.

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FIXTURES_DIR="$TEST_DIR/fixtures"
IMAGES_DIR="$TEST_DIR/images"
DEFAULT_FILES=".bash_profile .bashrc .profile .zprofile .zshrc"
IMAGE_PREFIX="dotfiles-fixtures-"

# Outputs: _image, _args and _files of fixture $1, read from its case.sh.
case_config() {
  local out
  out="$(
    IMAGE="" ARGS="" FILES="$DEFAULT_FILES"
    # shellcheck source=/dev/null
    source "$FIXTURES_DIR/$1/case.sh"
    printf '%s\n%s\n%s\n' "$IMAGE" "$ARGS" "$FILES"
  )"
  _image="${out%%$'\n'*}"
  out="${out#*$'\n'}"
  _args="${out%%$'\n'*}"
  _files="${out#*$'\n'}"
  [[ -n "$_image" && -d "$IMAGES_DIR/$_image" ]] || error "$1/case.sh: IMAGE must name a directory in tests/images"
  [[ -n "$_args" ]] || error "$1/case.sh: ARGS is empty"
}

# Print the name of every fixture.
all_fixtures() {
  local f names=""
  for f in "$FIXTURES_DIR"/*/case.sh; do
    f="${f%/case.sh}"
    names+="${names:+ }${f##*/}"
  done
  printf '%s' "$names"
}

# Print the entries under directory $1 (none if it is missing) as ./relative paths, sorted.
tree_entries() {
  [[ -d "$1" ]] || return 0
  (cd "$1" && find . ! -name . | LC_ALL=C sort)
}

# Return 0 if path $1 exists, counting dangling symlinks.
present() {
  [[ -e "$1" || -L "$1" ]]
}

# Compare tree $2 against the expected tree $1: the same entries, of the same type, with the same symlink targets and
# file contents. Prints each difference (paths relative to the trees, i.e. to ~), with a diff for files, and returns 1
# if there are any.
compare_trees() {
  local expected="$1" actual="$2" path name e a differ=0
  while IFS= read -r path; do
    e="$expected/$path" a="$actual/$path" name="${path#./}"
    if ! present "$e"; then
      warn "$name: not expected, but found"
    elif ! present "$a"; then
      warn "$name: expected, but missing"
    elif [[ -L "$e" || -L "$a" ]]; then
      [[ -L "$e" && -L "$a" && "$(readlink "$e")" == "$(readlink "$a")" ]] && continue
      warn "$name: expected $(describe "$e"), found $(describe "$a")"
    elif [[ -d "$e" || -d "$a" ]]; then
      [[ -d "$e" && -d "$a" ]] && continue
      warn "$name: expected $(describe "$e"), found $(describe "$a")"
    else
      cmp -s "$e" "$a" && continue
      warn "$name: contents differ (- expected, + found):"
      diff -u --label expected --label found "$e" "$a" | sed 's/^/       | /' >&2 || true
    fi
    differ=1
  done < <({ tree_entries "$expected"; tree_entries "$actual"; } | LC_ALL=C sort -u)
  return "$differ"
}

# Print what kind of entry $1 is, for messages.
describe() {
  if [[ -L "$1" ]]; then
    printf 'a symlink to %s' "$(readlink "$1")"
  elif [[ -d "$1" ]]; then
    printf 'a directory'
  else
    printf 'a file'
  fi
}

# --- In the container ---

# Copy the paths in $2 (space-separated, relative to ~) that exist, plus ~/dotfiles/.backup, into new directory $1.
collect() {
  local dest="$1" files="$2" paths=() path
  for path in $files dotfiles/.backup; do
    present "$HOME/$path" && paths+=("$path")
  done
  mkdir -p "$dest"
  [[ ${#paths[@]} -eq 0 ]] || tar -cf - -C "$HOME" "${paths[@]}" | tar -xf - -C "$dest"
}

# Run install.sh with the words of $1 as arguments, showing its output, indented.
run_install() {
  local args="$1" status=0
  info "\$ ~/dotfiles/install.sh $args"
  # ~/.local/bin is on the PATH of an installed home (env.sh), where features look for what they installed.
  # shellcheck disable=SC2086 # ARGS is a list of words
  PATH="$HOME/.local/bin:$PATH" bash "$HOME/dotfiles/install.sh" $args </dev/null 2>&1 | sed 's/^/       | /' \
    || status=$?
  [[ "$status" == 0 ]] || error "install.sh failed"
}

# Run fixture $1 in this home: copy in before/, install twice, then compare the results with after/, or with $2 =
# true, write them to fd 3 as a tar archive. Refuses to run outside a container, since it changes ~ and /.
run_inside() {
  local name="$1" update="$2" dir="$FIXTURES_DIR/$1" scratch
  [[ -f /.dockerenv || -f /run/.containerenv ]] || error "--inside changes ~ and /, so it only runs in a container"
  f_write_args case_config _image _args _files -- "$name"
  [[ "$(ls -A "$HOME")" == dotfiles ]] || error "the home must start out empty but for ~/dotfiles; check the image"
  scratch="$(mktemp -d)"
  if [[ -d "$dir/before" ]]; then
    cp -RP "$dir/before/." "$HOME/"
  fi

  run_install "$_args"
  collect "$scratch/first" "$_files"
  run_install "$_args"
  collect "$scratch/second" "$_files"
  compare_trees "$scratch/first" "$scratch/second" || error "the second install changed the files above"

  if $update; then
    tar -cf - -C "$scratch/first" . >&3
  else
    compare_trees "$dir/after" "$scratch/first" || error "the files differ from $name/after"
  fi
}

# --- On the host ---

# Write a tar archive of the checkout's files (tracked and untracked, not ignored) to stdout.
repo_archive() {
  (
    cd "$REPO_ROOT"
    git ls-files -z -co --exclude-standard | while IFS= read -r -d '' path; do
      present "$path" && printf '%s\0' "$path"
    done | tar --null -T - -cf -
  )
}

# Run fixture $1 in a fresh container of its image, from a copy of the checkout at ~/dotfiles. With $2 = true, replace
# its after/ with the results. Returns 1 if it fails.
run_fixture() {
  local name="$1" update="$2" dir="$FIXTURES_DIR/$1" archive
  f_write_args case_config _image _args _files -- "$name"
  archive="$(mktemp)"
  # The container's stdout carries the results archive, so its messages go to stderr.
  if ! repo_archive | docker run --rm -i "$IMAGE_PREFIX$_image" bash -c \
    'mkdir ~/dotfiles && tar -xf - -C ~/dotfiles && exec ~/dotfiles/tests/fixtures.sh --inside "$@" 3>&1 1>&2' \
    _ "$name" "$update" > "$archive"; then
    rm -f "$archive"
    return 1
  fi
  if $update; then
    rm -rf "$dir/after"
    mkdir "$dir/after"
    tar -xf "$archive" -C "$dir/after"
  fi
  rm -f "$archive"
}

main() {
  local update=false names="" name images="" failed=""
  if [[ "${1:-}" == --inside ]]; then
    run_inside "$2" "$3"
    return
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --update) update=true ;;
      -*) error "unknown option: $1" ;;
      *) [[ -f "$FIXTURES_DIR/$1/case.sh" ]] || error "no fixture tests/fixtures/$1"; names+="${names:+ }$1" ;;
    esac
    shift
  done
  [[ -n "$names" ]] || names="$(all_fixtures)"
  command -v docker >/dev/null || error "docker is required to run the fixtures"

  for name in $names; do
    f_write_args case_config _image _args _files -- "$name"
    list_contains "$images" "$_image" || images+=" $_image"
  done
  for name in $images; do
    info "building image $IMAGE_PREFIX$name from tests/images/$name"
    docker build --quiet -t "$IMAGE_PREFIX$name" "$IMAGES_DIR/$name" >/dev/null
  done

  for name in $names; do
    info "fixture $name"
    run_fixture "$name" "$update" || failed+=" $name"
  done
  [[ -z "$failed" ]] || error "failed fixtures:$failed"
  if $update; then
    info "updated after/ of: $names (review with git diff)"
  else
    info "all fixtures passed"
  fi
}

main "$@"
