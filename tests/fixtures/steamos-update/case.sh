# A steamos install with the Framework 16 fixes, then a SteamOS update: the update resets /etc except what keep lists
# name, so it moves before/root/etc/dummy.conf into /etc/previous, but the installed files must all survive (the
# second install checks that nothing needed restoring). udev, tmpfiles and orei_switch's files survive through
# dotfiles.conf, and the system units of hdmi_audio_fix and orei_switch and their links through SteamOS's default
# list. gamescope_screenshot's user units and their global enable links in /etc/systemd/user survive
# through dotfiles.conf. See tests/images/steamos/steamos-update.
IMAGE=steamos
ARGS="--variant steamos --link --udev --tmpfiles --hdmi_audio_fix --orei_switch --gamescope_screenshot"
# framework_tool is left out of ROOT_FILES, as a binary too big to commit, so check it survived here instead.
AFTER_INSTALL="sudo steamos-update && test -x /etc/dotfiles/bin/framework_tool"
ROOT_FILES="/etc/atomic-update.conf.d /etc/udev/rules.d /etc/tmpfiles.d /etc/systemd/user /etc/previous /etc/dummy.conf"
ROOT_FILES="$ROOT_FILES /etc/dotfiles/bin/orei-switch /etc/dotfiles/bin/sddm-xsetup /etc/sddm.conf.d"
# Each unit and the link for each target in its WantedBy=, rather than all of /etc/systemd/system, which holds the
# image's own units too.
for target in multi-user suspend hibernate hybrid-sleep suspend-then-hibernate; do
  ROOT_FILES="$ROOT_FILES /etc/systemd/system/$target.target.wants/hdmi-audio-fix.service"
done
ROOT_FILES="$ROOT_FILES /etc/systemd/system/sleep.target.wants/orei-switch.service"
ROOT_FILES="$ROOT_FILES /etc/systemd/system/multi-user.target.wants/orei-switch-boot.service"
ROOT_FILES="$ROOT_FILES /etc/systemd/system/poweroff.target.wants/orei-switch-poweroff.service"
for unit in hdmi-audio-fix orei-switch orei-switch-boot orei-switch-poweroff; do
  ROOT_FILES="$ROOT_FILES /etc/systemd/system/$unit.service"
done
