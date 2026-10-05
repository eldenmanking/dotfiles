# TODO(andywang): add comment
VARIANT_DESCRIPTION="Arch Linux (or Arch-based) desktop with pacman/yay packages, gnome and dconf"
VARIANT_FEATURES="pacman yay terminal font printer logiops link services manual tmux gitconfig dconf xdg info"
VARIANT_ALL_EXCLUDE="terminal"
LINK_INCLUDE_PATHS=("${LINK_COMMON_PATHS[@]}" "${LINK_DESKTOP_PATHS[@]}")

# 'terminal' is intentionally left skipped: pacman + yay together cover
# all packages the --terminal flag would install.

TERMINAL_YAY=()

# Pacman package list
TERMINAL_PACMAN=(
  "wmctrl"                                                      # CLI interface for X window manager
  "zsh"                                                         # zshell essentials
  "zsh-autosuggestions"                                         # .
  "zsh-syntax-highlighting"                                     # .
  "zsh-history-substring-search"                                # .
  "zsh-completions"                                             # .
  "tmux"                                                        # terminal multiplexer
  "git"                                                         # install.sh
  "git-lfs"                                                     # handling large files in git
  "gradle"                                                      # Gradle build tool
  "make"                                                        # standard build tool
  "python"                                                      # Python
  "npm"                                                         # Javascript package manager
  "cargo"                                                       # Rust package manager
  "neovim"                                                      # text editor
  "yarn"                                                        # markdown-preview dependency
  "noto-fonts"                                                  # special fonts
  "noto-fonts-cjk"                                              # .
  "noto-fonts-emoji"                                            # .
  "noto-fonts-extra"                                            # .
  "tree"                                                        # show directory contents in tree form
  "cmus"                                                        # Music player
  "locate"                                                      # locate files
  "xclip"                                                       # system clipboard tool
  "man"                                                         # manual
  "man-pages"                                                   # manual database
  "acpi"                                                        # battery status and acpi information
)

GNOME_PACMAN=(
  "gnome-shell"                                                 # gnome desktop environment
  "gnome-terminal"                                              # gnome default terminal
  "gdm"                                                         # gnome display manager
  "gnome-tweaks"                                                # more settings
  "gnome-control-center"                                        # settings
  "gparted"                                                     # disk partition editor
  "baobab"                                                      # disk usage analyzer
  "gnome-disk-utility"                                          # disk manager
  "dconf-editor"                                                # gnome settings editor
  "seahorse"                                                    # keyring manager
  "papirus-icon-theme"                                          # nice app icon theme
  "nautilus"                                                    # gui file explorer
  "xdg-user-dirs-gtk"                                           # Manages "well-known" user directories (e.g. Documents, Videos, etc.)
  "okular"                                                      # PDF viewer
  "gnome-system-monitor"                                        # system monitor
  "fragments"                                                   # torrent downloader
  "gthumb"                                                      # image viewer
  "gnome-screenshot"                                            # screenshot tool
  "gst-plugin-pipewire"                                         # gnome screencast dependency
  "obs-studio"                                                  # Sophisticated recorder/streamer
  "xdg-desktop-portal"                                          # Enables pipewire to provide video capture (for obs)
  "xdg-desktop-portal-gnome"                                    # xdg-desktop-portal backend for gnome
  "totem"                                                       # video player (installs gst-plugins-good)
  "gst-libav"                                                   # required multimedia framework for totem
  "kid3"                                                        # audio metadata editor
  "bluez-utils"                                                 # bluetooth support
  "discord"                                                     # social media
  "solaar"                                                      # logitech pairing software
  "obsidian"                                                    # markdown note taker
)

LATEX_PACMAN=(
  "texlive-binextra"                                            # get latexmk
  "biber"                                                       # enable biber for latexmk
  "perl-clone"                                                  # fix missing dependency for biber (08-05-2022)
  "cpanminus"                                                   # install cpan modules more easily
)

# (hp) printer package list
PRINTER_PACMAN=(
  "cups"                                                        # standard printing system
  "system-config-printer"                                       # GUI printer configuration
  "hplip"                                                       # hp printer driver installer
)

GNOME_YAY=(
  "adw-gtk-theme"                                               # dark gtk theme
  "xcursor-breeze"                                              # cursor theme
  "insync"                                                      # drive sync
  "google-chrome"                                               # web browser
  "zoom"                                                        # video conferencing platform
)
