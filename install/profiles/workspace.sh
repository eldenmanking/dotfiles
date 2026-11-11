# Workspace: a remote dev box such as a Coder workspace.
# Usage: f_call profile_workspace description git_fsmonitor
# Returns: description git_fsmonitor
profile_workspace() {
  f_return description="Coder workspaces: lightweight, rootless-friendly terminal setup (formerly light-install.sh)"
  # This is not compatible with coder
  f_return git_fsmonitor=false
}
