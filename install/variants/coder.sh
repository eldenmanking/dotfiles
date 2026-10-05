# TODO(andywang): add comment
VARIANT_DESCRIPTION="Coder workspaces: lightweight, rootless-friendly terminal setup (formerly light-install.sh)"
VARIANT_FEATURES="binaries link zsh shell starship tmux gng tre claude gitconfig"
VARIANT_ALL_EXCLUDE=""
LINK_INCLUDE_PATHS=("${LINK_COMMON_PATHS[@]}")

# This is not compatible with coder
GIT_FSMONITOR=false
