# OREI HDMI switch handoff (Framework 16)
The `orei_switch` feature (`./install.sh --variant steamos --orei_switch`) makes an OREI 4K 3-input HDMI switch (auto
mode) follow a Framework 16's sleep and wake. It installs `/etc/orei-switch/orei-switch.sh`, a pinned
`framework_tool` (Framework's EC tool) beside it, `orei-switch.service` (enabled, wanted by `sleep.target`) and a SteamOS
keep list for `/etc/orei-switch`, without which an OS update deletes the script and binary.

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

The script does the PD disable on sleep, and on wake re-enables it, falling back to the two UCSI resets if no external
display is connected after 10s.

## Operating
- Logs: `journalctl -t orei-switch -b`
- Recovery, if the left ports stay dead: `sudo /etc/orei-switch/framework_tool --pd-enable 1` (or reboot)
- Remove: `./install.sh --variant steamos --orei_switch --uninstall`

## Open questions
- Verify with a real suspend/resume (only tested by hand while awake so far).
- Boot: maybe run the wake logic at boot too. The projector shows a blank screen on boot if connected, and the
  encrypted home needs a desktop-mode login first.
- Accidental wakes grab the projector; consider guarding against that.
