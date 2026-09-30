# Environmental Variables
export PATH="$HOME/.local/bin${PATH:+:$PATH}"                   # User executables
export PATH="/usr/bin/vendor_perl${PATH:+:$PATH}"               # Perl executables (e.g. biber)

export PYTHONPATH="$HOME/.local/lib/python3.10/site-packages${PYTHONPATH:+:$PYTHONPATH}"  # Path to user Python modules

export LS_COLORS=$LS_COLORS:ow=0:ex=0                           # Don't change color of directories/files with o+w permissions
export EDITOR=/usr/bin/nvim                                     # Change default editor
export QT_QPA_PLATFORMTHEME=gnome                               # Make QT applications use gnome theme when launched from terminal

# go
if command -v go >/dev/null 2>&1; then
  export GOPATH="$HOME/.local/share/go"                           # Go module cache (writable; ~/go/pkg is root-owned)
  export PATH="$PATH:$(go env GOPATH)/bin"                        # Go executables
  export GOBIN="$(go env GOPATH)/bin"                             # Go-installed binaries (already on PATH above)
fi

