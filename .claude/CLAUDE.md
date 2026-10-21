# dotfiles
Personal Linux/macOS dotfiles plus `install.sh`, which links them into place and installs tools. `README.md` has the annotated file tree, the variants and the install flow; read it before changing structure, and keep its tree in sync when adding, moving or removing files.

`.claude/` holds Claude Code config for working on this repo only (this file, plus any repo-specific skills or settings). Machine-wide config (the global CLAUDE.md, skills, hook scripts, settings) lives in separate tools repos (by default eldenmanking/tools; see `DOTFILES_TOOLS` in `README.md`), which the `claude` feature installs into `~/.claude`.

## install.sh layout
- `install/lib/`: shared helpers (`fn.sh` output variables, `exec.sh` dry-run aware execution, `fs.sh` symlinks and managed blocks).
- `install/features/<name>.sh`: one `feature_<name>` function per feature. Register its `--help` text in `feature_description` (`install/lib/features.sh`), and add it to `DRY_RUN_FEATURES` if it honors `--dry-run`.
- `install/variants/<name>.sh`: `variant_<name>` sets `_description`, `_features`, `_all_exclude` and `_link_paths`. Features run in `_features` order.
- Files meant to be linked live under `home/` (maps to `$HOME`) or `root/` (maps to `/`); everything else at the top level is repo-only. Paths to symlink go in `LINK_COMMON_PATHS`, `LINK_SHELL_PATHS`, `LINK_STEAMOS_PATHS` or `LINK_DESKTOP_PATHS` (`install/features/link.sh`), prefixed with `home/` or `root/`.

## Shell conventions
Write functions in a functional style:
- Pass inputs as arguments. Return values through `_`-prefixed output variables via `f_write_args fn _out1 _out2 -- args...`, not by setting globals or parsing stdout.
- Globals are UPPER_CASE constants set at file load time; never mutate them from functions. Declare everything else `local`.
- Keep pure logic (parsing, resolving config) separate from side effects, and route side effects through `run`/`run_tty` so `--dry-run` works.
- Every feature must be idempotent: check current state first, and use `make_symlink` and `upsert_block` rather than raw `ln` or appends.
- Shell startup files (`.profile`, `.bashrc`, `.zshrc`, ...) only source files under `home/.config/sh` and `home/.config/zsh`, so linked and managed installs share the same logic. Features write managed ones with `upsert_sources`. `env.sh` (environment, sourced from profiles and rc files) must stay POSIX sh and safe to source repeatedly.
- Stay portable across Linux and macOS (bash 3.2: no `mapfile`, associative arrays or namerefs; no GNU-only flags).

## Verifying changes
- `bash -n` every changed script, and `shellcheck` when available.
- `install.sh` requires the repo at `~/dotfiles`. To exercise a feature without touching the real home, point `HOME` at a scratch directory containing a `dotfiles` symlink to this checkout, then run `HOME=<dir> ./install.sh --variant <name> --<feature>`; use `--dry-run` for features that need root or a package manager.
