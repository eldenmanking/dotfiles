# dotfiles
Personal Linux/macOS dotfiles plus `install.sh`, which links them into place and installs tools. `README.md` has the annotated file tree, the variants and the install flow; read it before changing structure, and keep its tree in sync when adding, moving or removing files.

`.claude/` holds Claude Code config for working on this repo only (this file, plus any repo-specific skills or settings). Machine-wide config (the global CLAUDE.md, skills, hook scripts, settings) lives in separate tools repos (by default eldenmanking/tools; see `DOTFILES_TOOLS` in `README.md`), which the `claude` feature installs into `~/.claude`.

## install.sh layout
- `install/lib/`: shared helpers (`fn.sh` output variables, `exec.sh` dry-run aware execution, `fs.sh` symlinks and managed blocks).
- `install/features/<name>.sh`: one `feature_<name> <variant> <enabled>` function per feature. Register its `--help` text in `feature_description` (`install/lib/features.sh`), document the function in the comment directly above it with a brief description, a bare `#` line, then `# @machine`, `# @os`, `# @gui` and optionally `# @requires` tags (values in `install/lib/features.sh`, checked by `make validate`; keep the README table in sync), and add it to `DRY_RUN_FEATURES` if it honors `--dry-run`.
- A feature that can be undone also defines `uninstall_feature_<name> <variant> <enabled>`, which `--uninstall` runs (in reverse feature order) and `--reinstall` runs before `feature_<name>`. It must be idempotent, always honor `--dry-run`, and confirm before destroying user data. Defining it is all it takes; `--help` lists it automatically.
- `install/variants/<name>.sh`: `variant_<name>` sets `_description`, `_features`, `_os`, `_gui`, `_optional` and `_link_paths`. Features run in `_features` order, so list each after the features it requires; `_optional` lists the ones `--all` skips, which run only when their flag is given (`--help` shows them separately).
- Files meant to be linked live under `home/` (maps to `$HOME`) or `root/` (maps to `/`); everything else at the top level is repo-only. Paths to symlink go in `LINK_COMMON_PATHS`, `LINK_SHELL_PATHS`, `LINK_STEAMOS_PATHS` or `LINK_DESKTOP_PATHS` (`install/features/link.sh`), prefixed with `home/` or `root/`.

## Shell conventions
Write functions in a functional style:
- Pass inputs as arguments. Return values through `_`-prefixed output variables via `f_write_args fn _out1 _out2 -- args...`, not by setting globals or parsing stdout. A function with a single result may print it instead, for the caller to capture with `$(...)` (e.g. `feature_function`, `explain_checkout_problem`).
- Globals are UPPER_CASE constants set at file load time; never mutate them from functions. Declare everything else `local`.
- Keep pure logic (parsing, resolving config) separate from side effects, and route side effects through `run`/`run_tty` so `--dry-run` works.
- Every feature must be idempotent: check current state first, and use `make_symlink` and `upsert_block` rather than raw `ln` or appends.
- Shell startup files (`.profile`, `.bashrc`, `.zshrc`, ...) only source files under `home/.config/sh` and `home/.config/zsh`, so linked and managed installs share the same logic. Features write managed ones with `upsert_sources`. `env.sh` (environment, sourced from profiles and rc files) must stay POSIX sh and safe to source repeatedly.
- Stay portable across Linux and macOS (bash 3.2: no `mapfile`, associative arrays or namerefs; no GNU-only flags).
- Don't call `_`-prefixed helpers from another file; they are private to it. Add a public helper to `install/lib/` instead.

## Verifying changes
- Run `make check` before pushing; CI runs the same targets. It runs `make validate` (structure that must hold: checkout name, README tree, pinned checksums, feature docs and requirements), `make lint` (syntax, the pinned shellcheck with `.shellcheckrc`, actionlint) and `make test` (behavior: install.sh in scratch homes). Put structural checks in `tests/validation/`, code-quality checks in `tests/lint/`, and behavior tests at the top of `tests/`. See Testing in `README.md`.
- Fix shellcheck findings rather than disabling them; when one is intentional (e.g. word splitting a list), disable it on that line with a `# shellcheck disable=SCxxxx # reason` comment.
- shellcheck follows sourced files (`.shellcheckrc`). In startup files write `source "$HOME/dotfiles/..."`, not `~/dotfiles/...`: shellcheck resolves it through the checkout's parent (so the checkout must be named `dotfiles`, which `install.sh` enforces). Give other runtime paths (`$LIB_DIR/...`) a `# shellcheck source=<path relative to the script>` directive; use `source=/dev/null` only for sources that can't be followed, like a glob loop or user config.
- `install.sh` requires the repo at `~/dotfiles`. To exercise a feature without touching the real home, point `HOME` at a scratch directory containing a `dotfiles` symlink to this checkout, then run `HOME=<dir> ./install.sh --variant <name> --<feature>`; use `--dry-run` for features that need root or a package manager.
