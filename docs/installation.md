# Installation
`install.sh` is the single entry point. Choose what to install for with `--variant` (`coder`, `arch`, `steamos`, `portable`), which names an OS and a profile, or with `--os`, `--profile` and `--machine`, or let `--infer` guess them (see [OS, Profile and Machine](#os-profile-and-machine)), and toggle features with flags; run `./install.sh --variant <name> --help` to list the features, and `--all` to enable all of the default ones. Optional features (listed under "Optional" in `--help`, e.g. `--printer` on `arch`) are skipped by `--all` and run only when named. With no arguments it prints usage, unless defaults are set (see [Defaults](#defaults)). To set up a machine once instead, such as installing Arch from its live ISO, use `--oti` (see [One-time installs](one-time-installs/arch-install.md#one-time-installs)). Features that can be undone also accept `--uninstall`, which removes them, and `--reinstall`, which removes all of them (in reverse order), then installs them again; both apply to every selected feature that supports them (listed by `--help`), and the rest are skipped or just installed. For example, `--distrobox --reinstall` asks before deleting the `arch` distrobox, then recreates and enters it. Features whose settings are often changed in a settings app (`desktop_settings`, dconf on `arch` and KDE's config files on `steamos`) also accept `--capture`, which goes the other way: it copies this system's settings back into the repo, to review with `git diff` and commit. `./install.sh --variant arch --capture --all` captures every feature that can; add `--dry-run` to see the diff without writing it. A feature supports it by defining `capture_feature_<name>` (for a feature with several implementations, `capture_feature_<name>__<dir>` beside each one that can).

## Capturing settings
The dconf and KDE settings files are loaded by `--desktop_settings`, through its GNOME or KDE implementation (see [Feature implementations](writing-features.md#feature-implementations)), and written back by `--capture --desktop_settings`; [GNOME features](features/gnome.md#desktop_settings) and [KDE features](features/kde.md#desktop_settings) describe each. Both use `capture_filter` (`install/lib/capture.sh`). A capture rewrites the files, so keep notes about their settings in the code rather than in comments in them.

## Where the repo lives
The repo must live at `~/dotfiles`, since everything `install.sh` links points there, and `install.sh` refuses to run from any other checkout. `~/dotfiles` may be a symlink, but the checkout itself must be a directory named `dotfiles`, which lint relies on. When run from a git checkout elsewhere (such as the one Coder clones to `~/.config/coderv2/dotfiles`) and `~/dotfiles` doesn't exist, `install.sh` clones that checkout's current commit to `~/dotfiles`, sets the clone's `origin` to the checkout's, and re-runs from the clone with the same arguments; uncommitted changes aren't copied. `install.sh` doesn't clean up after layout changes, so after pulling, follow [migrations.md](migrations.md) for any changes that left stale files behind (it is written so an agent can work through it). `install.sh` doesn't run on its own: it refuses without its `install/` directory beside it.

## Installing on a fresh machine
On a fresh machine, install from the `install` branch instead. It holds a single file, a bootstrap `install.sh` that names one commit of `main` (`PINNED_REPO` and `PINNED_COMMIT`): it clones the repo at that commit to `~/dotfiles`, on the default branch so later pulls still work, and runs the clone's `install.sh` with the same arguments. If `~/dotfiles` already exists, it runs that as it is. Each commit on the `install` branch pins exactly one commit of `main`, so a URL naming an `install` branch commit instead of `install` always installs the same version.

The bootstrap is generated from its template, `bootstrap/install.sh`, by `scripts/bootstrap.sh` (`scripts/bootstrap.sh --commit <rev>` prints it). After CI passes on a push to `main`, the install branch workflow (`.github/workflows/install-branch.yml`) runs `scripts/bootstrap.sh --publish install`, which commits a bootstrap pinning that commit onto the `install` branch; it never moves the branch to an older commit, and can also be run by hand from the Actions tab. If the `install` branch is protected, let `github-actions` bypass the rules that would block its push. A fork's workflow pins the fork itself, and creates its `install` branch on its first run.
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/eldenmanking/dotfiles/install/install.sh)" -- --variant coder --all
```

## OS, Profile and Machine
An install is for three things:
 - the OS (`--os`): `arch` (Arch Linux or Arch-based), `steamos`, or `portable` (any Linux or macOS, e.g. WSL, without its package manager or root);
 - the profile (`--profile`), how the machine is used: `desktop` (your own machine with a desktop session), `minimal` (a terminal setup only) or `workspace` (a Coder workspace);
 - the machine (`--machine`), the hardware: `generic` (the default) or `framework16`.

Only the combinations in the [README's table](../README.md#os-profile-and-machine) exist. `--os` and `--profile` override the variant's, so `--variant steamos --profile minimal` is the SteamOS terminal setup. Features for specific hardware ([Framework 16 features](features/framework16.md)) are included by `--all` only on their machine; on other machines `--help` lists them under "For other machines", and naming one still runs it, with a warning.

`--infer` guesses whichever of the three isn't given by an option or a default, with `install/lib/infer.sh`, to suit the ones given. The OS is `portable` in a Coder workspace (`CODER=true`), else `steamos` or `arch` from `/etc/os-release`, else `portable` (other Linux systems and macOS); it is also `portable` when the given profile needs it, as `workspace` does. The profile is `workspace` in a Coder workspace on `portable`, `desktop` on `arch` and `steamos` (since their desktop installs set up the desktop, an Arch install without one yet still gets it), and `minimal` otherwise. The machine comes from the DMI vendor and product name in `/sys/class/dmi/id`, and is `generic` on an OS that doesn't support the one found. Without `--infer` nothing is guessed: `--os` needs `--profile` (and the other way around) unless `--variant` gives it, and the machine is `generic`. `./install.sh --infer --help` shows what it picks without installing anything.

## Defaults
To run `install.sh` without arguments (as Coder's dotfiles support does), set defaults in the environment or in `~/.config/dotfiles/install.conf`, which is sourced like a shell script (the environment wins; set `DOTFILES_INSTALL_CONFIG` to read a different file):
 - `DOTFILES_VARIANT`, `DOTFILES_OS` and `DOTFILES_PROFILE`: the OS and profile to use when the command line doesn't give them, as a variant whose OS and profile `DOTFILES_OS` and `DOTFILES_PROFILE` override (like `--variant`, `--os` and `--profile`).
 - `DOTFILES_MACHINE`: the machine to use when `--machine` isn't given (and not inferred, even with `--infer`).
 - `DOTFILES_FEATURES`: the features to run when the command line names none, as a space-separated list of feature names, with `all` for `--all` (e.g. `all printer`). They are ignored under `--uninstall`, and when the command line picks a different OS or profile than the defaults name.

```bash
# ~/.config/dotfiles/install.conf
DOTFILES_VARIANT=coder
DOTFILES_FEATURES=all
```

With that file, `./install.sh` runs `--variant coder --all`, `./install.sh --dry-run` previews it, `./install.sh --tmux` runs only `tmux` on `coder`, and `./install.sh --help` lists the `coder` options. In a Coder template, setting the two variables in the workspace agent's environment does the same without a file.

## Download Cache
Features download their pinned binaries (ttyd, framework_tool, the Nerd Font, neovim, starship, tmux) with `download_verified` and clone gng, tre and logiops at pinned commits with `clone_pinned`. `download_verified` checks each download against its SHA-256 and `clone_pinned` checks that HEAD is the pinned commit; Pinned downloads in `.claude/CLAUDE.md` says how to update a pin. Set `DOTFILES_DOWNLOAD_CACHE` in the environment to a directory to reuse them: a file there named by the SHA-256 is used instead of downloading (and still checked), and each download is stored there. `make fixtures` shares one between its containers.
