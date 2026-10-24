# An arch install on a home with Arch's default .bashrc and .bash_profile and the user's own .zshrc: --link moves them
# into ~/dotfiles/.backup and links the repo's startup files in their place. Runs every --all feature that works in a
# container; the rest (pacman, yay, font, logiops, services, manual, dconf, xdg) need a real Arch desktop and leave
# the startup files alone.
IMAGE=arch
ARGS="--variant arch --link --tmux --claude --gitconfig --info"
