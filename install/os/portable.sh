# Any Linux or macOS, without relying on its package manager.
os_portable() {
  f_return description="any Linux or macOS (e.g. Windows WSL): no package manager or root required"
  f_return platforms="linux macos"
  f_return machines="generic"
}

# Portable terminal setup, writing managed blocks into the shell startup files.
os_portable_minimal() {
  f_return features="$FEATURES_PORTABLE gitconfig"
  f_return gui="none"
  f_return optional=""
  f_return link_paths="${LINK_COMMON_PATHS[*]}"
}

# Coder workspaces, writing managed blocks into the shell startup files.
os_portable_workspace() {
  f_return features="$FEATURES_PORTABLE gng tre claude gitconfig"
  f_return gui="none"
  f_return optional=""
  f_return link_paths="${LINK_COMMON_PATHS[*]}"
}
