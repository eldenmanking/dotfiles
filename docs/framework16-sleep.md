# Framework 16 / SteamOS: sleep battery drain

## Diagnosis
- Deep sleep (s2idle) works. A ~27s suspend reached ~25.2s of hardware sleep, and amd_pmc/amd_pmf are loaded.
- The problem is repeated waking. The journal showed a loop: sleep 9-56s, wake, stay awake exactly 25s, re-suspend (12 cycles in 10 min). The laptop was awake about half the time.
- Wake source: IRQ 7 (pinctrl_amd, GPIO). Nearly all GPIO interrupts come from the touchpad, `PIXA3854:00` (146,342 of 146,451), and it was the only I2C device with wake enabled.
- Ruled out: Bluetooth (wake event 0x0), lid, power button, removed dGPU, GPU perf override (now `auto`), NVMe APST, battery health (89%, 127 cycles).
- Possible secondary issue: the touchpad's I2C controller (AMDI0010:03) logged ~4.6M interrupts in ~80 min while idle. The pad may be reporting noise, so try cleaning it or reseating the module if wakes continue.

## Fix (disable I2C wake)
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

Tradeoff: tapping the touchpad (or any other I2C device) no longer wakes the laptop. The keyboard, power button and lid still do.

## Verify
After applying, and again after a reboot (each line should end in `disabled`):
```sh
grep -H . /sys/bus/i2c/devices/*/power/wakeup
```

After a real sleep, woken with the keyboard:
```sh
echo "wake irq: $(cat /sys/power/pm_wakeup_irq)"; grep -H . /sys/power/suspend_stats/{success,last_hw_sleep}; journalctl -k -b --no-pager | grep -cE "PM: suspend entry"
```

Expect few suspend entries and a long last_hw_sleep. A wake IRQ of 7 means another GPIO source is still waking it.

## Undo
```sh
sudo rm /etc/udev/rules.d/90-touchpad-nowake.rules; echo enabled | sudo tee /sys/bus/i2c/devices/i2c-PIXA3854:00/power/wakeup
```

## Possible follow-ups
- Also wake-enabled: Keychron Ultra-Link 8K (USB 1-2.1, 3434:d028) and the Logitech receiver (USB 1-2.2, 046d:c539). Add similar rules if desk bumps or mouse movement wake it.
- Find what re-suspends the laptop after 25s. It's likely an idle timer or Steam/the desktop; the journal doesn't say which.
- Measure the actual drain: unplug, note `charge_now` in /sys/class/power_supply/BAT1, sleep about an hour, compare.
