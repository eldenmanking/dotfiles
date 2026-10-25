# A steamos install on a home with Arch's default .bashrc and .bash_profile (which SteamOS ships too) and the user's
# own .zshrc: --link moves them into ~/dotfiles/.backup and links the repo's startup files, and --starship leaves the
# linked .bashrc and .zshrc alone. Runs every feature that works in a container; the rest (flatpak, font, webterm,
# distrobox, steamos_xclip) need a real SteamOS desktop or a download, steamos-update covers udev and tmpfiles, and
# steamos-steam covers steam.
# None of them touch the startup files.
IMAGE=steamos
ARGS="--variant steamos --link --neovim --starship --tmux --claude --gitconfig --kde --home_units"
FILES="$FILES .config/webterm"
