# Light sleep with an eGPU (Framework 16)
The `light_sleep` feature (part of `./install.sh --variant steamos --machine framework16 --all`, or alone with
`--light_sleep`) keeps an eGPU on the Framework 16 expansion bay working across sleep. While a live one is attached,
a suspend idles with the displays off instead, and anything else suspends as before. It installs
`/etc/dotfiles/bin/light-sleep`, its helper `light-sleep-helper` and a `systemd-suspend.service` drop-in that runs
`light-sleep suspend` in place of `systemd-sleep suspend`, plus a SteamOS keep list entry for the scripts.

## Setup
- Framework 16 (AMD 7040, BIOS 04.04) on SteamOS, with the dual M.2 interposer in the expansion bay
  (`framework_tool --expansion-bay`: `DualInterposer`, `Pcie4x2`).
- An RX 9070 in a dock with its own power supply, on an M.2 OCuLink adapter. It sits behind the card's own PCIe switch
  (`01:00.0`, `02:00.0`, AMD IDs `1478`/`1479`) on root port `00:01.5` (ACPI `GPP4`), at 16 GT/s x2 or 8 GT/s x4.

## Problem
Every suspend loses the eGPU. On resume the switch, the GPU and its audio report
`Unable to change power state from D3hot to D0, device inaccessible`, amdgpu then fails with
`resume of IP block <gfx_v12_0> failed -110`, the card's config space reads all ones (`ffffffff`), and only a reboot
brings it back. Gaming Mode suspends through `dbus-send` to logind (the power button or Steam's sleep menu), so
`lid.conf` (the `logind` feature) doesn't help.

## Findings
- Every one of 8 suspends failed, including 11 and 14 s ones. Runtime power-off of the idle card (BOCO or BACO) came
  back almost every time; once (a single boot) it didn't, see below.
- These made no difference: keeping the left PD controller on (`orei-switch.service` disabled), `d3cold_allowed=0` on
  the root port, a cold power cycle of the dock, and `d3cold_allowed=0` on `03:00.0` and `03:00.1`, which keeps the
  root port and both switch ports in D0 into the suspend (setting it on the root port itself doesn't: the kernel only
  applies it to a device's upstream bridges).
- The EC keeps every bay rail on in s2idle: in Framework's EC source (`zephyr/program/framework/lotus/src/
  gpu_configuration.c`, `set_gpu_gpios_powerstate`) S0ix ranks above S0, and rails only drop in S3 and S5.
  `framework_tool` has no expansion bay power control, and `GPP4` has no ACPI power resource.
- The SoC reaches hardware sleep (`/sys/power/suspend_stats/last_hw_sleep` is nonzero), and in S0i3 the platform
  drops the bay's PCIe link whatever state Linux left the devices in. A GPU powered by the laptop would start over on
  wake; this one keeps its own power and never gets the reset (PERST#) a new link needs. Nothing from software brings
  it back afterwards: a link retrain, a secondary bus reset and a link disable and re-enable on the root port all
  leave the link training with nothing answering.
- Linux has no way to keep s2idle out of S0i3, and the laptop offers no other sleep state (`/sys/power/mem_sleep`:
  `[s2idle]`).
- The idle card was also lost without any suspend, three times: amdgpu powers it off while idle (BACO), which also
  lets the root port and the card's switch drop to D3hot, and the next wake failed with `device lost from bus!` or
  `rlc autoload: gc ucode autoload timeout`, then a gfx or SMU resume error (`-110`, `-62`). Gaming Mode then stays
  blank until a cold boot. It matches AMD's own fix for Navi 3x laptops that use BACO while the root port powers down
  (kernel commit 134b8c5d, "Fix detection of _PR3 on the PCIe root port"), which doesn't cover an eGPU on an M.2 slot.
  `root/etc/udev/rules.d/90-egpu-no-runpm.rules` (the `udev` feature) sets `power/control` to `on` for an amdgpu card
  below `00:01.5` as soon as it binds, so the card and the bridges above it stay powered; with it, the card came
  through all of the light sleep tests below. The card draws its idle power from the dock's supply instead.

## What light-sleep does
- **No live eGPU** (no display controller below `00:01.5`, or one whose config space reads `ffff`): runs
  `systemd-sleep suspend`, as without the drop-in.
- **Sleep:** switches to the empty VT 8, so logind takes DRM master from gamescope and gamescope stops drawing.
  Gamescope turns its outputs off itself on logind's `PrepareForSleep`, so in practice nothing is lit by then (the
  helper logs `turned off: nothing`). As a fallback for anything still lit, the helper opens each DRM card as master
  and sets every lit connector's DPMS property to off, noting which in `/run/light-sleep/dpms`: forcing a connector's
  sysfs status off doesn't make gamescope let go, and the framebuffer console doesn't take the CRTCs over on the VT
  switch (even with `setterm --powersave powerdown --blank force`). Then it freezes `user.slice`, as `systemd-sleep`
  does, and waits.
- **Wake:** on a key press on a keyboard, gamepad or power button (grabbed, so the press reaches nothing else), or the
  lid opening. Then it thaws `user.slice`, turns those connectors back on and switches back to the session's VT, where
  gamescope takes the displays again.
- logind, Steam and the units on `sleep.target` (such as `orei-switch.service`) see an ordinary suspend: logind still
  sends `PrepareForSleep`, and the sleep only ends when `systemd-suspend.service` does. The hooks in
  `/usr/lib/systemd/system-sleep` are skipped: SteamOS's only act on hibernate or with a flag file.
- The laptop draws idle power, not sleep power, while the eGPU is attached, including on battery.

## Tested
With `90-egpu-no-runpm.rules` in place and `orei-switch.service` enabled, these all passed: a 60 s, an 8 s and a
150 s sleep, a key pressed 1 s in (while orei-switch is still handing over; that press doesn't count, the next one
wakes it), a second suspend 5 s after a wake (while orei-switch's wake step is still running), and a sleep with the
projector already in standby. After each, amdgpu's test job passed on every ring and the projector was back on.

A `systemctl suspend` (the same logind request Steam sends) with amdgpu driving the eGPU took the light sleep path,
never reached hardware sleep (`last_hw_sleep` 0), woke on a key press, and Steam and gamescope logged a normal suspend
and resume. Before and after, the link answered, amdgpu was bound and `amdgpu_test_ib` (debugfs, as root) passed on
every ring. The config space read alone isn't proof the card works: after a warm reboot amdgpu can fail to start it
(`discovery failed: -2`) with the link up, which a dock power cycle with the laptop off fixes.

Check with `journalctl -t light-sleep -b` and `journalctl -u systemd-suspend -b` (the helper's output).
