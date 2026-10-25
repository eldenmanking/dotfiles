# OREI HDMI switch handoff (Framework 16)
The `orei_switch` feature (part of `./install.sh --variant steamos --all`, or alone with `--orei_switch`) makes an OREI
4K 3-input HDMI switch (auto mode) follow a Framework 16's sleep and wake, and turns the projector off on sleep and
poweroff and back on on wake. It installs `/etc/dotfiles/orei-switch/orei-switch.sh`, a pinned `framework_tool` (Framework's EC tool) beside it,
`orei-switch.service` (enabled, wanted by `sleep.target`), `orei-switch-poweroff.service` (wanted by `poweroff.target`,
so not on reboot) and a SteamOS keep list for `/etc/dotfiles/orei-switch`, without which an OS update deletes the
script and binary.

## Setup
- Framework 16 (AMD iGPU) on SteamOS. HDMI expansion card on USB-C port 2 (left), the DRM connector `card0-DP-4` and
  `/dev/cec0`, into OREI input 1. A Nintendo Switch is on input 2 and an Apple TV on input 3, and the OREI feeds a projector.
- Gamescope drives one display: with the external display connected, the laptop screen is blank.

## Problem
1. Waking or booting the laptop doesn't make the OREI switch to it: the laptop shows on its own screen and DP-4 reports
   disconnected. The OREI apparently only presents HPD/EDID on the selected input, so the laptop never sees a display.
2. While the laptop sleeps, turning on the Apple TV doesn't take the OREI away from it (the Nintendo Switch does).

## Findings
- The OREI ignores CEC entirely (Active Source, Set Stream Path and Image View On from either device do nothing).
- It switches on a fresh HDMI +5V edge (a new source arriving), and falls back to another live input only when the
  current input's 5V stays gone. The Apple TV keeps 5V on in standby, so it never makes an edge.
- These did not keep 5V off: forcing `/sys/class/drm/card0-DP-4/status` off/on; toggling
  `/sys/class/typec/port2/port2.0/active` (DP alt mode); a single UCSI connector reset (the blip is too short and the
  controller re-enters DP mode within seconds).
- A UCSI connector reset works as a software replug for wake:
  `echo 0x30003 > /sys/kernel/debug/usb/ucsi/USBC000:00/command` (connector 3 = typec port 2 + 1). It takes two resets
  ~10s apart: the first makes the OREI switch, the second gives a clean hotplug so video comes up.
- `framework_tool --pd-disable 1` cuts power to the whole left PD controller (ports 2 and 3), which lets the Apple TV take
  over; `--pd-enable 1` restores it, and the fresh edge switches the OREI back with a picture. Granularity is left
  (PD 1) and right (PD 0) only, so **a charger on port 3 is cut during sleep: keep it on the right side** (check with
  `framework_tool --pdports`).

- The projector (a Nebula Cosmos, CEC vendor ID `mtk`) is reachable over CEC through the OREI as the TV (0.0.0.0), and
  the Apple TV answers as Playback Device 1 (1.2.0.0) with its power state. The projector acknowledges `<Standby>`, sent
  to it or broadcast, even after an `<Active Source>`, but ignores it. It does turn off on the remote's Power Off key:
  `cec-ctl -D amdgpu --to 0 --user-control-pressed ui-cmd=power-off-function`, then `--user-control-released`.
- The kernel re-registers the CEC adapter on each resume, alternating between `/dev/cec0` and `/dev/cec1`, so the
  script finds it by driver (`cec-ctl -D amdgpu`). SteamOS's `cecd` configures it (OSD name `steamdeck`).
- The laptop's CEC adapter needs HPD, so it can only talk on the bus while the OREI shows the laptop, and not at all
  while it sleeps. It can't watch for another device turning on during sleep.

- The projector reports its power state over CEC, and the display stays connected for a while after it goes to standby
  (the OREI keeps HPD up), so the laptop can wake it with `<Image View On>`. After roughly 30s in standby, HPD drops.
- An ordinary monitor doesn't answer CEC at logical address 0. Behind the OREI, the laptop's physical address is
  `1.1.0.0` (two levels deep); plugged straight into a TV it would be `1.0.0.0`.
- While asleep the laptop can't react to anything on the ports: Type-C events arrive through the EC, whose wakeups are
  disabled (`root/etc/tmpfiles.d/ec-no-wakeup.conf`), and a wake would be a full resume anyway.

## What the script does
It only touches a CEC TV, so sleeping away from the projector or on a plain monitor changes nothing.

- **Sleep:** if the external display answers as a CEC TV, press its Power Off key (CEC only works while the OREI shows
  the laptop, so it never turns off another input's picture) and mark `/run/orei-switch/projector-off`. If the laptop is
  also behind a switch, disable the PD controller.
- **Wake:** if `framework_tool --pd-info` shows the left controller's ports disabled (by sleep, or by anything else),
  re-enable them and wait up to 15s for the display (polling `/sys/class/drm/card*-DP-*/status`), otherwise do up to two
  UCSI resets, each followed by a 6s wait. If the projector was turned off, or the ports were re-enabled (which makes
  the OREI switch to the laptop), wake it with `<Image View On>` and check its power state every 3s, resending until it reports on, for
  up to 60s, in case it is still shutting down. SteamOS's `cecd` also tries to wake the TV on resume, but this projector
  doesn't respond to it. CEC calls first wait for `cecd` to claim a logical address after resume.
- **Boot:** before the login screen starts (`Before=display-manager.service`), if the ports are disabled (the laptop
  died or was forced off while asleep; the EC keeps the setting), re-enable them and wait for the display, so the login
  screen sees the projector. Then, in a background transient unit (`orei-switch-boot-tv`), turn a connected CEC TV on as
  on wake. Before login `cecd` isn't running, so the script claims a CEC address itself. Everything it needs is in
  `/etc`, so the locked home doesn't matter.
- **Poweroff:** if a CEC TV is connected, turn it off.
- **Login screen:** a dirlock-encrypted home can't be unlocked by autologin, so every boot stops at SDDM's X11 login
  screen (its Wayland one needs `weston`, which SteamOS lacks). With the projector connected, X11's default layout put
  the panel and projector side by side, which left the panel black and the projector without a signal.
  `/etc/sddm.conf.d/orei-switch.conf` replaces SteamOS's setup command (`holo-rotate-x11-screen`, which it still runs)
  with `sddm-xsetup`. With the lid closed (`/proc/acpi/button/lid/*/state`) it turns the panel off, so the login screen
  fills the external display at its own mode. With the lid open it mirrors the panel onto it, stretched to fit: the
  panel only offers its native 16:10 2560x1600, so a 16:9 display squashes it by about 10%. Letterboxing the mirror
  with an xrandr transform instead left the login screen in the top left corner of the projector. A background copy
  of the script checks the lid and the DRM connectors every second while the login screen is up, and lays the displays
  out again when they change (e.g. unplugging the projector and opening the lid); it exits with the X server on login.

It logs each step; tune `PD_WAIT` and `RESET_WAIT` from the timings (`journalctl -t orei-switch -b -o short-precise`).
In 15 real suspend/resumes (RTC wakes after 12s to 5 min, the projector on, already in standby, or the ports cut
before sleep) the display connected 2.5–9.5s after the PD enable and the projector reported on 9–19s after resume. In
2 of them the connector came up "connected" without an EDID (kernel `No EDID read`): no CEC adapter, and gamescope
fell back to 640x480. A UCSI reset fixes that, so the wait treats it as not connected and moves on to the reset after
3s.

Known gaps:
- Connecting to the OREI while the laptop sleeps makes the OREI switch to the sleeping laptop (its card is powered), and
  nothing can hand it back until the laptop wakes. Use the OREI remote, or wake and sleep the laptop again.
- If the projector has been in standby long enough to drop HPD (e.g. turned off with its own remote), a sleep finds no
  TV and leaves the ports on, so another source can't take over. Use the OREI remote.

## Operating
- Logs: `journalctl -t orei-switch -b`
- Recovery, if the left ports stay dead: `sudo /etc/dotfiles/orei-switch/framework_tool --pd-enable 1` (or reboot)
- Remove: `./install.sh --variant steamos --orei_switch --uninstall`

## Open questions
- Verify a real poweroff and boot, the UCSI reset fallback on wake, and turning on a projector that is still shutting
  down. (Suspend/resume, including turning the projector off and on, works.) Accidental wakes turning the projector on
  are fine.
- Boot login screen: verify the mirroring with the projector connected (`journalctl -t orei-switch -b` shows what X11
  saw and did).
