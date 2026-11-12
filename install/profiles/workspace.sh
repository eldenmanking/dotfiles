# Workspace: a remote dev box such as a Coder workspace.
# Usage: f_call profile_workspace description git_fsmonitor
# Returns: description git_fsmonitor
profile_workspace() {
  f_return description="Coder workspaces: lightweight, rootless-friendly terminal setup (formerly light-install.sh)"
  # Leave git's core.fsmonitor off: its file system watcher daemon doesn't suit Coder workspaces.
  f_return git_fsmonitor=false
}
