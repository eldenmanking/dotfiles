# Framework 16 features

Fixes for the Framework 16 (`@machine framework16`), and one for any laptop (`@machine laptop`). `--all` includes them only on that machine (`--machine framework16`, or `--infer`); see [OS, Profile and Machine](../installation.md#os-profile-and-machine). Their files are copied into `/etc` (with sudo), not linked, since they are read at boot, and named in the SteamOS keep list so updates keep them. [framework16-sleep.md](../framework16-sleep.md) has the sleep battery drain investigation behind some of them.

## Any Linux

### `udev`
Copies the rules in `root/etc/udev/rules.d` into `/etc` (replacing any old symlink), then reloads udev and re-applies the rules to i2c devices: one stops the touchpad waking the laptop, one keeps an eGPU on the expansion bay powered while idle.

### `tmpfiles`
Copies the configs in `root/etc/tmpfiles.d` into `/etc` (replacing any old symlink), then applies them so no reboot is needed.

### `hdmi_audio_fix`
Copies `root/etc/systemd/system/hdmi-audio-fix.service` into `/etc/systemd/system` (with sudo). At boot and after every resume it sets the 780M to the `manual` level and gives its SoC clock a 720 MHz floor (`pp_dpm_socclk` levels 2 to 7), leaving the graphics, memory and fabric clocks free. It retries for up to 30 s while amdgpu still refuses the write at boot, and only matches the 780M's PCI ID, so an eGPU is never touched. At idle `socclk` otherwise drops to 400 MHz and HDMI audio stutters; games aren't capped (PipeWire buffer settings don't help: it reports no underruns); `--uninstall` removes it and sets the level back to `auto`.

### `logind`
For any laptop (`@machine laptop`). Copies `root/etc/systemd/logind.conf.d/lid.conf` into `/etc` (with sudo) so that closing the lid on external power doesn't suspend: logind only counts the laptop as docked while an external display is in use, so a lid closed all session otherwise suspends it in the gaps, like between the login screen and Gaming Mode or after gamescope crashes, and an eGPU doesn't come back from that.

## SteamOS

### `orei_switch`
Makes an OREI HDMI switch hand over to another input while the laptop sleeps; see [orei-switch.md](../orei-switch.md).

### `light_sleep`
Keeps an eGPU on the expansion bay working across sleep: the bay's PCIe link drops whenever the laptop reaches hardware sleep, and an eGPU with its own power supply never comes back, so while one is attached a suspend idles with the displays off instead; see [light-sleep.md](../light-sleep.md).

### `quiet_slow_charger`
Stops Steam's Slow Charger dialog, which opens whenever a charger can't keep up with the laptop (vpower writes `Connected slow` to `/run/vpower/ac_status`, and nothing in Steam turns the dialog off): a drop-in for SteamOS's `vpower.service` makes vpower write its state into `/run/vpower-raw` (a bind mount in its own namespace; the rest of the unit is left as SteamOS ships it), and `vpower-filter.service`, started and stopped with vpower, copies it to `/run/vpower` with `Connected slow` changed to `Connected`. Battery percentage, low-battery warnings and vpower's shutdown request pass through unchanged.

### `charge_limit`
Lets Steam's battery charge limit setting work there. Steam keeps the setting itself (`ChargeLimitEnabled` and `ChargeLimit` in `~/.local/share/Steam/config/config.vdf`) and applies it through steamos-manager whenever it starts; the feature only gives steamos-manager a limit to set, with three files and nothing that runs. `/etc/modprobe.d/framework-charge-control.conf` loads `cros_charge_control` with `probe_with_fwk_charge_control=1` (the kernel otherwise refuses it on Framework laptops, leaving the BIOS limit, 80% by default, which Linux can't see), and `usr-share-steamos\x2dmanager-devices.mount` lays `/etc/dotfiles/steamos-manager/devices`, with a Framework 16 device file, over the read-only `/usr/share/steamos-manager/devices` (an overlay, read-only too), the only place steamos-manager looks for device files. It also turns Steam's limit on at 80%, the BIOS default, in `config.vdf`, which it can only edit while Steam is closed (Steam rewrites it on exit; the `steam` feature's helpers in `install/lib/steam.sh` do both). Loading the module resets the limit to 100% until Steam next starts, so the first install takes effect after a reboot. Turning the limit off in Steam then means no limit at all, not the BIOS one.
