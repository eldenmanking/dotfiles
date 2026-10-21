# Framework 16 / SteamOS: sleep battery drain

## Diagnosis
- Deep sleep (s2idle) works. A ~27s suspend reached ~25.2s of hardware sleep, and amd_pmc/amd_pmf are loaded.
- The problem is repeated waking. The journal showed a loop: sleep 9-56s, wake, stay awake exactly 25s, re-suspend (12 cycles in 10 min). The laptop was awake about half the time.
- Wake source: IRQ 7 (pinctrl_amd, GPIO). Nearly all GPIO interrupts come from the touchpad, `PIXA3854:00` (146,342 of 146,451), and it was the only I2C device with wake enabled.
- Ruled out: Bluetooth (wake event 0x0), lid, power button, removed dGPU, GPU perf override (now `auto`), NVMe APST, battery health (89%, 127 cycles).
- Possible secondary issue: the touchpad's I2C controller (AMDI0010:03) logged ~4.6M interrupts in ~80 min while idle. The pad may be reporting noise, so try cleaning it or reseating the module if wakes continue.

## Fix 1 (disable I2C wake)
> **Possibly redundant, candidate for removal.** The wake blamed on the touchpad (IRQ 7, GPIO) may really have been embedded controller wakes delivered through a GPIO pin, which [Fix 2](#fix-2-disable-embedded-controller-wake) now stops. Keep this rule until a sleep test with it removed (see [Undo fix 1](#undo-fix-1)) confirms sleep stays fixed, then delete it.

The rule disables wake for every I2C device that has it enabled. On this laptop that is only the touchpad: the built-in and external keyboards are USB, so they are unaffected.

Rule file: `root/etc/udev/rules.d/90-touchpad-nowake.rules`, installed to `/etc/udev/rules.d/` with:
```sh
./install.sh --variant steamos --udev
```

Home is encrypted and udev runs before login, so the feature **copies** the rule into /etc instead of symlinking it. The `90-` prefix only sets ordering: udev sorts rules by filename, so this one runs after the distro's rules.

Apply now without the installer (temporary, lasts until reboot):
```sh
echo disabled | sudo tee /sys/bus/i2c/devices/i2c-PIXA3854:00/power/wakeup
```

Reload rules by hand (the rule matches every action except `remove`, so the default `change` trigger applies it):
```sh
sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=i2c
```

Tradeoff: tapping the touchpad (or any other I2C device) no longer wakes the laptop. The keyboard and power button still do. (So did the lid, until Fix 2.)

### Verify fix 1
After applying, and again after a reboot (each line should end in `disabled`):
```sh
grep -H . /sys/bus/i2c/devices/*/power/wakeup
```

After a real sleep, woken with the keyboard:
```sh
echo "wake irq: $(cat /sys/power/pm_wakeup_irq)"; grep -H . /sys/power/suspend_stats/{success,last_hw_sleep}; journalctl -k -b --no-pager | grep -cE "PM: suspend entry"
```

Expect few suspend entries and a long last_hw_sleep. A wake IRQ of 7 means another GPIO source is still waking it.

### Undo fix 1
```sh
sudo rm /etc/udev/rules.d/90-touchpad-nowake.rules; echo enabled | sudo tee /sys/bus/i2c/devices/i2c-PIXA3854:00/power/wakeup
```

## Fix 2 (disable embedded controller wake)
The embedded controller (EC) kept waking the laptop from s2idle. Its ACPI event, GPE 0x0B, fires every few seconds. The kernel's `acpi.ec_no_wakeup` parameter stops the EC from waking the system while suspended. A systemd-tmpfiles config sets it at every boot:
```
w /sys/module/acpi/parameters/ec_no_wakeup - - - - Y
```

Evidence, on battery, with a 180 s sleep woken by an RTC alarm:
- `ec_no_wakeup=N`: woke after ~19 s.
- `ec_no_wakeup=Y`: slept the full 180 s (178.9 s hardware sleep), woken only by the RTC alarm.

Config file: `root/etc/tmpfiles.d/ec-no-wakeup.conf`, installed to `/etc/tmpfiles.d/` and applied immediately (no reboot needed) with:
```sh
./install.sh --variant steamos --tmpfiles
```

Like the udev rule, the feature **copies** the file into /etc instead of symlinking it: systemd-tmpfiles runs at early boot, before the encrypted home is unlocked, so a symlink into ~ would silently fail.

Apply now without the installer (after copying the file into /etc/tmpfiles.d):
```sh
sudo systemd-tmpfiles --create /etc/tmpfiles.d/ec-no-wakeup.conf
```

Tradeoff: opening the lid no longer wakes the laptop (the lid switch is reported through the EC). The keyboard and power button still do.

### Verify fix 2
After applying, and again after a reboot (should print `Y`):
```sh
cat /sys/module/acpi/parameters/ec_no_wakeup
```

### Undo fix 2
The parameter stays `Y` until the reboot:
```sh
sudo rm /etc/tmpfiles.d/ec-no-wakeup.conf
```
then reboot.

## Possible follow-ups
- Test whether Fix 1 is still needed: remove the touchpad rule (see [Undo fix 1](#undo-fix-1)), sleep on battery for a while, and check the wake IRQ and `last_hw_sleep` as in [Verify fix 1](#verify-fix-1). If sleep stays fixed, delete `root/etc/udev/rules.d/90-touchpad-nowake.rules`.
- Also wake-enabled: Keychron Ultra-Link 8K (USB 1-2.1, 3434:d028) and the Logitech receiver (USB 1-2.2, 046d:c539). Add similar rules if desk bumps or mouse movement wake it.
- Find what re-suspends the laptop after 25s. It's likely an idle timer or Steam/the desktop; the journal doesn't say which.
- Measure the actual drain: unplug, note `charge_now` in /sys/class/power_supply/BAT1, sleep about an hour, compare.
