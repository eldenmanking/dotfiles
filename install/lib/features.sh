# Feature and variant registry helpers.

feature_description() {
  case "$1" in
    all)         echo "install all options" ;;
    pacman)      echo "install pacman packages" ;;
    yay)         echo "install yay packages" ;;
    terminal)    echo "install terminal packages" ;;
    font)        echo "install jetbrains mono font" ;;
    printer)     echo "install and set up HP printer drivers" ;;
    logiops)     echo "install and configure logitech software" ;;
    link)        echo "symlink the variant's dotfiles into ~ (root/ into /)" ;;
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
    gng)         echo "install gng (Gradle wrapper) to ~/.local" ;;
    tre)         echo "build and install tre (tree alternative) from source" ;;
    claude)      echo "configure CLAUDE.md, hooks, scripts, and commands" ;;
    gitconfig)   echo "set up default global git config" ;;
    steamos_xclip) echo "install xclip to ~/.local/bin by copying it out of a temporary arch distrobox" ;;
    *)           echo "" ;;
  esac
}

# Features that honor --dry-run; others are only announced.
DRY_RUN_FEATURES=" pacman yay terminal font printer logiops link services manual tmux gitconfig dconf xdg info steamos_xclip "

feature_function() {
  printf 'feature_%s' "${1//-/_}"
}

# Return 0 if a variant_<name> function is defined.
variant_exists() {
  [[ -n "$1" ]] && declare -F "variant_$1" >/dev/null
}

# Call variant_<name>, which sets the variant's _* config outputs.
variant_config() {
  variant_exists "$1" || error "Unknown variant '$1'"
  "variant_$1"
}
