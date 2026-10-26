# Any Linux or macOS, without relying on its package manager.
os_portable() {
  _description="any Linux or macOS (e.g. Windows WSL): no package manager or root required"
  _platforms="linux macos"
  _machines="generic"
}

# Portable terminal setup, writing managed blocks into the shell startup files.
os_portable_minimal() {
  _features="binaries link zsh shell starship tmux gitconfig"
  _gui="none"
  _optional=""
  _link_paths="${LINK_COMMON_PATHS[*]}"
}

# Coder workspaces, writing managed blocks into the shell startup files.
os_portable_workspace() {
  _features="binaries link zsh shell starship tmux gng tre claude gitconfig"
  _gui="none"
  _optional=""
  _link_paths="${LINK_COMMON_PATHS[*]}"
}
