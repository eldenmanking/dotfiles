# Environmental Variables
export PATH="$HOME/.local/bin${PATH:+:$PATH}"                   # User executables
export PATH="/usr/bin/vendor_perl${PATH:+:$PATH}"               # Perl executables (e.g. biber)

export LS_COLORS=$LS_COLORS:ow=0:ex=0                           # Don't change color of directories/files with o+w permissions
export EDITOR=/usr/bin/nvim                                     # Change default editor
export QT_QPA_PLATFORMTHEME=gnome                               # Make QT applications use gnome theme when launched from terminal

# Color man pages
export LESS_TERMCAP_mb=$'\E[01;32m'
export LESS_TERMCAP_md=$'\E[01;32m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;47;34m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;36m'
export LESS=-R

# go
if command -v go >/dev/null 2>&1; then
  export GOPATH="$HOME/.local/share/go"                           # Go module cache (writable; ~/go/pkg is root-owned)
  export PATH="$PATH:$(go env GOPATH)/bin"                        # Go executables
  export GOBIN="$(go env GOPATH)/bin"                             # Go-installed binaries (already on PATH above)
fi

