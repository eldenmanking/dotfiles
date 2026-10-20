#
# ~/.zshrc
#

################################################################################
# zsh plugins
################################################################################

# Package list:
#               zsh-autosuggestions
#               zsh-syntax-highlighting
#               zsh-history-substring-search
#               zsh-completions

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

autoload -Uz compinit colors                                    # Autoload these zsh functions when called
compinit -d                                                     # Initialize zsh completion
colors                                                          # Activate color-coding for completion

################################################################################
# Shell config
################################################################################

# global config
source ~/dotfiles/.config/sh/aliases.sh
source ~/dotfiles/.config/sh/env.sh

# zsh config
source ~/dotfiles/.config/zsh/keybindings.zsh
source ~/dotfiles/.config/zsh/settings.zsh


################################################################################
# External packages
################################################################################

# opam configuration
[[ ! -r $HOME/.opam/opam-init/init.zsh ]] || source $HOME/.opam/opam-init/init.zsh  > /dev/null 2> /dev/null

################################################################################
# Starship prompt
################################################################################

eval "$(starship init zsh)"
