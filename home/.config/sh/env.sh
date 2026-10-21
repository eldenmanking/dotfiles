# Environment variables. Sourced from login profiles and rc files, so it must be POSIX sh and safe to source more
# than once.

# Add a directory to the front or back of PATH unless it is already there.
path_prepend() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1${PATH:+:$PATH}" ;; esac; }
path_append() { case ":$PATH:" in *":$1:"*) ;; *) PATH="${PATH:+$PATH:}$1" ;; esac; }

path_prepend "$HOME/.local/bin"                                 # User executables
path_prepend /usr/bin/vendor_perl                               # Perl executables (e.g. biber)
export PATH

# Don't change color of directories/files with o+w permissions
case ":${LS_COLORS:-}:" in
  *":ow=0:ex=0:"*) ;;
  *) export LS_COLORS="${LS_COLORS:-}:ow=0:ex=0" ;;
esac
export EDITOR=/usr/bin/nvim                                     # Change default editor
export QT_QPA_PLATFORMTHEME=gnome                               # Make QT applications use gnome theme when launched from terminal

# Color man pages
esc="$(printf '\033')"
export LESS_TERMCAP_mb="${esc}[01;32m"
export LESS_TERMCAP_md="${esc}[01;32m"
export LESS_TERMCAP_me="${esc}[0m"
export LESS_TERMCAP_se="${esc}[0m"
export LESS_TERMCAP_so="${esc}[01;47;34m"
export LESS_TERMCAP_ue="${esc}[0m"
export LESS_TERMCAP_us="${esc}[01;36m"
export LESS=-R
unset esc

# go
if command -v go >/dev/null 2>&1; then
  export GOPATH="$HOME/.local/share/go"                           # Go module cache (writable; ~/go/pkg is root-owned)
  path_append "$(go env GOPATH)/bin"                              # Go executables
  export GOBIN="$(go env GOPATH)/bin"                             # Go-installed binaries (already on PATH above)
fi

unset -f path_prepend path_append
