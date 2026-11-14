# Desktop: a machine of your own with a desktop session.
# Usage: f_call profile_desktop description git_fsmonitor
# Returns: description git_fsmonitor
profile_desktop() {
  f_return description="a machine of your own with a desktop session: desktop apps and config, linked startup files"
  f_return git_fsmonitor=true
}
