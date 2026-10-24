# A steamos install with the Framework 16 fixes, then a SteamOS update: the update resets /etc except what keep lists
# name, so it moves before/root/etc/dummy.conf into /etc/previous, but the installed files must all survive (the
# second install checks that nothing needed restoring). udev and tmpfiles survive through dotfiles.conf, and
# hdmi_audio_fix's system unit and its links through SteamOS's default list. The image's dirlock reports an
# encrypted home, so home_units installs too. See tests/images/steamos/steamos-update.
IMAGE=steamos
ARGS="--variant steamos --link --udev --tmpfiles --home_units --hdmi_audio_fix"
AFTER_INSTALL="sudo steamos-update"
ROOT_FILES="/etc/atomic-update.conf.d /etc/udev/rules.d /etc/tmpfiles.d /etc/systemd/user /etc/dotfiles /etc/previous"
ROOT_FILES="$ROOT_FILES /etc/dummy.conf"
# The unit and the link for each target in its WantedBy=, rather than all of /etc/systemd/system, which holds the
# image's own units too.
for target in multi-user suspend hibernate hybrid-sleep suspend-then-hibernate; do
  ROOT_FILES="$ROOT_FILES /etc/systemd/system/$target.target.wants/hdmi-audio-fix.service"
done
ROOT_FILES="$ROOT_FILES /etc/systemd/system/hdmi-audio-fix.service"
