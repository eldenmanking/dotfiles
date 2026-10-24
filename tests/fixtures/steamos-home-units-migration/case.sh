# --home_units on a deck set up by older versions: home-units.service is installed and up to date, but kept by the
# keep list this feature used to install as dotfiles.conf, and the standalone steamos-config repo's files are still
# there. One run replaces dotfiles.conf with the dotfiles-home_units.conf that keep_across_steamos_updates writes and
# removes the old files, and a SteamOS update afterwards keeps everything installed.
IMAGE=steamos
ARGS="--variant steamos --home_units"
AFTER_INSTALL="sudo steamos-update"
FILES=""
ROOT_FILES="/etc/atomic-update.conf.d /etc/systemd/user /etc/dotfiles /etc/steamos-config /etc/previous"
