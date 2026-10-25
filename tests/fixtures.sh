#!/usr/bin/env bash
# Fixture tests: run install.sh in a container that starts out holding a fixture's before/ files, and check what it
# leaves against the fixture's after/. Run via `make fixtures` (needs docker); `--update` rewrites after/ from the
# results instead, for review with git diff. Name fixtures to run only those. Each tests/fixtures/<name>/ holds:
#   case.sh   IMAGE, the image to run in (a directory under tests/images), and ARGS, install.sh's arguments.
#             Optionally: FILES, the paths under ~ whose regular files after/ holds in full (it starts out as the shell
#             startup files, so a case can add to it; ~/dotfiles/.backup, where install.sh moves files it replaces, is
#             always included); ROOT_FILES, absolute paths outside ~ to compare; AFTER_INSTALL, a command to run after
#             the first install (e.g. an OS update), as the user; and RUN_WITH, a command that runs install.sh (e.g.
#             dbus-run-session -- for a session bus).
#   before/   home/ (copied into ~) and root/ (copied into / with sudo), like the repo's own home/ and root/
#   after/    after the first install and AFTER_INSTALL: manifest, one line for every entry under ~ (but ~/dotfiles
#             other than its .backup) and ROOT_FILES (see manifest_lines), marked new, changed, kept or removed against
#             a manifest taken just before the install (see mark_manifest); and home/ and root/, every symlink the
#             manifest lists, to show the layout, and the regular files under FILES and ROOT_FILES, for readable diffs
# install.sh then runs again, and must leave all of it as it was: an idempotent install, and one that AFTER_INSTALL
# didn't undo any of. Every container shares DOWNLOADS_DIR as its DOTFILES_DOWNLOAD_CACHE, so pinned downloads are
# fetched once (see Download Cache in README.md).

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FIXTURES_DIR="$TEST_DIR/fixtures"
IMAGES_DIR="$TEST_DIR/images"
DEFAULT_FILES=".bash_profile .bashrc .profile .zprofile .zshrc"
IMAGE_PREFIX="dotfiles-fixtures-"
DOWNLOADS_DIR="$TOOLS_CACHE/fixture-downloads"
CONTAINER_DOWNLOADS_DIR=/var/cache/dotfiles-downloads
# Files under ~ whose contents the manifest leaves out, since the claude feature builds them from the tools repos'
# latest commits.
# shellcheck disable=SC2088 # manifest paths, not ones to expand
UNPINNED_FILES="~/.claude/settings.json ~/git/.claude/CLAUDE.md"

# Outputs: _image, _args, _files, _root_files, _after_install and _run_with of fixture $1, read from its case.sh.
case_config() {
  local out
  out="$(
    IMAGE="" ARGS="" FILES="$DEFAULT_FILES" ROOT_FILES="" AFTER_INSTALL="" RUN_WITH=""
    # shellcheck source=/dev/null
    source "$FIXTURES_DIR/$1/case.sh"
    # One line each, since the lists may span lines in case.sh, and a last line so $(...) keeps the empty ones.
    printf '%s\n' "$IMAGE" "${ARGS//$'\n'/ }" "${FILES//$'\n'/ }" "${ROOT_FILES//$'\n'/ }" "${AFTER_INSTALL//$'\n'/ }" \
      "$RUN_WITH" .
  )"
  {
    IFS= read -r _image
    IFS= read -r _args
    IFS= read -r _files
    IFS= read -r _root_files
    IFS= read -r _after_install
    IFS= read -r _run_with
  } <<< "$out"
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

# Print the entries under directory $1 (none if it is missing) but directories as ./relative paths, sorted. after/
# leaves out directories, which git can't hold empty; the manifest lists them.
tree_entries() {
  [[ -d "$1" ]] || return 0
  (cd "$1" && find . ! -type d | LC_ALL=C sort)
}

# Return 0 if path $1 exists, counting dangling symlinks.
present() {
  [[ -e "$1" || -L "$1" ]]
}

# Compare tree $2 against the expected tree $1: the same entries, of the same type, with the same symlink targets and
# file contents. Prints each difference (paths relative to the trees, e.g. home/.bashrc), with a diff for files (all of
# a new one, so a missing after/ file shows in full), and returns 1 if there are any.
compare_trees() {
  local expected="$1" actual="$2" path name e a differ=0
  while IFS= read -r path; do
    e="$expected/$path" a="$actual/$path" name="${path#./}"
    if ! present "$e"; then
      warn "$name: not expected, but found"
      if [[ -f "$a" && ! -L "$a" ]]; then
        diff -u --label expected --label found /dev/null "$a" | sed 's/^/       | /' >&2 || true
      fi
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

# Print path $1 as the manifest shows it: starting with ~ under ~.
shown_path() {
  case "$1" in
    "$HOME" | "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# Print a manifest line for each entry under the paths $2... (themselves included), which find walks under command $1
# (sudo, or empty): "<path> <type> <mode> <owner>", where type is find's (f, d, l, ...) and owner is "user" for the
# user's own entries, then "-> <target>" for a symlink and the start of its SHA-256 for a regular file (* for
# UNPINNED_FILES). Paths and link targets under ~ start with ~. ~/dotfiles is left out (name its .backup to include
# that). A git clone, whose contents follow upstream, is one "git" line with its remote URL (without credentials), then
# lines for its untracked and changed files. Returns 1 if a symlink outside ~/dotfiles/.backup dangles.
manifest_lines() {
  local sudo="$1" me type mode owner path target line status=0
  shift
  me="$(id -un):$(id -gn)"
  while IFS=$'\t' read -r -d '' type mode owner path target; do
    [[ "$owner" == "$me" ]] && owner=user
    line="$(shown_path "$path") $type $mode $owner"
    case "$type" in
      l)
        line+=" -> $(shown_path "$target")"
        if [[ "$path" != "$HOME/dotfiles/.backup/"* ]] && ! $sudo test -e "$path"; then
          warn "$(shown_path "$path"): dangling symlink to $target"
          status=1
        fi
        ;;
      f)
        if list_contains "$UNPINNED_FILES" "$(shown_path "$path")"; then
          line+=" *"
        else
          line+=" $($sudo sha256sum "$path" | cut -c1-16)"
        fi
        ;;
      git)
        # Without any user:password@ (tpm clones from https://git::@github.com/...).
        line+=" $($sudo git -C "$path" remote get-url origin 2>/dev/null | sed 's|^\([a-z+]*://\)[^/@]*@|\1|' \
          || printf -)"
        ;;
    esac
    printf '%s\n' "$line"
    if [[ "$type" == git ]]; then
      clone_changes "$sudo" "$path" || status=1
    fi
  done < <($sudo find "$@" -path "$HOME/dotfiles" -prune \
    -o -type d -exec test -e '{}/.git' ';' -printf 'git\t%m\t%u:%g\t%p\t\0' -prune \
    -o -printf '%y\t%m\t%u:%g\t%p\t%l\0')
  return "$status"
}

# Print manifest lines (see manifest_lines, under command $1) for the untracked and changed files of the git clone $2,
# and "<path> deleted" for each deleted one.
clone_changes() {
  local sudo="$1" clone="$2" entry path status=0
  while IFS= read -r -d '' entry; do
    path="$clone/${entry:3}"
    # A rename is followed by its old path.
    [[ "$entry" == R* ]] && IFS= read -r -d '' _
    if present "$path"; then
      manifest_lines "$sudo" "$path" || status=1
    else
      printf '%s deleted\n' "$(shown_path "$path")"
    fi
  done < <($sudo git -C "$clone" status --porcelain -z --untracked-files=all)
  return "$status"
}

# Copy the regular files and symlinks under the paths $4... (relative to directory $2) into directory $3, keeping their
# paths, read under command $1 (sudo, or empty). Leaves $3 out if there are none, since git can't hold it empty. A path
# inside a symlinked directory is an error: tar would copy the link target's files as if they were there.
copy_files() {
  local sudo="$1" from="${2%/}" to="$3" path parent list
  shift 3
  list="$(mktemp)"
  for path in "$@"; do
    present "$from/$path" || continue
    parent="$(dirname "$from/$path")"
    [[ "$(cd "$parent" && pwd -P)" == "$parent" ]] \
      || error "$(shown_path "$from/$path") is inside a symlinked directory; name the symlink instead"
    (cd "$from/" && $sudo find "$path" \( -type f -o -type l \) -print0) >> "$list"
  done
  if [[ -s "$list" ]]; then
    mkdir -p "$to"
    LC_ALL=C sort -zu "$list" | $sudo tar -C "$from/" --null -T - -cf - | tar -xf - --no-same-owner -C "$to"
  fi
  rm -f "$list"
}

# Write the sorted manifest lines (see manifest_lines) of ~, with ~/dotfiles/.backup, and of the absolute paths in $2 to
# file $1. Returns 1 if a symlink dangles.
write_manifest() {
  local file="$1" root_files="$2" path homes=("$HOME") roots=() status=0
  for path in $root_files; do
    [[ "$path" == /* ]] || error "ROOT_FILES must be absolute paths, not $path"
    present "$path" && roots+=("$path")
  done
  present "$HOME/dotfiles/.backup" && homes+=("$HOME/dotfiles/.backup")
  {
    manifest_lines "" "${homes[@]}" || status=1
    if [[ ${#roots[@]} -gt 0 ]]; then
      manifest_lines sudo "${roots[@]}" || status=1
    fi
  } > "$file.unsorted"
  LC_ALL=C sort "$file.unsorted" > "$file"
  rm "$file.unsorted"
  return "$status"
}

# Print the lines of manifest $2, each marked against manifest $1, taken before the install: "new" if $1 has no line
# for its path, "kept" if $1 has the same line, or "changed" with "(was ...)" and the rest of $1's line; then "removed"
# and $1's line for each path only $1 has. Sorted by path.
mark_manifest() {
  awk '
    NR == FNR { before[$1] = substr($0, length($1) + 2); next }
    {
      rest = substr($0, length($1) + 2)
      if (!($1 in before)) { printf "%-7s %s\n", "new", $0 }
      else if (before[$1] == rest) { printf "%-7s %s\n", "kept", $0 }
      else { printf "%-7s %s (was %s)\n", "changed", $0, before[$1] }
      after[$1] = 1
    }
    END { for (path in before) if (!(path in after)) printf "%-7s %s %s\n", "removed", path, before[path] }
  ' "$1" "$2" | LC_ALL=C sort -s -b -k2,2
}

# Write the manifest of ~ and of the absolute paths in $3, marked against manifest $4 (see mark_manifest), to
# $1/manifest, and copy the symlinks it lists and the regular files and symlinks under the paths in $2 (relative to ~)
# and ~/dotfiles/.backup into $1/home, and those outside ~ into $1/root (read with sudo, since some may be root's
# alone).
collect() {
  local dest="$1" files="$2" root_files="$3" before="$4" links
  mkdir -p "$dest"
  write_manifest "$dest/manifest.unmarked" "$root_files" || error "the symlinks above dangle"
  mark_manifest "$before" "$dest/manifest.unmarked" > "$dest/manifest"
  # Each symlink's path, relative to ~ or /.
  links="$(awk '$2 == "l" { print $1 }' "$dest/manifest.unmarked")"
  rm "$dest/manifest.unmarked"

  copy_files "" "$HOME" "$dest/home" $files dotfiles/.backup $(printf '%s\n' "$links" | sed -n 's|^~/||p')
  copy_files sudo / "$dest/root" $(printf '%s\n' $root_files "$links" | sed -n 's|^/||p')
}

# Run install.sh with the words of $1 as arguments, under the words of command $2 if any, showing its output, indented.
run_install() {
  local args="$1" run_with="$2" status=0
  info "\$ ${run_with:+$run_with }~/dotfiles/install.sh $args"
  # ~/.local/bin is on the PATH of an installed home (env.sh), where features look for what they installed.
  PATH="$HOME/.local/bin:$PATH" $run_with bash "$HOME/dotfiles/install.sh" $args </dev/null 2>&1 | sed 's/^/       | /' \
    || status=$?
  [[ "$status" == 0 ]] || error "install.sh failed"
}

# Run fixture $1 here: copy in before/, take a manifest, install, run AFTER_INSTALL, install again, then compare the
# results of the first install with after/, or with $2 = true, write them to fd 3 as a tar archive. Refuses to run
# outside a container, since it changes ~ and /.
run_inside() {
  local name="$1" update="$2" dir="$FIXTURES_DIR/$1" scratch
  [[ -f /.dockerenv || -f /run/.containerenv ]] || error "--inside changes ~ and /, so it only runs in a container"
  f_write_args case_config _image _args _files _root_files _after_install _run_with -- "$name"
  [[ "$(ls -A "$HOME")" == dotfiles ]] || error "the home must start out empty but for ~/dotfiles; check the image"
  scratch="$(mktemp -d)"
  if [[ -d "$dir/before/home" ]]; then
    cp -RP "$dir/before/home/." "$HOME/"
  fi
  if [[ -d "$dir/before/root" ]]; then
    sudo cp -RP --no-preserve=ownership "$dir/before/root/." /
  fi
  # What the install starts from, to mark what it did. A symlink that already dangles is the fixture's business.
  write_manifest "$scratch/before" "$_root_files" || true

  run_install "$_args" "$_run_with"
  if [[ -n "$_after_install" ]]; then
    info "\$ $_after_install"
    bash -c "$_after_install" 2>&1 | sed 's/^/       | /' || error "AFTER_INSTALL failed"
  fi
  collect "$scratch/first" "$_files" "$_root_files" "$scratch/before"
  run_install "$_args" "$_run_with"
  collect "$scratch/second" "$_files" "$_root_files" "$scratch/before"
  compare_trees "$scratch/first" "$scratch/second" \
    || error "the second install changed the files above${_after_install:+ (if the first install was idempotent, '$_after_install' undid part of it)}"

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
  f_write_args case_config _image _args _files _root_files _after_install _run_with -- "$name"
  archive="$(mktemp)"
  # The container's stdout carries the results archive, so its messages go to stderr.
  if ! repo_archive | docker run --rm -i -v "$DOWNLOADS_DIR:$CONTAINER_DOWNLOADS_DIR" \
    -e DOTFILES_DOWNLOAD_CACHE="$CONTAINER_DOWNLOADS_DIR" "$IMAGE_PREFIX$_image" bash -c \
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
    f_write_args case_config _image _args _files _root_files _after_install _run_with -- "$name"
    list_contains "$images" "$_image" || images+=" $_image"
  done
  # Writable by the containers' users, whose ids needn't match this one's.
  mkdir -p "$DOWNLOADS_DIR"
  chmod a+rwx "$DOWNLOADS_DIR"
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
