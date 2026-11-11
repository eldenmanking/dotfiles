# One-time installs (install/oti/<name>.sh, run with --oti <name>): setting up a machine once, such as installing an
# OS from its live ISO, rather than configuring the machine install.sh runs on. Each defines oti_<name>, which asks
# its questions up front and then runs steps that each check what is done first, so a rerun resumes where an earlier
# run stopped. They print every command they run (run_shown in install/lib/exec.sh) and honor --dry-run, and they
# can't be undone, so they have no uninstall. See One-time installs in README.md.

# Print the function that runs one-time install $1.
oti_function() {
  fn_name oti_ "$1"
}

# Return 0 if one-time install $1 exists.
oti_exists() {
  [[ -n "$1" ]] && fn_defined "$(oti_function "$1")"
}

# Call oti_config_<name>, which returns description.
oti_config() {
  oti_exists "$1" || error "Unknown one-time install '$1'"
  "$(fn_name oti_config_ "$1")"
}

# Run one-time install $1. It runs as a plain command, not in a condition, so set -e stops it at the first command that
# fails (bash ignores set -e in everything a condition calls); the EXIT trap then says how to go on.
run_oti() {
  trap '[[ $? -eq 0 ]] || warn "One-time install stopped before finishing; run it again to resume."' EXIT
  info "Beginning one-time install: $1..."
  "$(oti_function "$1")"
  info "One-time install $1 complete."
}
