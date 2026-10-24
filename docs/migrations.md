# Migrations
`install.sh` doesn't clean up after changes to the repo's layout: a feature only installs the current layout and
never removes what an older one left behind. When a change on `main` leaves stale files on machines that installed
an older version, it is listed here, oldest first, with the steps to fix it by hand.

## For agents
You are updating a machine whose `~/dotfiles` checkout was just pulled, or is about to be.

1. Find the commit the machine was on before the pull: `git -C ~/dotfiles reflog` (the entry before the latest
   `pull`/`merge`/`reset`), or `ORIG_HEAD` right after a pull. If you can't tell, treat it as older than every
   entry: each one has a check that is safe to run on any machine.
2. Resolve each entry's commit on `main`. Entries name the squash-merged PR, so look it up with
   `git -C ~/dotfiles log --oneline --grep='(#<number>)' origin/main` (the hash is given too, once known).
   An entry applies if its commit is not an ancestor of the old commit:
   `! git -C ~/dotfiles merge-base --is-ancestor <commit> <old commit>`.
3. Work through the entries that apply in order. For each step, run its **Check** first and skip the step if it
   finds nothing; only then run **Fix**, and confirm with **Verify**. Steps that run `sudo` or delete files: show
   the user what will change and ask first.
4. Report which steps you ran, skipped (and why), and anything that did not verify.

Don't add migration code to `install.sh` or the features for these; when a change needs one, add an entry here
instead (newest last) in the same shape.

## Merge steamos-config into dotfiles (#18, 9e2f895)
The standalone steamos-config repo moved into `~/dotfiles/steamos`, and `home_units` started installing its files
under names after `dotfiles`. Applies to SteamOS machines that ran steamos-config's installer.

### Old home-units files in /etc
- **Check:** `ls -d /etc/steamos-config /etc/atomic-update.conf.d/steamos-config.conf /etc/atomic-update.conf.d/home-units.conf 2>/dev/null`
- **Fix:** run `~/dotfiles/install.sh --variant steamos --home_units` first, so the new files are in place, then
  `sudo rm -f /etc/steamos-config/home-units-start /etc/atomic-update.conf.d/steamos-config.conf /etc/atomic-update.conf.d/home-units.conf`
  and `sudo rmdir /etc/steamos-config`.
- **Verify:** the check prints nothing, and `systemctl --user cat home-units.service` shows `ExecStart=/etc/dotfiles/home-units-start`.

### Old webterm units
- **Check:** `grep -l steamos-config ~/.config/systemd/user/webterm*.service 2>/dev/null`
- **Fix:** `~/dotfiles/install.sh --variant steamos --link --webterm`. Once the check prints nothing, a leftover
  standalone checkout (e.g. `~/steamos-config`) can be deleted, after asking the user.
- **Verify:** the check prints nothing and the URL `--webterm` prints answers.

## Move steamos/ into home/ and root/ (#46)
webterm's scripts, page and units moved from `steamos/` into `home/` (ttyd now downloads to `~/.local/bin/ttyd`),
home-units and hdmi-audio-fix files moved under `root/etc/`, and `LINK_DESKTOP_PATHS` stopped linking `root/etc`
and `root/usr` as whole directories.

### webterm units still point into steamos/ (steamos)
- **Check:** `grep -l 'dotfiles/steamos' ~/.config/systemd/user/webterm*.service 2>/dev/null`
- **Fix:** `~/dotfiles/install.sh --variant steamos --link --webterm` (`--link` first: the units now run the scripts
  it links into `~/.local/bin`).
- **Verify:** the check prints nothing, `~/.local/bin/ttyd` exists, and the URL `--webterm` prints answers.

### Old ttyd download in the checkout (steamos)
Once `steamos/.gitignore` is gone, git shows the old download as untracked.
- **Check:** `git -C ~/dotfiles status --short --ignored -- steamos`
- **Fix:** only after the step above verified, `rm -rf ~/dotfiles/steamos` if the check lists nothing but
  `steamos/bin/ttyd` and `__pycache__` directories; otherwise show the user what else is there and ask.
- **Verify:** the check prints nothing.

### Links into /etc that are now copied, or no longer linked (arch)
`root/etc` used to be linked as a whole, which also linked files their features copy instead (the udev rule and the
tmpfiles config).
- **Check:** `sudo find /etc /usr/local /usr/share/kbd -type l -lname "$HOME/dotfiles/root/*"`, then compare each
  link with `LINK_DESKTOP_PATHS` in `~/dotfiles/install/features/link.sh`: a link whose repo path is not listed
  there is stale.
- **Fix:** on a Framework 16, `~/dotfiles/install.sh --variant arch --udev --tmpfiles`, which replaces those links
  with copies. Otherwise, after asking, `sudo rm` each stale link (only links, never regular files), then
  `sudo udevadm control --reload` if a udev rule was removed.
- **Verify:** rerunning the check lists only paths in `LINK_DESKTOP_PATHS`.
