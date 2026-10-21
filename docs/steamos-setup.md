# SteamOS installation

Instructions for setting up a SteamOS machine the way I like it, plus the
resources I used.

## OS installation

Follow Valve's official guide: [Installing SteamOS][steamos-install]. On a
Linux box, write the recovery image with `dd` as below rather than a
multi-boot tool like Ventoy, which the SteamOS image behaves poorly with.

1. Download the SteamOS recovery image from the page above: the Deck, Machine
   and PC image, or the separate Frame image. Either one downloads as
   `steamdeck-recovery-4.img.bz2` (the number may change).

2. Plug in a USB drive (8GB minimum) and find its device name. Check
   carefully, because the next step overwrites the whole device:

   ```sh
   lsblk
   ```

3. Write the image to the drive (replace `/dev/sdX` with the **whole device**,
   not a partition like `/dev/sdX1`). This is Valve's command; `bzcat`
   decompresses on the fly, so there's no need to extract the image first:

   ```sh
   bzcat steamdeck-recovery-4.img.bz2 | sudo dd if=/dev/stdin of=/dev/sdX oflag=sync status=progress bs=128M
   ```

4. Boot the target machine from the USB drive. Most non-Deck hardware needs
   Secure Boot disabled in the BIOS first; the guide above has steps for the
   Legion Go and ROG Ally.

5. Once the recovery desktop loads, choose **Wipe Device & Install SteamOS**.
   The same environment also offers Re-image Device (factory reset), Repair
   SteamOS (keeps games and personal content) and Recovery tools.

## Steam settings

In Steam, under **Settings > In Game**:

- Change the main menu shortcut key to <kbd>Win</kbd>+<kbd>Tab</kbd>.
- Change the quick access shortcut key to <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Tab</kbd>.

## dotfiles

After the OS is installed and you've signed in to Steam:

1. Switch to Desktop Mode: press the Steam button, then **Power > Switch to
   Desktop**.
2. Open Konsole and give the `deck` user a password, which `sudo` needs (SteamOS
   ships without one):

   ```sh
   passwd
   ```

3. Clone this repo to `~/dotfiles` and run the installer:

   ```sh
   git clone https://github.com/eldenmanking/dotfiles ~/dotfiles
   ~/dotfiles/install.sh --variant steamos --all
   ```

   Run `~/dotfiles/install.sh --help` to see the features, or add `--dry-run`
   to preview the changes. This includes webterm, a browser shell on
   localhost; see [steamos/README.md](../steamos/README.md).

## Disk encryption

SteamOS does not support full disk encryption, so don't treat the machine as
safe for sensitive information, even with the steps below. Encryption here
only protects a user's home directory, and the rest of the system stays
unencrypted.

The approach:

- Don't keep sensitive data on the machine. Use an alternate account for
  Steam and gaming rather than your main one.
- Enable home directory encryption with dirlock. Follow
  [Enabling disk encryption on the Steam Deck][dirlock].

## Windows apps

[GNOME Boxes][gnome-boxes] works well enough for running Windows apps in a VM.
Windows 11 needs some registry tinkering during setup to skip the TPM and
Secure Boot requirements. The video [Installing Windows 11 via Gnome
Boxes][boxes-video] walks through the whole process.

See also the GNOME Boxes [issue #236][boxes-issue].

If you use the Flatpak version of GNOME Boxes, USB devices must be attached to
the VM manually.

### Bypassing the TPM and Secure Boot checks

> These are the commonly documented steps for the Windows 11 installer. I
> haven't checked them against the video above, so adjust them to match it if
> they differ.

If the installer stops with "This PC can't run Windows 11":

1. Press `Shift+F10` to open a command prompt, then run `regedit`.
2. Go to `HKEY_LOCAL_MACHINE\SYSTEM\Setup`.
3. Right-click `Setup`, choose **New → Key**, and name it `LabConfig`.
4. Inside `LabConfig`, create two **DWORD (32-bit)** values and set each to `1`:
   - `BypassTPMCheck`
   - `BypassSecureBootCheck`
5. Close regedit and the command prompt, go back one step in the installer,
   and continue.

### Creating a local account

To skip the Microsoft account requirement, open a command prompt on the
sign-in screen with `Shift+F10` and run:

```
start ms-cxh:localonly
```

This opens a local account creation dialog.

> As with the regedit steps above, this is the commonly documented method and
> hasn't been checked against the video.

### Debloating Windows

After Windows is installed, run [Win11Debloat][win11debloat] to remove
preinstalled apps and trim telemetry and other defaults.

## Resources

- [Installing SteamOS][steamos-install]
- [Enabling home directory encryption (dirlock)][dirlock]
- [Installing Windows 11 via Gnome Boxes (video)][boxes-video]
- [Win11Debloat][win11debloat]
- [GNOME Boxes issue #236][boxes-issue]

[steamos-install]: https://help.steampowered.com/en/faqs/view/65B4-2AA3-5F37-4227
[dirlock]: https://gitlab.steamos.cloud/holo/dirlock/-/wikis/Enabling-disk-encryption-on-the-Steam-Deck
[boxes-video]: https://www.youtube.com/watch?v=7yFaVNE-0SY
[gnome-boxes]: https://wiki.gnome.org/Apps/Boxes
[win11debloat]: https://github.com/raphire/win11debloat
[boxes-issue]: https://gitlab.gnome.org/GNOME/gnome-boxes/-/work_items/236
