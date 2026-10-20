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

################################################################################
# Shell config
################################################################################

# global config
source ~/dotfiles/.config/sh/aliases.sh
source ~/dotfiles/.config/sh/env.sh

# zsh config
source ~/dotfiles/.config/zsh/keybindings.zsh
source ~/dotfiles/.config/zsh/settings.zsh
source ~/dotfiles/.config/zsh/external.zsh

################################################################################
# Starship prompt
################################################################################

eval "$(starship init zsh)"
