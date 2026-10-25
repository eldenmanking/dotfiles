# --steam on a home where Steam already wrote a user's localconfig.vdf: the main menu and quick access hotkeys in its
# Gamescope section are replaced, every other line is kept, and the original is backed up to ~/dotfiles/.backup.
IMAGE=steamos
ARGS="--variant steamos --steam"
FILES=".local/share/Steam"
