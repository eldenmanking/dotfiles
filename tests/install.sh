#!/usr/bin/env bash
# Exercise install.sh in scratch home directories: usage, --dry-run for every OS and profile, real rootless installs and
# their idempotency, and the resulting shell startup files. Run via `make test`. INSTALL_BASH picks the bash that runs
# install.sh (CI sets /bin/bash on macOS to test bash 3.2).

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INSTALL_BASH="${INSTALL_BASH:-bash}"
SCRATCH="$(mktemp -d)"
LOG="$SCRATCH/install.log"
# Features that check for a live host even under --dry-run: webterm needs a systemd user session.
DRY_RUN_SKIP=" webterm "

FAILURES=0
trap 'rm -rf "$SCRATCH"' EXIT

# Report a passed check.
# Usage: pass <description>...
pass() {
  printf '  \033[32mok\033[0m   %s\n' "$*"
}

# Report a failed check and keep going, so one run reports every failure.
# Usage: fail <description>...
fail() {
  printf '  \033[31mFAIL\033[0m %s\n' "$*" >&2
  FAILURES=$((FAILURES + 1))
}

# Report check $1 as passed if the remaining args, run as a command, succeed.
# Usage: check <description> <command> [<arg>...]
check() {
  local description="$1"
  shift
  if "$@"; then pass "$description"; else fail "$description"; fi
}

# Make a new scratch home holding a dotfiles symlink to this checkout, as install.sh requires.
# Usage: f_call new_home home
# Returns: home
new_home() {
  local home
  home="$(mktemp -d "$SCRATCH/home.XXXXXX")"
  ln -s "$REPO_ROOT" "$home/dotfiles"
  f_return home
}

# Run install.sh with home $1 and the remaining args, in a clean environment with no terminal. Its output goes to
# LOG. Returns install.sh's status. XDG_RUNTIME_DIR is set as in a login session, since without one dconf (read by
# --capture --dconf) keeps its runtime state in ~/.cache instead.
# Usage: run_install <home> [<arg>...]
run_install() {
  local home="$1"
  shift
  mkdir -p "$SCRATCH/runtime"
  env -i HOME="$home" PATH="$PATH" TERM=dumb XDG_RUNTIME_DIR="$SCRATCH/runtime" "$INSTALL_BASH" "$home/dotfiles/install.sh" "$@" </dev/null >"$LOG" 2>&1
}

# Run install.sh like run_install and report it as a check that it succeeds, showing its output if not.
# Usage: install_ok <home> [<arg>...]
install_ok() {
  local home="$1"
  shift
  if run_install "$home" "$@"; then
    pass "install.sh${*:+ $*}"
  else
    fail "install.sh${*:+ $*}"
    sed 's/^/       | /' "$LOG" >&2
    return 1
  fi
}

# Run install.sh like run_install and report it as a check that it refuses.
# Usage: install_refused <home> [<arg>...]
install_refused() {
  local home="$1"
  shift
  if run_install "$home" "$@"; then fail "install.sh${*:+ $*} (should be refused)"; else pass "install.sh${*:+ $*} (refused)"; fi
}

# Print the output of running the remaining args as a command, with install/ loaded the way install.sh loads it.
# Usage: with_install_loaded <command> [<arg>...]
with_install_loaded() {
  (
    set +u
    INSTALL_DIR="$REPO_ROOT/install"
    load_install_tree
    "$@"
  )
}

# Print the features, link paths and DRY_RUN_FEATURES of OS $1 with profile $2, one per line.
# Usage: print_setup_info <os> <profile>
print_setup_info() {
  local features link_paths
  f_call os_profile_config features link_paths -- "$1" "$2"
  printf '%s\n%s\n%s\n' "$features" "$link_paths" "$DRY_RUN_FEATURES"
}

# Read the features and link paths of setup <os>/<profile> from its definition the same way install.sh does.
# Usage: f_call setup_info features link_paths dry_run_features -- <os>/<profile>
# Returns: features link_paths dry_run_features
#   dry_run_features: the features that honor --dry-run (install.sh only announces the others)
setup_info() {
  local out
  out="$(with_install_loaded print_setup_info "${1%/*}" "${1#*/}")"
  f_return features="${out%%$'\n'*}"
  out="${out#*$'\n'}"
  f_return link_paths="${out%%$'\n'*}" dry_run_features="${out#*$'\n'}"
}

# Print one line per entry under home $1 (outside dotfiles): its type, path, and symlink target or checksum.
# Usage: snapshot <home>
snapshot() {
  local home="$1" path
  (cd "$home" && find . -path ./dotfiles -prune -o -print | LC_ALL=C sort) | while IFS= read -r path; do
    if [[ -L "$home/$path" ]]; then
      printf 'L %s -> %s\n' "$path" "$(readlink "$home/$path")"
    elif [[ -d "$home/$path" ]]; then
      printf 'D %s\n' "$path"
    else
      printf 'F %s %s\n' "$path" "$(cksum < "$home/$path")"
    fi
  done
}

# Report check $1: snapshot $3 must equal snapshot $2, or the lines that differ are shown.
# Usage: check_unchanged <description> <before> <after>
check_unchanged() {
  local description="$1" before="$2" after="$3"
  if [[ "$before" == "$after" ]]; then
    pass "$description"
  else
    fail "$description; changed (- before, + after):"
    diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | grep '^[<>]' | sed 's/^</       -/; s/^>/       +/' >&2 || true
  fi
}

# Print the checkout's git status, ignored files included.
# Usage: repo_status
repo_status() {
  # --ignored too, since backups would land in the ignored dotfiles/.backup.
  git -C "$REPO_ROOT" status --porcelain --untracked-files=all --ignored
}

# Print every OS and profile that go together, as os/profile.
# Usage: print_all_setups
print_all_setups() {
  local os profile setups=""
  for os in $(available_names os); do
    for profile in $(os_profiles "$os"); do
      setups+="${setups:+ }$os/$profile"
    done
  done
  printf '%s' "$setups"
}

# install.sh with no arguments runs, --help lists the options of each variant in <variants>, and an
# unknown variant or option is refused.
# Usage: test_usage <variants>
test_usage() {
  local variants="$1" variant
  info "usage"
  local home
  f_call new_home home
  install_ok "$home" || true
  for variant in $variants; do
    install_ok "$home" --variant "$variant" --help && check "  ...lists --link" grep -q -- '--link' "$LOG"
  done
  install_refused "$home" --variant nope
  install_refused "$home" --variant coder --nope
}

# --variant names an OS and profile, which --os and --profile override; only the OS, profile and machine combinations
# install/os defines run.
# Usage: test_dimensions
test_dimensions() {
  info "dimensions: --os, --profile and their combinations"
  local home
  f_call new_home home
  install_ok "$home" --variant steamos --profile minimal --help \
    && check "  ...--profile overrides the variant's" grep -q "Options for OS 'steamos' with profile 'minimal'" "$LOG"
  install_ok "$home" --os portable --profile workspace --help \
    && check "  ...--os and --profile stand in for a variant" grep -q -- "--gng" "$LOG"
  install_refused "$home" --os arch --profile workspace
  install_refused "$home" --os portable --profile desktop
  install_refused "$home" --variant coder --machine framework16
  install_refused "$home" --os arch --gitconfig
  install_refused "$home" --profile minimal --gitconfig
  install_refused "$home" --os nope --profile minimal
  write_install_conf "$home" "DOTFILES_VARIANT=steamos" "DOTFILES_PROFILE=minimal"
  install_ok "$home" && check "  ...DOTFILES_PROFILE overrides DOTFILES_VARIANT's" \
    grep -q "Options for OS 'steamos' with profile 'minimal'" "$LOG"
}

# Command-line parsing: --help in every form, value options, option names, and the order --reinstall runs in.
# Usage: test_cli
test_cli() {
  local home
  info "cli: option parsing and --reinstall order"
  f_call new_home home
  install_ok "$home" --oti arch-chroot --help && check "  ...--oti --help prints usage" grep -q '^Usage:' "$LOG"
  install_ok "$home" --os arch --help && check "  ...--os alone with --help prints usage" grep -q '^Usage:' "$LOG"
  install_ok "$home" --profile minimal --help && check "  ...--profile alone with --help prints usage" grep -q '^Usage:' "$LOG"
  install_ok "$home" -h && check "  ...-h prints usage" grep -q '^Usage:' "$LOG"
  install_ok "$home" --os=portable --profile=minimal --help \
    && check "  ...--opt=value works" grep -q "Options for OS 'portable' with profile 'minimal'" "$LOG"
  install_refused "$home" --os --all
  check "  ...--os --all says the value is missing" grep -q "requires a value, but got the option --all" "$LOG"
  install_refused "$home" --os= --profile minimal
  check "  ...an empty value is rejected" grep -q "requires a non-empty value" "$LOG"
  install_refused "$home" --variant coder --variant arch
  check "  ...a repeated option is rejected" grep -q "given twice" "$LOG"
  install_refused "$home" --variant coder '--*'
  check "  ...odd option names are rejected, not globbed" grep -q "Unexpected argument: --\*" "$LOG"
  write_install_conf "$home" "DOTFILES_VARIANT=nope"
  install_ok "$home" --os portable --profile minimal --help \
    && check "  ...a bad default variant is ignored when --os and --profile are given" \
      grep -q "Options for OS 'portable'" "$LOG"
  install_refused "$home" --help
  check "  ...a bad default variant is named as the default" grep -q "Unknown variant 'nope' (from DOTFILES_VARIANT" "$LOG"
  rm -f "$home/.config/dotfiles/install.conf"
  install_ok "$home" --variant arch --dry-run --reinstall --logind --link \
    && check "  ...--reinstall uninstalls everything, then installs" sh -c '
      last_uninstall="$(grep -n "Uninstalling feature" "$1" | tail -1 | cut -d: -f1)"
      first_install="$(grep -n "ln -snfv" "$1" | head -1 | cut -d: -f1)"
      [ -n "$last_uninstall" ] && [ -n "$first_install" ] && [ "$last_uninstall" -lt "$first_install" ]' sh "$LOG"
}

# Write install.conf in home $1 with the remaining args as its lines.
# Usage: write_install_conf <home> [<line>...]
write_install_conf() {
  local home="$1"
  shift
  mkdir -p "$home/.config/dotfiles"
  printf '%s\n' "$@" > "$home/.config/dotfiles/install.conf"
}

# DOTFILES_VARIANT and DOTFILES_FEATURES, from the environment or ~/.config/dotfiles/install.conf, stand in for
# --variant and the feature options when the command line leaves them out.
# Usage: test_defaults
test_defaults() {
  local out
  info "defaults: DOTFILES_VARIANT and DOTFILES_FEATURES from install.conf or the environment"
  local home
  f_call new_home home
  write_install_conf "$home" "DOTFILES_VARIANT=coder"
  install_ok "$home" && check "  ...lists the default variant's options" \
    grep -q "Options for OS 'portable' with profile 'workspace'" "$LOG"

  write_install_conf "$home" "DOTFILES_VARIANT=coder" "DOTFILES_FEATURES=all"
  install_ok "$home" --dry-run && check "  ...runs --all" grep -q "would run feature: binaries" "$LOG"
  install_ok "$home" --variant arch && check "  ...ignores the features for another variant" \
    grep -q "Options for OS 'arch' with profile 'desktop'" "$LOG"
  install_ok "$home" --profile minimal && check "  ...and for another profile" \
    grep -q "Options for OS 'portable' with profile 'minimal'" "$LOG"
  install_ok "$home" --dry-run --uninstall && check "  ...ignores the features under --uninstall" \
    grep -q "Options for OS 'portable' with profile 'workspace'" "$LOG"
  install_ok "$home" --dry-run --gitconfig && check "  ...lets options override the features" \
    sh -c '! grep -q "would run feature: binaries" "$1"' sh "$LOG"
  if out="$(env -i HOME="$home" PATH="$PATH" TERM=dumb DOTFILES_VARIANT=portable DOTFILES_FEATURES=gitconfig \
    "$INSTALL_BASH" "$home/dotfiles/install.sh" --dry-run </dev/null 2>&1)" \
    && grep -q "os: portable, profile: minimal" <<< "$out" && grep -q "git config --global" <<< "$out"; then
    pass "the environment overrides install.conf"
  else
    fail "the environment overrides install.conf: $out"
  fi

  write_install_conf "$home" "DOTFILES_VARIANT=coder" "DOTFILES_FEATURES=gitconfig"
  install_ok "$home" && check "  ...installs with no arguments" grep -q "excludesFile" "$home/.gitconfig"

  write_install_conf "$home" 'DOTFILES_VARIANT="$UNSET_VARIABLE"'
  install_refused "$home" --dry-run
  write_install_conf "$home" "DOTFILES_VARIANT=nope"
  install_refused "$home"
}

# Run install.sh at $1 with home $2 and expect it to refuse, with a message matching $3. $4 describes the case.
# Usage: expect_refused <script> <home> <pattern> <description>
expect_refused() {
  local script="$1" home="$2" pattern="$3" description="$4" out
  if out="$(env -i HOME="$home" PATH="$PATH" "$INSTALL_BASH" "$script" --variant coder --gitconfig </dev/null 2>&1)"; then
    fail "install.sh ran from $script with HOME=$home"
  elif ! grep -q -- "$pattern" <<< "$out"; then
    fail "install.sh from $script: expected '$pattern', got: $out"
  else
    pass "refused $description"
  fi
}

# Commit to repo $1 with message $2, as a test user.
# Usage: test_commit <repo> <message>
test_commit() {
  git -C "$1" -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false \
    commit --quiet --allow-empty -m "$2"
}

# Clone this checkout to $1 on branch main, as a GitHub repo would be (CI checks out a detached HEAD), and commit the
# working tree's install.sh, install/, bootstrap/ and scripts/ there, so tests that clone it test them rather than the
# last commit.
# Usage: clone_working_tree <src>
clone_working_tree() {
  local src="$1"
  git -c advice.detachedHead=false clone --quiet "$REPO_ROOT" "$src"
  git -C "$src" checkout --quiet -B main
  cp -R "$REPO_ROOT/install.sh" "$REPO_ROOT/install" "$REPO_ROOT/bootstrap" "$REPO_ROOT/scripts" "$src/"
  git -C "$src" add -A
  test_commit "$src" "working tree"
}

# Run from a git checkout elsewhere with no ~/dotfiles, install.sh clones that checkout's commit to ~/dotfiles, keeps
# its origin, and installs from the clone.
# Usage: test_clone_checkout
test_clone_checkout() {
  local home src
  info "checkout location: install.sh clones a checkout elsewhere to ~/dotfiles"
  home="$(mktemp -d "$SCRATCH/home.XXXXXX")"
  src="$SCRATCH/coder-checkout"
  clone_working_tree "$src"
  git -C "$src" remote set-url origin https://example.com/dotfiles.git
  printf 'local change\n' > "$src/uncommitted"
  if env -i HOME="$home" PATH="$PATH" TERM=dumb "$INSTALL_BASH" "$src/install.sh" --variant coder --gitconfig \
    </dev/null >"$LOG" 2>&1; then
    pass "install.sh from $src"
  else
    fail "install.sh from $src"
    sed 's/^/       | /' "$LOG" >&2
    return
  fi
  check "  ...cloned the same commit" \
    test "$(git -C "$home/dotfiles" rev-parse HEAD)" = "$(git -C "$src" rev-parse HEAD)"
  check "  ...kept the origin" test "$(git -C "$home/dotfiles" remote get-url origin)" = https://example.com/dotfiles.git
  check "  ...warned about uncommitted changes" grep -q "uncommitted changes" "$LOG"
  check "  ...installed from the clone" grep -q "$home/dotfiles/home/.config/git/ignore" "$home/.gitconfig"
}

# Run install.sh like run_install, but from script $2 rather than home $1's checkout, with no terminal. Its output goes
# to LOG.
# Usage: run_script <home> <script> [<arg>...]
run_script() {
  local home="$1" script="$2"
  shift 2
  env -i HOME="$home" PATH="$PATH" TERM=dumb "$INSTALL_BASH" "$script" "$@" </dev/null >"$LOG" 2>&1
}

# Report check $1 as passed if run_script with the remaining args succeeds, showing its output if not.
# Usage: script_ok <description> [<arg>...]
script_ok() {
  local description="$1"
  shift
  if run_script "$@"; then
    pass "$description"
  else
    fail "$description"
    sed 's/^/       | /' "$LOG" >&2
    return 1
  fi
}

# The install branch's bootstrap (bootstrap/install.sh, filled in by scripts/bootstrap.sh) clones its pinned commit to
# ~/dotfiles, on the default branch so it can be pulled, and runs it. main's install.sh doesn't run on its own.
# Usage: test_bootstrap
test_bootstrap() {
  local src pinned script home
  info "bootstrap: the install branch's install.sh clones its pinned commit to ~/dotfiles and runs it"
  src="$SCRATCH/pinned-repo"
  clone_working_tree "$src"
  pinned="$(git -C "$src" rev-parse HEAD)"
  test_commit "$src" "after the pin"
  mkdir "$SCRATCH/bootstrap"
  script="$SCRATCH/bootstrap/install.sh"
  "$src/scripts/bootstrap.sh" --repo "$src" --commit "$pinned" > "$script"

  home="$(mktemp -d "$SCRATCH/home.XXXXXX")"
  if script_ok "bootstrap" "$home" "$script" --variant coder --gitconfig; then
    check "  ...checked out the pinned commit" test "$(git -C "$home/dotfiles" rev-parse HEAD)" = "$pinned"
    check "  ...on the default branch" test -n "$(git -C "$home/dotfiles" symbolic-ref -q HEAD)"
    check "  ...ran its install.sh" grep -q "$home/dotfiles/home/.config/git/ignore" "$home/.gitconfig"
  fi

  # A repo whose HEAD is detached gets the pinned commit detached.
  git -C "$src" checkout --quiet --detach
  home="$(mktemp -d "$SCRATCH/home.XXXXXX")"
  if script_ok "bootstrap from a repo with a detached HEAD" "$home" "$script" --variant coder --gitconfig; then
    check "  ...checked out the pinned commit" test "$(git -C "$home/dotfiles" rev-parse HEAD)" = "$pinned"
  fi
  git -C "$src" checkout --quiet main

  f_call new_home home
  if script_ok "bootstrap with ~/dotfiles already there" "$home" "$script" --variant coder --gitconfig; then
    check "  ...ran it as it is" grep -q "already exists" "$LOG"
  fi

  home="$(mktemp -d "$SCRATCH/home.XXXXXX")"
  if run_script "$home" "$REPO_ROOT/bootstrap/install.sh" --variant coder; then
    fail "the template, bootstrap/install.sh (should be refused)"
  else
    pass "the template, bootstrap/install.sh (refused)"
  fi
  mkdir "$SCRATCH/main-install"
  cp "$REPO_ROOT/install.sh" "$SCRATCH/main-install/"
  if run_script "$home" "$SCRATCH/main-install/install.sh" --variant coder; then
    fail "main's install.sh on its own (should be refused)"
  elif grep -q "install branch" "$LOG" && [[ ! -e "$home/dotfiles" ]]; then
    pass "main's install.sh on its own (refused, pointing at the install branch)"
  else
    fail "main's install.sh on its own: expected a refusal naming the install branch, got: $(cat "$LOG")"
  fi
}

# Print the commit that the install.sh on branch $2 of repo $1 pins.
# Usage: branch_pin <repo> <branch>
branch_pin() {
  git -C "$1" show "$2:install.sh" | sed -n 's/^PINNED_COMMIT="\(.*\)"$/\1/p'
}

# scripts/bootstrap.sh --publish, as the install branch workflow runs it: it commits the bootstrap as the install
# branch's only file, moves the branch forward one commit per pin, and never back to an older commit.
# Usage: test_publish
test_publish() {
  local origin work first second
  info "bootstrap: scripts/bootstrap.sh --publish moves the install branch forward"
  origin="$SCRATCH/publish-origin.git"
  work="$SCRATCH/publish-work"
  # A fresh repo rather than a clone, which would be shallow in CI and so couldn't be pushed to a new repo.
  git init --quiet "$work"
  git -C "$work" checkout --quiet -b main
  cp -R "$REPO_ROOT/install" "$REPO_ROOT/bootstrap" "$REPO_ROOT/scripts" "$work/"
  git -C "$work" add -A
  test_commit "$work" "first"
  test_commit "$work" "second"
  git init --quiet --bare "$origin"
  git -C "$work" remote add origin "$origin"
  git -C "$work" push --quiet origin main
  first="$(git -C "$work" rev-parse HEAD^1)"
  second="$(git -C "$work" rev-parse HEAD)"
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test
  export GIT_COMMITTER_EMAIL=test@example.com

  "$work/scripts/bootstrap.sh" --publish install --commit "$first" >/dev/null
  check "creates the branch, pinning the commit" test "$(branch_pin "$origin" install)" = "$first"
  check "  ...with install.sh as its only file, executable" \
    test "$(git -C "$origin" ls-tree install)" = "100755 blob $(git -C "$origin" rev-parse install:install.sh)	install.sh"
  check "  ...cloning origin" grep -qxF "PINNED_REPO=\"$origin\"" <(git -C "$origin" show install:install.sh)
  "$work/scripts/bootstrap.sh" --publish install --commit "$first" >/dev/null
  check "publishing the same commit again changes nothing" test "$(git -C "$origin" rev-list --count install)" = 1
  "$work/scripts/bootstrap.sh" --publish install --commit "$second" >/dev/null
  check "a later commit moves the branch forward one commit" \
    test "$(branch_pin "$origin" install) $(git -C "$origin" rev-list --count install)" = "$second 2"
  "$work/scripts/bootstrap.sh" --publish install --commit "$first" >/dev/null
  check "an earlier commit doesn't move it back" test "$(branch_pin "$origin" install)" = "$second"
  unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
}

# install.sh must run from ~/dotfiles (or a link to it), and the checkout must be named dotfiles.
# Usage: test_checkout_location
test_checkout_location() {
  local home other
  info "checkout location: install.sh refuses to run from anywhere but a checkout named dotfiles at ~/dotfiles"
  home="$(mktemp -d "$SCRATCH/home.XXXXXX")"
  # A copy that isn't a git checkout, so it can't be cloned to ~/dotfiles.
  other="$SCRATCH/not-dotfiles"
  mkdir "$other"
  cp -R "$REPO_ROOT/install.sh" "$REPO_ROOT/install" "$other/"
  expect_refused "$other/install.sh" "$home" "must be checked out at $home/dotfiles" \
    "with no ~/dotfiles, from a copy that isn't a git checkout"
  mkdir "$home/dotfiles"
  expect_refused "$REPO_ROOT/install.sh" "$home" "is not $home/dotfiles" "from a checkout other than ~/dotfiles"
  rmdir "$home/dotfiles"
  # The copy, linked as ~/dotfiles.
  ln -s "$other" "$home/dotfiles"
  expect_refused "$home/dotfiles/install.sh" "$home" "must be a directory named dotfiles" \
    "with ~/dotfiles linked to a checkout named not-dotfiles"
}

# --dry-run must succeed and leave the home untouched, for install, reinstall, uninstall and capture.
# Usage: test_dry_run <setup>
test_dry_run() {
  local setup="$1" flags=() feature mode before skipped="" announced="" features honor_dry_run
  f_call setup_info features honor_dry_run=dry_run_features -- "$setup"
  for feature in $features; do
    if list_contains "$DRY_RUN_SKIP" "$feature"; then
      skipped+=" $feature"
      continue
    fi
    flags+=("--$feature")
    list_contains "$honor_dry_run" "$feature" || announced+=" $feature"
  done
  info "$setup: dry run of every feature${skipped:+ except$skipped (needs a live systemd user session)}"
  [[ -z "$announced" ]] || info "  (without --dry-run support, so only announced:$announced)"
  local home
  f_call new_home home
  before="$(snapshot "$home")"
  for mode in "" --reinstall --uninstall --capture; do
    install_ok "$home" --os "${setup%/*}" --profile "${setup#*/}" --dry-run ${mode:+"$mode"} "${flags[@]}" || true
  done
  check_unchanged "home unchanged" "$before" "$(snapshot "$home")"
}

# Check that every file under the link paths of setup $1 (os/profile) is linked into home $2.
# Usage: check_links <setup> <home>
check_links() {
  local setup="$1" home="$2" file target count=0 bad=0 paths link_paths
  f_call setup_info link_paths -- "$setup"
  read -r -a paths <<< "$link_paths"
  while IFS= read -r file; do
    target="$home/${file#home/}"
    count=$((count + 1))
    if [[ ! -L "$target" || "$(readlink "$target")" != "$home/dotfiles/$file" ]]; then
      fail "link missing or wrong: ~/${file#home/} should point to ~/dotfiles/$file"
      bad=$((bad + 1))
    fi
  done < <(git -C "$REPO_ROOT" ls-files -- "${paths[@]}")
  [[ "$bad" != 0 ]] || pass "all $count files under the link paths are linked into ~"
}

# Check the managed startup files in home $1 source env.sh and keep the user's own lines.
# Usage: check_managed_blocks <setup> <home>
check_managed_blocks() {
  local setup="$1" home="$2" file
  for file in .profile .zprofile .bashrc .zshrc; do
    check "managed block in ~/$file sources env.sh" grep -q '^\. ~/dotfiles/home/\.config/sh/env\.sh$' "$home/$file"
  done
  check "user's own line in ~/.bashrc kept" grep -q '^# user line$' "$home/.bashrc"
}

# Check login and interactive bash and zsh load the startup files in home $1 without errors.
# Usage: check_shells_load <setup> <home>
check_shells_load() {
  local setup="$1" home="$2" shell opts err
  for shell in bash zsh; do
    have_or_skip "$shell" "sourcing the $setup startup files with $shell" || continue
    for opts in -lic -ic; do
      # bash prints job control warnings when interactive without a terminal.
      err="$(env -i HOME="$home" PATH=/usr/bin:/bin TERM=dumb "$shell" "$opts" true 2>&1 </dev/null \
        | grep -vE 'cannot set terminal process group|no job control in this shell' || true)"
      if [[ -z "$err" ]]; then
        pass "$shell $opts loads the startup files without errors"
      else
        fail "$shell $opts printed: $err"
      fi
    done
  done
}

# A real install of the rootless features of setup $1 (os/profile), then the same install again, which must change
# nothing. Setups that link anything under root/ need sudo, so only their --dry-run is tested.
# Usage: test_install <setup>
test_install() {
  local setup="$1" flags=(--os "${1%/*}" --profile "${1#*/}" --link --gitconfig) managed=false repo_before first
  local features link_paths
  f_call setup_info features link_paths -- "$setup"
  case " $link_paths" in
    *" root/"*)
      info "$setup: no real install (its links include root/, which needs sudo)"
      return
      ;;
  esac
  # Setups with the shell feature write managed blocks into the startup files instead of linking them.
  list_contains "$features" shell && managed=true
  $managed && flags+=(--shell)
  info "$setup: real install of ${flags[*]:4} (the other features download, build or need root)"
  local home
  f_call new_home home
  if $managed; then
    # The shell feature must keep what is already there. (Linked setups would back it up into the checkout.)
    printf '# user line\n' > "$home/.bashrc"
  fi
  repo_before="$(repo_status)"

  install_ok "$home" "${flags[@]}" || return
  check_links "$setup" "$home"
  if $managed; then
    check_managed_blocks "$setup" "$home"
  fi
  check_shells_load "$setup" "$home"
  check "core.excludesFile set in ~/.gitconfig" \
    [ "$(git config --file "$home/.gitconfig" core.excludesFile)" = "$home/dotfiles/home/.config/git/ignore" ]

  first="$(snapshot "$home")"
  install_ok "$home" "${flags[@]}" || true
  check_unchanged "  ...the second install changed nothing" "$first" "$(snapshot "$home")"
  check_unchanged "nothing was written into the checkout" "$repo_before" "$(repo_status)"
}

# env.sh must be POSIX and safe to source more than once: a second source leaves PATH as it was.
# Usage: test_env_sh
test_env_sh() {
  local shell env_sh="$REPO_ROOT/home/.config/sh/env.sh"
  info "env.sh: sourcing it twice leaves PATH unchanged"
  for shell in sh bash zsh; do
    have_or_skip "$shell" "sourcing env.sh with $shell" || continue
    check "$shell" env -i HOME="$SCRATCH" PATH=/usr/bin:/bin "$shell" -c \
      '. "$1"; first=$PATH; . "$1"; [ "$PATH" = "$first" ]' sh "$env_sh"
  done

  # The gnome Qt theme overrides other desktops' themes (e.g. Plasma's icons and colors), so only gnome gets it.
  info "env.sh: sets QT_QPA_PLATFORMTHEME only in gnome"
  check "set in gnome" env -i HOME="$SCRATCH" PATH=/usr/bin:/bin XDG_CURRENT_DESKTOP=ubuntu:GNOME sh -c \
    '. "$1"; [ "${QT_QPA_PLATFORMTHEME:-}" = gnome ]' sh "$env_sh"
  check "unset in KDE" env -i HOME="$SCRATCH" PATH=/usr/bin:/bin XDG_CURRENT_DESKTOP=KDE sh -c \
    '. "$1"; [ -z "${QT_QPA_PLATFORMTHEME:-}" ]' sh "$env_sh"
}

# vm-usb: steamos links it, and --help describes it without needing a VM, a device or libvirt.
# Usage: test_vm_usb
test_vm_usb() {
  local home flag vm_usb="$REPO_ROOT/home/.local/bin/vm-usb"
  info "vm-usb: linked on steamos, and --help"
  f_call new_home home
  install_ok "$home" --os steamos --profile desktop --machine generic --link \
    && check "  ...vm-usb is linked" test -L "$home/.local/bin/vm-usb"

  for flag in --help -h; do
    check "vm-usb $flag prints its usage and exits 0" env -i HOME="$home" PATH="$PATH" TERM=dumb "$INSTALL_BASH" \
      -c '"$1" "$2" | grep -q "^Usage: vm-usb \[PATTERN \[VM\]\]$"' sh "$vm_usb" "$flag"
  done
  check "vm-usb --help lists the defaults and how to find a VM" env -i HOME="$home" PATH="$PATH" TERM=dumb \
    "$INSTALL_BASH" -c '"$1" --help | grep -q "default: win11" && "$1" --help | grep -q "virsh org.gnome.Boxes list"' \
    sh "$vm_usb"
  check "vm-usb --help stops at the header" env -i HOME="$home" PATH="$PATH" TERM=dumb "$INSTALL_BASH" \
    -c '! "$1" --help | grep -q "LIB_DIR"' sh "$vm_usb"
  check "vm-usb refuses an unknown option" env -i HOME="$home" PATH="$PATH" TERM=dumb "$INSTALL_BASH" \
    -c '! out=$("$1" --bogus 2>&1) && [[ $out == *"Unknown option"* ]]' sh "$vm_usb"
}

# Report a check that function $2 of install/lib/infer.sh, called with the remaining args, prints $1.
# Usage: infer_prints <expected> <function> [<arg>...]
infer_prints() {
  local expected="$1" got
  shift
  # shellcheck source=../install/lib/infer.sh
  got="$(source "$REPO_ROOT/install/lib/infer.sh" && "$@")"
  if [[ "$got" == "$expected" ]]; then pass "$* -> $expected"; else fail "$* -> '$got', expected '$expected'"; fi
}

# What --infer picks for a system: the OS and profile from uname, os-release and Coder's CODER, the machine from DMI.
# Usage: test_infer
test_infer() {
  local os_release="$SCRATCH/os-release"
  info "infer: OSes, profiles and machines for known systems"
  infer_prints steamos os_for_system Linux steamos arch false
  infer_prints arch os_for_system Linux arch "" false
  infer_prints arch os_for_system Linux endeavouros arch false
  infer_prints portable os_for_system Linux ubuntu debian false
  infer_prints portable os_for_system Darwin "" "" false
  infer_prints portable os_for_system Linux arch "" true
  infer_prints "" os_for_system FreeBSD "" "" false
  infer_prints desktop profile_for_system steamos false
  infer_prints desktop profile_for_system arch true
  infer_prints minimal profile_for_system portable false
  infer_prints workspace profile_for_system portable true
  infer_prints framework16 machine_for_dmi Framework "Laptop 16 (AMD Ryzen 7040 Series)"
  infer_prints generic machine_for_dmi Framework "Laptop 13 (AMD Ryzen 7040Series)"
  infer_prints generic machine_for_dmi "" ""

  printf '%s\n' 'NAME="SteamOS"' 'ID=steamos' "ID_LIKE='arch'" > "$os_release"
  check "read_os_release unquotes ID and ID_LIKE" bash -c \
    'source "$1/install/lib/output.sh" && source "$1/install/lib/fn.sh" && source "$1/install/lib/infer.sh" &&
     f_call read_os_release id id_like -- "$2" && [[ "$id:$id_like" == steamos:arch ]]' sh "$REPO_ROOT" "$os_release"
}

# Check that a function of install/oti/arch-chroot.sh, run with the remaining args, prints $1.
# Usage: arch_chroot_prints <expected> <function> [<arg>...]
arch_chroot_prints() {
  local expected="$1" got
  shift
  # shellcheck source=../install/oti/arch-chroot.sh
  got="$(source "$REPO_ROOT/install/lib/fn.sh" && source "$REPO_ROOT/install/oti/arch-chroot.sh" && "$@")"
  if [[ "$got" == "$expected" ]]; then pass "$* -> $expected"; else fail "$* -> '$got', expected '$expected'"; fi
}

# Check that a function of install/oti/arch-chroot.sh, run with the remaining args, returns $1 (0 or 1).
# Usage: arch_chroot_returns <expected> <function> [<arg>...]
arch_chroot_returns() {
  local expected="$1" got=0
  shift
  (source "$REPO_ROOT/install/lib/fn.sh" && source "$REPO_ROOT/install/oti/arch-chroot.sh" && "$@") || got=1
  if [[ "$got" == "$expected" ]]; then pass "$* returns $expected"; else fail "$* returns $got, expected $expected"; fi
}

# Return 0 if arch_chroot_packages for CPU vendor $1, dual booting when $2 is true, includes package $3.
# Usage: packages_include <vendor> <dual> <package>
packages_include() {
  list_contains "$(arch_chroot_packages "$1" "$2")" "$3"
}

# One-time installs: --oti is refused with anything else and can't be undone; arch-chroot's --dry-run prints every
# command without touching the home; and its pure helpers.
# Usage: test_oti
test_oti() {
  local dir="$SCRATCH/oti" before home
  info "one-time installs"
  f_call new_home home
  install_ok "$home" --help && check "  ...lists --oti arch-chroot" grep -q '^  arch-chroot ' "$LOG"
  install_refused "$home" --oti nope
  install_refused "$home" --oti arch-chroot --variant arch
  install_refused "$home" --oti arch-chroot --infer
  install_refused "$home" --oti arch-chroot --all
  install_refused "$home" --oti arch-chroot --uninstall

  before="$(snapshot "$home")"
  if env -i HOME="$home" PATH="$PATH" TERM=dumb DOTFILES_ARCH_DISK=/dev/nvme0n1 DOTFILES_ARCH_USER=tester \
    DOTFILES_ARCH_SWAP_SIZE=8 "$INSTALL_BASH" "$home/dotfiles/install.sh" --oti arch-chroot --dry-run \
    </dev/null >"$LOG" 2>&1; then
    pass "install.sh --oti arch-chroot --dry-run"
  else
    fail "install.sh --oti arch-chroot --dry-run"
    sed 's/^/       | /' "$LOG" >&2
  fi
  check "  ...partitions the disk" grep -q 'sfdisk --quiet /dev/nvme0n1 <<' "$LOG"
  check "  ...formats nvme0n1p2" grep -q 'mkfs.btrfs --force --quiet /dev/nvme0n1p2$' "$LOG"
  check "  ...pacstraps the packages" grep -q 'pacstrap -K /mnt --needed base ' "$LOG"
  check "  ...creates @swap" grep -q 'btrfs subvolume create /run/dotfiles-btrfs/@swap$' "$LOG"
  check "  ...makes an 8G swap file" grep -q 'btrfs filesystem mkswapfile --size 8g /mnt/swap/swapfile$' "$LOG"
  check "  ...adds it to fstab" grep -q '^/swap/swapfile none swap defaults 0 0$' "$LOG"
  check "  ...installs GRUB at the fallback path" grep -q 'grub-install .*--removable$' "$LOG"
  check "  ...clones dotfiles for the user" grep -q 'clone .* /mnt/home/tester/dotfiles$' "$LOG"
  check_unchanged "  ...home unchanged" "$before" "$(snapshot "$home")"

  if env -i HOME="$home" PATH="$PATH" TERM=dumb DOTFILES_ARCH_DISK=partitions DOTFILES_ARCH_EFI=/dev/sda1 \
    DOTFILES_ARCH_ROOT=/dev/sda5 DOTFILES_ARCH_SWAP_PART=/dev/sda6 DOTFILES_ARCH_USER=tester "$INSTALL_BASH" \
    "$home/dotfiles/install.sh" --oti arch-chroot --dry-run </dev/null >"$LOG" 2>&1; then
    pass "install.sh --oti arch-chroot --dry-run, onto partitions"
  else
    fail "install.sh --oti arch-chroot --dry-run, onto partitions"
    sed 's/^/       | /' "$LOG" >&2
  fi
  check "  ...doesn't repartition" bash -c '! grep -q "wipefs\|sfdisk" "$1"' sh "$LOG"
  check "  ...keeps the EFI system partition" bash -c '! grep -q "mkfs.fat" "$1"' sh "$LOG"
  check "  ...formats the root and swap partitions" bash -c \
    'grep -q "mkfs.btrfs --force --quiet /dev/sda5$" "$1" && grep -q "mkswap /dev/sda6$" "$1"' sh "$LOG"
  check "  ...adds the swap partition to fstab" grep -q '^UUID=.* none swap defaults 0 0$' "$LOG"
  check "  ...installs and enables os-prober" bash -c \
    'grep -q "pacstrap .* os-prober" "$1" && grep -q "GRUB_DISABLE_OS_PROBER=false" "$1"' sh "$LOG"
  check "  ...leaves the fallback path alone" bash -c '! grep -q -- "--removable" "$1"' sh "$LOG"

  arch_chroot_prints /dev/vda1 arch_chroot_partition /dev/vda 1
  arch_chroot_prints /dev/nvme0n1p2 arch_chroot_partition /dev/nvme0n1 2
  arch_chroot_prints /dev/mmcblk0p1 arch_chroot_partition /dev/mmcblk0 1
  arch_chroot_returns 0 packages_include AuthenticAMD false amd-ucode
  arch_chroot_returns 0 packages_include GenuineIntel false intel-ucode
  arch_chroot_returns 1 packages_include "" false amd-ucode
  arch_chroot_returns 0 packages_include "" true os-prober
  arch_chroot_returns 1 packages_include "" false os-prober
  arch_chroot_prints $'127.0.0.1 localhost\n::1 localhost\n127.0.1.1 box' arch_chroot_hosts box
  arch_chroot_prints "UUID=2026-10-01-14-49-03-00" arch_chroot_live_tag \
    "initrd=x archisobasedir=arch archisosearchuuid=2026-10-01-14-49-03-00 console=ttyS0"
  arch_chroot_prints "LABEL=ARCH_202610" arch_chroot_live_tag "archisobasedir=arch archisolabel=ARCH_202610"
  arch_chroot_prints "" arch_chroot_live_tag "root=/dev/vda2 rw"
  arch_chroot_returns 0 arch_chroot_valid_swap_size 0 10
  arch_chroot_returns 0 arch_chroot_valid_swap_size 8 10
  arch_chroot_returns 1 arch_chroot_valid_swap_size 11 10
  arch_chroot_returns 1 arch_chroot_valid_swap_size 08 10
  arch_chroot_returns 1 arch_chroot_valid_swap_size 4G 10
  arch_chroot_returns 0 arch_chroot_valid_hostname my-box1
  arch_chroot_returns 1 arch_chroot_valid_hostname -box
  arch_chroot_returns 0 arch_chroot_valid_user tester
  arch_chroot_returns 1 arch_chroot_valid_user root
  arch_chroot_returns 1 arch_chroot_valid_user Tester

  mkdir -p "$dir/zoneinfo/America" "$dir/keymaps/i386/qwerty"
  touch "$dir/zoneinfo/America/New_York" "$dir/keymaps/i386/qwerty/us.map.gz"
  printf '%s\n' 'en_US.UTF-8 UTF-8' 'en_US ISO-8859-1' > "$dir/SUPPORTED"
  printf '%s\n' 'root:*:19000::::::' 'locked:!:19000::::::' 'me:$6$salt$hash:19000::::::' 'empty::19000::::::' \
    > "$dir/shadow"
  arch_chroot_returns 0 arch_chroot_valid_timezone America/New_York "$dir/zoneinfo"
  arch_chroot_returns 1 arch_chroot_valid_timezone America/Nowhere "$dir/zoneinfo"
  arch_chroot_returns 1 arch_chroot_valid_timezone ../shadow "$dir/zoneinfo"
  arch_chroot_returns 0 arch_chroot_valid_locale en_US.UTF-8 "$dir/SUPPORTED"
  arch_chroot_returns 1 arch_chroot_valid_locale en_GB.UTF-8 "$dir/SUPPORTED"
  arch_chroot_returns 0 arch_chroot_valid_keymap us "$dir/keymaps"
  arch_chroot_returns 1 arch_chroot_valid_keymap xx "$dir/keymaps"
  arch_chroot_returns 0 arch_chroot_has_password "$dir/shadow" me
  arch_chroot_returns 1 arch_chroot_has_password "$dir/shadow" root
  arch_chroot_returns 1 arch_chroot_has_password "$dir/shadow" locked
  arch_chroot_returns 1 arch_chroot_has_password "$dir/shadow" empty
  arch_chroot_returns 1 arch_chroot_has_password "$dir/shadow" nobody
}

# --machine picks the hardware, which decides whether --all includes features for specific hardware; --infer fills in
# the OS, profile or machine not given, to suit the ones given, and only then.
# Usage: test_machine
test_machine() {
  local out
  info "machine: --machine, DOTFILES_MACHINE and --infer"
  local home
  f_call new_home home
  install_ok "$home" --variant steamos --help \
    && check "  ...lists machine-specific options apart on machine generic" grep -q "For other machines" "$LOG"
  install_ok "$home" --variant steamos --machine framework16 --help \
    && check "  ...lists them with the rest on framework16" sh -c '! grep -q "For other machines" "$1"' sh "$LOG"
  # --all goes on to webterm, which needs a live systemd user session (see DRY_RUN_SKIP), so ignore the status: udev
  # runs before it. It names its rule whether it copies it or finds it already up to date, as on a configured machine.
  run_install "$home" --variant steamos --machine generic --all --dry-run || true
  check "--all leaves them out on generic" sh -c '! grep -q 90-touchpad-nowake.rules "$1"' sh "$LOG"
  run_install "$home" --variant steamos --machine framework16 --all --dry-run || true
  check "--all includes them on framework16" grep -q /etc/udev/rules.d/90-touchpad-nowake.rules "$LOG"
  install_ok "$home" --variant steamos --udev --dry-run \
    && check "  ...naming one runs it on generic, with a warning" grep -q "udev is for machine framework16" "$LOG"
  install_refused "$home" --variant steamos --machine nope
  install_refused "$home" --machine framework16 --gitconfig

  write_install_conf "$home" "DOTFILES_VARIANT=steamos" "DOTFILES_MACHINE=framework16"
  install_ok "$home" && check "  ...DOTFILES_MACHINE names the default machine" \
    grep -q "Options for OS 'steamos' with profile 'desktop' on machine 'framework16'" "$LOG"
  rm "$home/.config/dotfiles/install.conf"

  if out="$(env -i HOME="$home" PATH="$PATH" TERM=dumb CODER=true \
    "$INSTALL_BASH" "$home/dotfiles/install.sh" --infer --help </dev/null 2>&1)" \
    && grep -q "Options for OS 'portable' with profile 'workspace'" <<< "$out"; then
    pass "--infer picks coder in a Coder workspace"
  else
    fail "--infer picks coder in a Coder workspace: $out"
  fi
  install_ok "$home" --variant arch --machine generic --infer --help \
    && check "  ...and infers nothing given" sh -c '! grep -q Inferred "$1"' sh "$LOG"
  install_ok "$home" --variant arch --infer --help \
    && check "  ...and only the machine with --variant" grep -q "Inferred machine '[a-z0-9]*' from" "$LOG"
  install_ok "$home" --profile workspace --infer --help \
    && check "  ...and an OS with the given profile" grep -q "Options for OS 'portable' with profile 'workspace'" "$LOG"
}

# The steam feature replaces the hotkeys Steam already wrote, keeps the other settings, warns about missing keys
# instead of adding them, backs up the file and changes nothing on a second run.
# Usage: test_steam
test_steam() {
  local userdata vdf_a vdf_b b_before first
  info "steam: hotkeys replaced in localconfig.vdf"
  if pgrep -x steam >/dev/null 2>&1; then
    warn "Steam is running; skipping the steam feature test"
    return
  fi
  local home
  f_call new_home home
  userdata="$home/.local/share/Steam/userdata"
  vdf_a="$userdata/1/config/localconfig.vdf"
  vdf_b="$userdata/2/config/localconfig.vdf"
  mkdir -p "${vdf_a%/*}" "${vdf_b%/*}"
  printf '"UserLocalConfigStore"\n{\n\t"Gamescope"\n\t{\n\t\t"GameResolutionGlobal"\t\t"Default"\n' > "$vdf_a"
  printf '\t\t"GuideKeyboardHotkey"\t\t"Ctrl\tWin\tKEY_TAB"\n\t\t"QAMKeyboardHotkey"\t\t"Shift\tKEY_TAB"\n' >> "$vdf_a"
  printf '\t}\n}\n' >> "$vdf_a"
  printf '"UserLocalConfigStore"\n{\n\t"friends"\t\t"1"\n}\n' > "$vdf_b"
  b_before="$(cat "$vdf_b")"

  install_ok "$home" --variant steamos --steam || return
  check "main menu hotkey replaced" grep -qx $'\t\t"GuideKeyboardHotkey"\t\t"Win\tKEY_TAB"' "$vdf_a"
  check "quick access hotkey replaced" grep -qx $'\t\t"QAMKeyboardHotkey"\t\t"Shift\tWin\tKEY_TAB"' "$vdf_a"
  check "other settings kept" grep -q '"GameResolutionGlobal"' "$vdf_a"
  check "missing keys not added" [ "$(cat "$vdf_b")" = "$b_before" ]
  check "  ...but warned about" grep -q "$vdf_b has no GuideKeyboardHotkey QAMKeyboardHotkey" "$LOG"
  check "original backed up" grep -q '"Ctrl' "$REPO_ROOT/.backup$vdf_a"
  first="$(snapshot "$home")"
  install_ok "$home" --variant steamos --steam || true
  check_unchanged "  ...the second install changed nothing" "$first" "$(snapshot "$home")"
  # Backups land in the checkout (the scratch home links to it).
  rm -rf "$REPO_ROOT/.backup$SCRATCH"
  rmdir -p "$(dirname "$REPO_ROOT/.backup$SCRATCH")" 2>/dev/null || true
}

# Run bash snippet $1 under INSTALL_BASH with install/lib/output.sh and fn.sh loaded and these test functions defined:
# pair returns a and b, nested returns a after an f_call of pair, half returns only a, and tricky returns a value
# with = signs, spaces, quotes and a newline. Its output goes to LOG.
# Usage: f_call_snippet <snippet>
f_call_snippet() {
  "$INSTALL_BASH" -c 'set -euo pipefail; source "$0/output.sh"; source "$0/fn.sh"
    pair() { f_return a="a:$1" b="b:$1"; }
    nested() { local inner; f_call pair inner=a -- in; f_return a="outer($inner)"; }
    half() { f_return a=1; }
    tricky() { f_return a="x=1 y==2 \"q\"
z" b=""; }
    '"$1" "$REPO_ROOT/install/lib" >"$LOG" 2>&1
}

# f_call sets its caller's variables from the values a function returns with f_return, the way read does, and checks
# them.
# Usage: test_f_call
test_f_call() {
  info "f_call and f_return: returning named values"
  check "sets the named variables" f_call_snippet \
    'f() { local a b; f_call pair a b -- x; [[ "$a $b" == "a:x b:x" ]]; }; f'
  check "sets a renamed one from the value it names" f_call_snippet \
    'f() { local first; f_call pair first=a -- x; [[ "$first" == a:x ]]; }; f'
  check "keeps = signs, spaces, quotes, newlines and empty values" f_call_snippet \
    'f() { local a b; f_call tricky a b; [[ "$a" == "x=1 y==2 \"q\""$'"'"'\n'"'"'z && -z "$b" ]]; }; f'
  check "a nested call doesn't clobber the outer one's values" f_call_snippet \
    'f() { local a; f_call nested a; [[ "$a" == "outer(a:in)" ]]; }; f'
  check "leaves no variables behind, even for values nobody asked for" f_call_snippet \
    'f() { local a; f_call pair a -- x; [[ -z "${_a+x}${_b+x}" ]]; }; f; pair x; [[ -z "${_a+x}${_b+x}" ]]'
  check "fails if the function doesn't return a value asked for" f_call_snippet \
    '! out="$( (f_call half a b) 2>&1)" && [[ "$out" == *"did not return '"'"'b'"'"'"* ]]'
  check "rejects a variable that starts with an underscore" f_call_snippet \
    '! (f_call pair _a) && ! (f_call pair a=_a)'
  check "returns a bare name's variable" f_call_snippet \
    'f() { local a="x=1 y" b=""; f_return a b c=3; }; g() { local a b c; f_call f a b c; [[ "$a|$b|$c" == "x=1 y||3" ]]; }; g'
  check "returns a bare name declared with no value as empty" f_call_snippet \
    'f() { local a; f_return a; }; g() { local a=x; f_call f a; [[ -z "$a" ]]; }; g'
  check "fails on a bare name that isn't a variable" f_call_snippet \
    'f() { f_return nope; }; ! out="$( (f_call f nope) 2>&1)" && [[ "$out" == *"is not a variable"* ]]'
  check "rejects a return without a name" f_call_snippet \
    'f() { f_return "=1"; }; ! (f_call f a) && f() { f_return _a; } && ! (f_call f a)'
}

# --capture --dconf writes the keys DCONF_CAPTURE selects from dconf into dump/dconf/arch.dconf, with paths under the home
# directory written as ${HOME}/...: here one selected key, one left out with ! and one in a directory it doesn't select.
# Usage: test_capture_dconf
test_capture_dconf() {
  local home saved="$SCRATCH/arch.dconf.saved" file="$REPO_ROOT/dump/dconf/arch.dconf" expected
  info "capture: dconf writes the selected keys into dump/dconf/arch.dconf"
  f_call new_home home
  mkdir -p "$home/keyfile" "$home/.config/dconf"
  printf '%s\n' '[org/gnome/desktop/peripherals/keyboard]' 'delay=uint32 123' '' \
    '[org/gnome/desktop/input-sources]' "mru-sources=[('xkb', 'us')]" '' \
    '[org/gnome/desktop/screensaver]' "picture-uri='file://$home/wallpaper.jpg'" '' \
    '[org/gnome/desktop/notifications]' "application-children=['app']" > "$home/keyfile/settings"
  # Compiled straight into the user database, so no session bus is needed.
  dconf compile "$home/.config/dconf/user" "$home/keyfile"
  expected="$(printf '%s\n' '[org/gnome/desktop/peripherals/keyboard]' 'delay=uint32 123' '' \
    '[org/gnome/desktop/screensaver]' "picture-uri='file://\${HOME}/wallpaper.jpg'")"
  cp "$file" "$saved"
  install_ok "$home" --variant arch --capture --dconf --dry-run \
    && check "  ...--dry-run leaves arch.dconf alone" cmp -s "$saved" "$file"
  install_ok "$home" --variant arch --capture --dconf \
    && check "  ...arch.dconf holds just the selected keys, with \${HOME}" [ "$(cat "$file")" = "$expected" ]
  cp "$saved" "$file"
}

# --capture --kde writes home/.config/kcminputrc from ~/.config/kcminputrc, keeping the groups KDE_CAPTURE selects:
# here [Keyboard], and not [Mouse]. Needs no KDE tools, so it runs everywhere.
# Usage: test_capture_kde
test_capture_kde() {
  local dir="$SCRATCH/kde.saved" file="$REPO_ROOT/home/.config/kcminputrc" nested="$REPO_ROOT/home/.config/powerdevilrc"
  local home expected expected_nested
  info "capture: kde writes the selected keys of ~/.config files into home/.config, nested groups included"
  f_call new_home home
  mkdir -p "$home/.config" "$dir"
  printf '%s\n' '[Keyboard]' 'NumLock=0' 'RepeatDelay=123' '' '[Mouse]' 'X11LibInputXAccelProfileFlat=true' \
    > "$home/.config/kcminputrc"
  printf '%s\n' '[AC][SuspendAndShutdown]' 'LidAction=64' 'PowerButtonAction=16' '' '[AC][Display]' 'DimDisplayWhenIdle=true' \
    > "$home/.config/powerdevilrc"
  expected="$(printf '%s\n' '[Keyboard]' 'NumLock=0' 'RepeatDelay=123')"
  expected_nested="$(printf '%s\n' '[AC][SuspendAndShutdown]' 'LidAction=64')"
  cp "$file" "$dir/kcminputrc"
  cp "$nested" "$dir/powerdevilrc"
  install_ok "$home" --variant steamos --capture --kde --dry-run \
    && check "  ...--dry-run leaves the files alone" cmp -s "$dir/kcminputrc" "$file" \
    && check "  ...--dry-run leaves the nested one alone" cmp -s "$dir/powerdevilrc" "$nested"
  install_ok "$home" --variant steamos --capture --kde \
    && check "  ...kcminputrc holds just the selected group" [ "$(cat "$file")" = "$expected" ] \
    && check "  ...powerdevilrc holds just the selected key of the nested group" [ "$(cat "$nested")" = "$expected_nested" ]
  cp "$dir/kcminputrc" "$file"
  cp "$dir/powerdevilrc" "$nested"
}

# --capture copies settings from this system into the repo's files.
# Usage: test_capture
test_capture() {
  test_capture_kde
  if command -v dconf >/dev/null; then
    test_capture_dconf
  else
    warn "dconf not found; skipping the dconf capture test"
  fi
}

# Run download_verified with DOWNLOAD_CACHE $1 and the remaining args (url, sha256, out) in a fresh bash, its output
# going to LOG. Returns its status.
# Usage: download_with_cache <cache> <url> <sha256> <out>
download_with_cache() {
  local cache="$1"
  shift
  "$INSTALL_BASH" -c 'set -euo pipefail; DRY_RUN=false DOWNLOAD_CACHE="$1"; shift
    source "$0/output.sh"; source "$0/fn.sh"; source "$0/fs.sh"; download_verified "$@" test' \
    "$REPO_ROOT/install/lib" "$cache" "$@" >"$LOG" 2>&1
}

# With DOTFILES_DOWNLOAD_CACHE, download_verified stores downloads under their SHA-256 and uses a cached file instead of
# downloading, but only one that matches.
# Usage: test_download_cache
test_download_cache() {
  local dir sha
  info "download_verified: DOTFILES_DOWNLOAD_CACHE"
  dir="$(mktemp -d "$SCRATCH/download.XXXXXX")"
  printf 'payload\n' > "$dir/src"
  sha="$(sha256_of "$dir/src")"
  check "a download is stored in the cache" download_with_cache "$dir/cache" "file://$dir/src" "$sha" "$dir/out1"
  check "  ...under its SHA-256" cmp -s "$dir/src" "$dir/cache/$sha"
  mv "$dir/src" "$dir/moved"
  check "a cached file is used instead of downloading" download_with_cache "$dir/cache" "file://$dir/src" "$sha" "$dir/out2"
  check "  ...and copied out" cmp -s "$dir/moved" "$dir/out2"
  printf 'tampered\n' > "$dir/cache/$sha"
  if download_with_cache "$dir/cache" "file://$dir/src" "$sha" "$dir/out3"; then
    fail "a cached file that doesn't match its SHA-256 is downloaded again"
  else
    pass "a cached file that doesn't match its SHA-256 is downloaded again"
  fi
}

# Run the code in $2 in a fresh bash with the shared library loaded, DRY_RUN=$1 and BACKUPS_ROOT and DOTFILES_ROOT in
# SCRATCH, its output going to LOG. Returns its status.
# Usage: lib_run <dry_run> <code>
lib_run() {
  local dry_run="$1" code="$2" lib="$REPO_ROOT/install/lib"
  "$INSTALL_BASH" -c 'set -euo pipefail; DRY_RUN="$1"; BACKUPS_ROOT="$2/backups"; DOTFILES_ROOT="$2/root"
    for f in output fn exec fs capture; do source "$3/$f.sh"; done
    eval "$4"' lib_run "$dry_run" "$SCRATCH" "$lib" "$code" >"$LOG" 2>&1
}

# The shared library's dry-run output, upsert_block, confirmsed, write_captured and file_sha256.
# Usage: test_lib_helpers
test_lib_helpers() {
  local dir file
  info "install/lib: dry-run output, upsert_block, confirmsed, write_captured, file_sha256"
  dir="$(mktemp -d "$SCRATCH/lib.XXXXXX")"

  lib_run true 'run printf "%s\n" "two words" ""'
  check "run shows a command with its quoting under --dry-run" grep -qF "'two words' ''" "$LOG"

  file="$dir/rc"
  lib_run false "upsert_block '$file' x 'line one'"
  lib_run true "upsert_block '$file' x 'line one'"
  check "upsert_block --dry-run says an unchanged block is up to date" grep -q "already up to date" "$LOG"
  lib_run true "upsert_block '$file' x 'line two'"
  check "upsert_block --dry-run says a changed block would be set" grep -q "would set block" "$LOG"
  check "  ...and leaves the file alone" grep -qx "line one" "$file"

  file="$dir/main.conf"
  printf 'a\n#Opt=off\nb\n' > "$file"
  lib_run true "confirmsed '$file' '#Opt=off' 'Opt=on&x'"
  check "confirmsed --dry-run announces the replacement" grep -q "would replace" "$LOG"
  check "  ...and leaves the file alone" grep -qx "#Opt=off" "$file"
  lib_run false "confirm() { return 0; }; has_tty() { return 1; }; confirmsed '$file' '#Opt=off' 'Opt=on&x'"
  check "confirmsed replaces the matching line with the literal text" grep -qxF "Opt=on&x" "$file"
  check "  ...keeping the other lines" test "$(grep -c '' "$file")" = 3
  check "  ...and a backup" grep -qx "#Opt=off" "$SCRATCH/backups$file"
  lib_run false "confirm() { return 1; }; confirmsed '$file' 'Opt=on&x' 'z'"
  check "confirmsed leaves the file alone when declined" grep -qxF "Opt=on&x" "$file"
  lib_run false "confirmsed '$file' 'nothing' 'nope'"
  check "confirmsed warns when neither is found" grep -q "Neither" "$LOG"
  lib_run false "confirmsed '$file' 'nothing' 'Opt=on&x'"
  check "  ...but not when the replacement is already there" test ! -s "$LOG"

  mkdir -p "$SCRATCH/root"
  file="$SCRATCH/root/new.txt"
  lib_run true "write_captured '$file' 'text'"
  check "write_captured --dry-run diffs a missing file against empty" grep -q "^+text" "$LOG"
  check "  ...without creating it" test ! -e "$file"

  printf 'payload\n' > "$dir/src"
  lib_run false "f_call file_sha256 sha=sha256 -- '$dir/src'; sha256_matches '$dir/src' \"\$sha\" && ! sha256_matches '$dir/src' 00"
  check "file_sha256 and sha256_matches compare a file's SHA-256" test ! -s "$LOG"
}

# Run bash code $1 with the install library's output.sh and fs.sh loaded and the remaining args as $1.., its output
# going to LOG. Returns its status.
# Usage: run_fs_lib <code> [<arg>...]
run_fs_lib() {
  local code="$1"
  shift
  "$INSTALL_BASH" -c 'set -euo pipefail; DRY_RUN=false; source "$0/output.sh"; source "$0/fs.sh"; code="$1"; shift; eval "$code"' \
    "$REPO_ROOT/install/lib" "$code" "$@" >"$LOG" 2>&1
}

# with_tmpdir removes its directory however the command ends, and clone_pinned only accepts the commit it was given.
# Usage: test_tmpdir_and_pinned_clone
test_tmpdir_and_pinned_clone() {
  local dir commit
  info "with_tmpdir and clone_pinned"
  dir="$(mktemp -d "$SCRATCH/tmpdir.XXXXXX")"
  # shellcheck disable=SC2016 # expanded by the inner bash
  run_fs_lib 'w() { printf "%s" "${@: -1}" > "$1"; }; with_tmpdir w "$1"' "$dir/ok" || true
  check "with_tmpdir passes a directory and removes it afterwards" test -n "$(cat "$dir/ok")" -a ! -e "$(cat "$dir/ok")"
  # shellcheck disable=SC2016 # expanded by the inner bash
  if run_fs_lib 'f() { printf "%s" "$2" > "$1"; false; }; with_tmpdir f "$1"; touch "$1.after"' "$dir/fail"; then
    fail "with_tmpdir returns the command's failure"
  else
    pass "with_tmpdir returns the command's failure"
  fi
  check "  ...and removes its directory" test ! -e "$(cat "$dir/fail")"
  # shellcheck disable=SC2016 # expanded by the inner bash
  run_fs_lib 'f() { printf "%s" "$2" > "$1"; error boom; }; with_tmpdir f "$1"' "$dir/err" || true
  check "with_tmpdir removes its directory when the command calls error" test ! -e "$(cat "$dir/err")"

  git init -q "$dir/repo"
  git -C "$dir/repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
  commit="$(git -C "$dir/repo" rev-parse HEAD)"
  # shellcheck disable=SC2016 # expanded by the inner bash
  check "clone_pinned checks out the pinned commit" \
    run_fs_lib 'clone_pinned "$1" "$2" "$3"; test "$(git -C "$3" rev-parse HEAD)" = "$2"' "$dir/repo" "$commit" "$dir/clone"
  # shellcheck disable=SC2016 # expanded by the inner bash
  check "  ...again, unchanged" run_fs_lib 'clone_pinned "$1" "$2" "$3"' "$dir/repo" "$commit" "$dir/clone"
  # shellcheck disable=SC2016 # expanded by the inner bash
  if run_fs_lib 'clone_pinned "$1" "$2" "$3"' "$dir/repo" "0000000000000000000000000000000000000000" "$dir/clone2"; then
    fail "clone_pinned rejects a commit the remote doesn't have"
  else
    pass "clone_pinned rejects a commit the remote doesn't have"
  fi
  # shellcheck disable=SC2016 # expanded by the inner bash
  if run_fs_lib 'clone_pinned "$1" v1 "$2"' "$dir/repo" "$dir/clone3"; then
    fail "clone_pinned rejects a ref that isn't a full commit hash"
  else
    pass "clone_pinned rejects a ref that isn't a full commit hash"
  fi
}

# Run every test, then fail if any check failed.
# Usage: main
main() {
  local setup
  info "install.sh runs under $("$INSTALL_BASH" -c 'echo "bash $BASH_VERSION"')"
  test_usage "$(with_install_loaded available_names variants)"
  test_dimensions
  test_defaults
  test_cli
  test_checkout_location
  test_clone_checkout
  test_bootstrap
  test_publish
  for setup in $(with_install_loaded print_all_setups); do
    test_dry_run "$setup"
    test_install "$setup"
  done
  test_infer
  test_oti
  test_machine
  test_steam
  test_capture
  test_download_cache
  test_lib_helpers
  test_tmpdir_and_pinned_clone
  test_f_call
  test_env_sh
  test_vm_usb

  [[ "$FAILURES" == 0 ]] || error "$FAILURES check(s) failed"
  info "all install tests passed"
}

main "$@"
