# TODO(andywang): add comment

feature_description() {
  case "$1" in
    all)         echo "install all options" ;;
    pacman)      echo "install pacman packages" ;;
    yay)         echo "install yay packages" ;;
    terminal)    echo "install terminal packages" ;;
    font)        echo "install jetbrains mono font" ;;
    printer)     echo "install and set up HP printer drivers" ;;
    logiops)     echo "install and configure logitech software" ;;
    link)        echo "create dotfile links" ;;
    services)    echo "enable and start custom services" ;;
    manual)      echo "make manual substitutions to files in-place" ;;
    dconf)       echo "load dconf configuration" ;;
    xdg)         echo "load default xdg configuration" ;;
    info)        echo "provide info on manual configuration tasks" ;;
    shell)       echo "configure shell keybindings (source aliases in shell rc)" ;;
    starship)    echo "install starship and add its init line to the shell rc" ;;
    zsh)         echo "clone zsh plugins into ~/.zsh and source them in .zshrc" ;;
    tmux)        echo "install tmux plugin manager and plugins" ;;
    binaries)    echo "install neovim and tmux to ~/.local/bin from GitHub" ;;
    link-config) echo "symlink neovim and tmux configs into ~" ;;
    link-bin)    echo "symlink executables into $LOCAL_BIN" ;;
    gng)         echo "install gng (Gradle wrapper) to ~/.local" ;;
    tre)         echo "build and install tre (tree alternative) from source" ;;
    claude)      echo "configure CLAUDE.md, hooks, scripts, and commands" ;;
    gitconfig)   echo "set up default global git config" ;;
    *)           echo "" ;;
  esac
}

# TODO(andywang): add comment
DRY_RUN_FEATURES=" pacman yay terminal font printer logiops link link-config link-bin services manual tmux gitconfig dconf xdg info "

feature_supports_dry_run() {
  case "$DRY_RUN_FEATURES" in
    *" $1 "*) return 0 ;;
    *)        return 1 ;;
  esac
}

feature_function() {
  printf 'feature_%s' "${1//-/_}"
}
