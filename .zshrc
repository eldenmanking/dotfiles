#
# ~/.zshrc
#

typeset -U path                                                 # Remove duplicates in path/PATH

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

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

################################################################################
# Shell config
################################################################################

# zsh common
export HISTFILE=~/.zhistory
export HISTSIZE=10000
export SAVEHIST=10000
export WORDCHARS=${WORDCHARS//\/[&.;]}                          # Don't consider certain characters as words
export ZLE_RPROMPT_INDENT=0                                     # No space after right prompt

# Color man pages
export LESS_TERMCAP_mb=$'\E[01;32m'
export LESS_TERMCAP_md=$'\E[01;32m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;47;34m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;36m'
export LESS=-R

# Aliases
source ~/dotfiles/.config/sh/aliases.sh

# zsh config
source ~/dotfiles/.config/zsh/keybindings.zsh


################################################################################
# External packages
################################################################################

# opam configuration
[[ ! -r /home/linstar/.opam/opam-init/init.zsh ]] || source /home/linstar/.opam/opam-init/init.zsh  > /dev/null 2> /dev/null

################################################################################
# Starship prompt
################################################################################

eval "$(starship init zsh)"
