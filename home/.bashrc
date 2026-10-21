#!/bin/bash
#
# ~/.bashrc
#

# shellcheck source=.config/sh/env.sh
source ~/dotfiles/home/.config/sh/env.sh                             # For shells with no login shell above them
[[ $- != *i* ]] && return                                       # Leave if shell is not interactive

# shellcheck source=.config/sh/aliases.sh
source ~/dotfiles/home/.config/sh/aliases.sh
