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

source ~/dotfiles/.config/zsh/plugins.zsh

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

source ~/dotfiles/.config/sh/starship.sh
