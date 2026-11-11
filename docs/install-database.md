# Install database (design proposal)
Status: proposal, nothing here is implemented yet.

`install.sh` features are convergent: each checks the current state and fixes it, and remembers nothing. So nothing
knows what an older version installed. Stale files need hand-written steps in `docs/migrations.md`, and each
`uninstall_feature_<name>` has to work out again what its feature did. Package managers solve this with a database of
what each package installed (pacman's `/var/lib/pacman/local`, dpkg's `/var/lib/dpkg`), and this proposal does the same
for features: the shared helpers record every change a feature makes, with the state it replaced, so a later run can
undo what a feature no longer does and an uninstall can restore what was there before.

## Goals
- Undo, generically: remove what a feature installed, restoring what it replaced, without per-feature code.
- Upgrade by diff: after a feature runs, undo what it did last time but not this time, as pacman does for files dropped
  from a package. This replaces most `docs/migrations.md` entries.
- Uninstall features that are no longer in the selection's feature list, or no longer in the repo.
- Never destroy a change the user made after install without asking.
- Keep format changes rare and simple: one manifest version, with `docs/migrations.md` for breaking changes.

Not in scope for now: transaction-level hooks (one `daemon-reload` for the whole run), and a conflict pre-check
before any feature runs (see Follow-ups).

## Layout
The database lives in the checkout, ignored by git, next to everything else `install.sh` owns:

```
~/dotfiles/.state/
├── manifest                   --- every feature's entries, as of each feature's last run
├── backups/<feature>/<path>   --- files and links an entry replaced, at their original path
├── v<N>/                       --- the manifest and backups of an earlier format version, set aside by --all
└── lock                       --- present while install.sh runs, so two runs can't interleave
```

- `.state` goes in `.gitignore`. Old commits' `.gitignore` doesn't list it, but git leaves untracked paths alone on
  checkout, so checking out an older commit doesn't disturb it.
- Entries outside `$HOME` (system files, system units, packages) are recorded here too. That gives no new power to
  anyone who can write the checkout: they can already change the code `install.sh` runs with sudo.
- Backups of files outside `$HOME` are written with sudo and keep their owner and mode, under a root-owned
  `backups/<feature>/` directory, so a root-only file doesn't become readable by copying it into the home.
- Deleting the checkout deletes the database, as it already deletes `.backup`. A fresh clone starts with no
  database, so it behaves like a machine that installed before the database existed.
- Encrypted homes are not a concern: the database is read only when `install.sh` runs, never at boot.

## Manifest format
The manifest is one text file with one record per line and fields separated by tabs. bash 3.2 can read it with
`IFS=$'\t' read -r`. Its first line is the format version (see Versioning the format), then each installed feature
has a header line followed by its entries:

```
version	1
feature	<name>	<sha of the checkout its last run used>	<os>	<profile>	<machine>
<name>	<kind>	<key...>	<written>	<prior>
...
```

Each feature keeps its own commit, since runs can install a subset of features (`--tmux`) or fail partway, and
`refs/dotfiles/installed/<feature>` points at it so git never garbage-collects it (e.g. after a squash merge removes
the branch it was on). The commit is there for diagnosis and for migration steps that need the old code. A feature's
entries appear in the order they were made, and are undone in reverse. A path containing a tab or newline is an error.

| Kind | Made by | Key | `written` | `prior` |
|---|---|---|---|---|
| `link` | `make_symlink` | target | link destination | `-` (absent), `file` or `link:<dest>` (backed up) |
| `file` | `copy_system_file(s)`, `write_file`, `download_verified`, git clones | path | sha256, or `dir` | `-` or `file` (backed up) |
| `block` | `upsert_block`, `upsert_sources`, `keep_across_steamos_updates` | file, block name | sha256 of block | `-` (file absent) or `file` |
| `unit` | `install_system_units`, `install_user_units` | scope (`system`/`user`), unit | `enabled` or `installed` | `-`, `installed` or `enabled` |
| `package` | package installs (pacman, yay, apt, flatpak, brew) | manager, name | `installed` | `-` or `installed` |
| `setting` | `kwriteconfig`, `dconf` | tool, key | value | value, or `-` (unset) |

Settings are the one kind whose prior state must be read before writing. For `dconf load` that means dumping the
tree it loads into first.

## Recording
- Helpers record entries. Features don't call the database directly, so a feature written with the helpers gets a
  manifest for free.
- A key is owned by one feature. Recording a key the manifest gives another feature is an error, the same as a pacman
  file conflict.
- `prior` is captured when a feature first takes ownership of a key. It is carried forward unchanged while the key stays
  in the manifest, so it always describes the state before dotfiles, never dotfiles' own earlier output. A key that is
  dropped (undone) and later recorded again captures a fresh `prior`.
- `written` is what the entry last wrote. If the current state differs from it, the user has changed it since.
- A feature's entries are collected in a temporary file. When the feature finishes, the whole manifest is rewritten
  with that feature's section replaced, to a temporary file that is then moved into place, so a crash never leaves
  half a manifest behind.
- `--dry-run` never writes the database. It reports the entries it would record and undo.

## Install and reinstall
For each selected feature, in `_features` order:
1. Read the feature's section. A manifest of another version is dealt with before any feature runs (see Versioning
   the format).
2. Run the feature, recording entries.
3. If it succeeded, undo the old entries whose keys weren't recorded this run, newest first, and write the new
   manifest. If it failed, write the old entries plus the new ones and undo nothing, so the next run can still clean up.

Features in the manifest that this run doesn't select:
- With `--all`, once every selected feature has run, each feature in the manifest that the selected OS and profile
  don't list in `_features` is undone, in reverse manifest order. That covers features since dropped from the list or
  deleted from the repo, and those of an OS or profile the machine used before. Optional features the list names stay
  installed, since `--all` never selects them. Their entries are only undone by `--uninstall` with their flag.
- Without `--all`, they are left alone, since a run that names features changes only those. The run ends by listing
  the features in the manifest that the selected OS and profile don't list in `_features`, each with its OS, profile
  and recorded commit, and how to remove them: `--all`, or `--uninstall` with their flags. Features the list does
  name but this run didn't select aren't listed: they're still part of the install.

`--uninstall` with a feature's flag removes it even if the feature has since been deleted from the repo.

## Undo
Entries are undone in one of two modes:
- Stale undo, the default: every install undoes the entries a feature no longer records, and under `--all` the
  features the selection no longer lists (see Install and reinstall). It is conservative. It skips an entry whose
  current state differs from `written`, since the user changed it (like pacman's `.pacsave`), and an entry the
  generic undo can't remove (see Escape hatch in Follow-ups). Both are reported and stay in the manifest, so
  `--uninstall` can still remove them.
- `--uninstall`, as today: removes everything a feature recorded, so the machine returns to its state before the
  feature. It also removes the entries stale undo skips: it asks before overwriting or deleting a change the user made,
  and runs the feature's own code for entries the generic undo can't remove. `--reinstall` is `--uninstall` and
  then an install, as today.

Packages are asked about in both modes (see Packages).

Each kind has one generic undo:

| Kind | Undo |
|---|---|
| `link` | if it still points at `written`, remove it and restore the backup |
| `file` | if its hash matches `written`, remove it and restore the backup (a `dir` is removed only if unchanged since it was cloned) |
| `block` | `remove_block`; if `prior` is `-` and the file is now empty, remove the file |
| `unit` | disable and remove it, or return it to `prior` |
| `package` | if `prior` is `-`, ask before removing it (see Packages); if `prior` is `installed`, leave it |
| `setting` | restore `prior`, or unset it |

`--uninstall` undoes every entry of a feature, newest first, then removes its section and its backups. Entries the
user declines to remove (a package, or a file they changed) stay in the section, and the section goes once they are
gone. `uninstall_feature_<name>` still runs first for anything entries can't express, and becomes rare. For a feature
deleted from the repo, that code is gone too: its generic entries are still undone, and the rest are reported with
the feature's recorded commit, whose code can remove them.

### Packages
A package is never removed without asking, whichever path undoes it: `--uninstall`, a package dropped from a
feature's list, or a feature undone under `--all`.
- Only packages whose `prior` is `-` are offered for removal. A package that was installed before dotfiles is left
  alone and its entry dropped.
- Each feature asks once, listing its packages for that package manager, and removes them through it (e.g.
  `pacman -Rs`, `flatpak uninstall --user`). The package manager still refuses to remove a package that others
  depend on.
- A package the user declines, or any package when there is no terminal to ask on, is kept and reported. Its entry
  stays in the manifest, so a later run asks again. `--dry-run` reports what it would ask.

## Versioning the format
The manifest has one integer version, on its first line. Bump it on any change a reader must understand: removing or
renaming a kind, changing what a field means, or adding a kind, since older code can't undo it. Fields a reader may
ignore can be added without a bump. Code only reads a manifest of its own version: it never converts an older one,
and never tries to read a newer one.

When the manifest's version differs from the code's, older or newer:
- Partial runs are refused: named features, `--uninstall` and `--reinstall`. The error names both versions and points
  to `docs/migrations.md`.
- `--all` is allowed, and starts over. It moves the manifest and backups to `.state/v<N>/`, installs every selected
  feature with a fresh manifest at the code's version, and skips stale undo for this run, since it can't read what the
  old manifest held. The `prior` it records is whatever is there now, which may be an earlier install's output.
- Every bump comes with a `docs/migrations.md` entry (written with the `update-migrations` skill) for what the new
  version doesn't clean up by itself: what the old version installed that the new one doesn't, and, if wanted, how to
  restore the state before dotfiles from `.state/v<N>/`, whose manifest the old commits recorded in it can read.

So bumps should be rare, and grouped with other breaking changes where possible.

## Relation to existing pieces
- `BACKUPS_ROOT` (`~/dotfiles/.backup`) is replaced by `.state/backups`. Backups recorded in `prior` are restorable,
  and a later backup can't overwrite an earlier one.
- The fixtures leave `~/dotfiles` out of the files they compare, except `.backup`. They would include `.state` in its
  place, with the commit in the manifest normalized, so each case pins what its install records.
- `uninstall_feature_<name>` stays for steps entries can't express.
- `docs/migrations.md` stays for machines installed before the database, for changes outside any entry, and for
  manifest version bumps.

## Follow-ups
From an audit of what the current features change that the kinds above don't yet cover:
- Directory trees: a `dir` kind that records the tree's file list, for the font, git clones (zsh plugins, tpm and its
  plugins, the tools repos) and extracted releases. A git checkout is removed only if it has no local changes or
  unpushed commits; otherwise it is kept and reported.
- Installers: audit each installer that writes files without listing them (tmux's and logiops' `make install`, gng's
  and starship's install scripts, tpm's `install_plugins`, neovim's `cp -r` into `~/.local`), and sandbox them: run
  each into a staging directory (`DESTDIR`, a temporary prefix, an extract to a temporary directory) and install the
  result through the helpers, so every file is recorded.
- Escape hatch: whatever the generic undo can't remove (e.g. the distrobox container, the webterm token that
  uninstall keeps) is still recorded as an entry, with its prior state, and undone by the feature's own code.
  Stale undo keeps such an entry and reports it, but `--uninstall` should almost always have a clean way to remove
  it.
- Side effects: temporary ones (`udevadm` reloads, service restarts, `fc-cache`) aren't recorded. Permanent ones
  are, with their prior state where it can be read: e.g. the paths `systemd-tmpfiles --create` makes, and what
  installers like gng's write outside their own files.
- Settings: give `setting` an accessor per tool, each able to read (for `prior`), write and unset: `git-config`,
  `kconfig`, `dconf` (per key), `xdg-mime`, `json` (key path, for `settings.json`), `vdf` (Steam) and `line` (a file
  plus a pattern, for `confirmsed`). The flathub remote is a `flatpak-remote` setting.
- Helpers for what features now do directly: enabling a unit dotfiles didn't install (`unit` with `prior`
  `installed`, undone by disabling only), `git clone`, `cp` and `sudo install`. A check in `tests/lint/` then
  flags direct writes in `install/features/`, so new code can't bypass the manifest.
- Conflict pre-check: plan every selected feature (a dry run that records entries) and check the keys against the
  disk and other features' manifests before changing anything.
- Transaction-level hooks.
