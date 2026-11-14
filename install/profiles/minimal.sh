# Minimal: a terminal setup only.
# Usage: f_call profile_minimal description git_fsmonitor
# Returns: description git_fsmonitor
profile_minimal() {
  f_return description="a terminal setup only: shell, editor, tmux and git, without desktop apps or config"
  f_return git_fsmonitor=true
}
