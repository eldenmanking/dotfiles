# Any Linux or macOS, without relying on its package manager.
# Usage: f_call os_portable description platforms machines
# Returns: description platforms machines
os_portable() {
  f_return description="any Linux or macOS (e.g. Windows WSL): no package manager or root required"
  f_return platforms="linux macos"
  f_return machines="generic"
}

# Portable terminal setup, writing managed blocks into the shell startup files.
# Usage: f_call os_portable_minimal features gui optional link_paths
# Returns: features gui optional link_paths
os_portable_minimal() {
  f_return features="binaries link zsh shell starship tmux gitconfig"
  f_return gui="none"
  f_return optional=""
  f_return link_paths="${LINK_COMMON_PATHS[*]}"
}

# Coder workspaces, writing managed blocks into the shell startup files.
# Usage: f_call os_portable_workspace features gui optional link_paths
# Returns: features gui optional link_paths
os_portable_workspace() {
  f_return features="binaries link zsh shell starship tmux gng tre claude gitconfig"
  f_return gui="none"
  f_return optional=""
  f_return link_paths="${LINK_COMMON_PATHS[*]}"
}
