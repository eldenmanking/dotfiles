# A steamos install with the Framework 16 fixes, then a SteamOS update: the update resets /etc except what keep lists
# name, so it moves before/root/etc/dummy.conf into /etc/previous, but the installed files must all survive (the
# second install checks that nothing needed restoring). udev, tmpfiles, logind and orei_switch's files survive through
# dotfiles.conf, and the system units of hdmi_audio_fix and orei_switch and their links through SteamOS's default
# list. gamescope_screenshot's user units and their global enable links in /etc/systemd/user survive
# through dotfiles.conf. light_sleep's script survives through dotfiles.conf, and its systemd-suspend drop-in through
# SteamOS's default list. tailscale's binaries and /etc/default/tailscaled survive through dotfiles.conf, and tailscaled.service, its
# drop-in and its link through SteamOS's default list. webterm is left out: it needs a systemd user session and downloads ttyd, which this
# container has neither of. See tests/images/steamos/steamos-update.
IMAGE=steamos
ARGS="--variant steamos --machine framework16 --link --udev --tmpfiles --logind --hdmi_audio_fix --orei_switch --light_sleep --gamescope_screenshot --tailscale"
# framework_tool and the Tailscale binaries are left out of ROOT_FILES, as binaries too big to commit, so check they
# survived here instead.
AFTER_INSTALL="sudo steamos-update && test -x /etc/dotfiles/bin/framework_tool"
AFTER_INSTALL="$AFTER_INSTALL && test -x /etc/dotfiles/bin/tailscale && test -x /etc/dotfiles/bin/tailscaled"
ROOT_FILES="/etc/atomic-update.conf.d /etc/udev/rules.d /etc/tmpfiles.d /etc/systemd/logind.conf.d /etc/systemd/user /etc/previous /etc/dummy.conf"
ROOT_FILES="$ROOT_FILES /etc/dotfiles/bin/orei-switch /etc/dotfiles/bin/sddm-xsetup /etc/dotfiles/bin/sddm-xstop /etc/sddm.conf.d"
ROOT_FILES="$ROOT_FILES /etc/dotfiles/bin/light-sleep /etc/systemd/system/systemd-suspend.service.d"
# Each unit and the link for each target in its WantedBy=, rather than all of /etc/systemd/system, which holds the
# image's own units too.
for target in multi-user suspend hibernate hybrid-sleep suspend-then-hibernate; do
  ROOT_FILES="$ROOT_FILES /etc/systemd/system/$target.target.wants/hdmi-audio-fix.service"
done
ROOT_FILES="$ROOT_FILES /etc/systemd/system/sleep.target.wants/orei-switch.service"
ROOT_FILES="$ROOT_FILES /etc/systemd/system/multi-user.target.wants/tailscaled.service"
ROOT_FILES="$ROOT_FILES /etc/systemd/system/tailscaled.service.d /etc/default/tailscaled"
ROOT_FILES="$ROOT_FILES /etc/systemd/system/multi-user.target.wants/orei-switch-boot.service"
ROOT_FILES="$ROOT_FILES /etc/systemd/system/poweroff.target.wants/orei-switch-poweroff.service"
for unit in hdmi-audio-fix orei-switch orei-switch-boot orei-switch-poweroff tailscaled; do
  ROOT_FILES="$ROOT_FILES /etc/systemd/system/$unit.service"
done
