# Claude Code
The `--claude` feature installs Claude Code configuration from one or more tools repos, by default just [eldenmanking/tools](https://github.com/eldenmanking/tools) cloned to `~/tools`. From each repo it inserts `claude/CLAUDE.md` into `~/git/.claude/CLAUDE.md` (all repos' files joined, in order, into its `## feature claude` subblock), symlinks each entry of `claude/skills` and `claude/scripts` into `~/.claude`, and deep-merges `claude/settings.json` into `~/.claude/settings.json`. Existing checkouts are fast-forwarded on each run.

Repos are listed in priority order. When two repos ship a skill or script with the same name, the earlier repo's is linked and the later one is skipped with a warning; when their settings disagree on a value, the earlier repo's value is kept (lists are unioned).

To choose the tools repos, set the following in the environment or in `~/.config/dotfiles/tools.conf` (the environment wins; set `DOTFILES_TOOLS_CONFIG` to read a different file):
 - `DOTFILES_TOOLS`: one repo per line as `<repo> [dir] [ref]`, where `repo` is a git URL, `dir` is the checkout location (default `~/<repo name>`, or `-` to keep the default while giving a ref) and `ref` is a branch or tag (default: the repo's default branch). Blank lines and `#` comments are ignored. A `dir` that exists but isn't a git checkout is used as-is. Each repo needs its own `dir`.

For a single repo, the older per-field variables still work and are used when `DOTFILES_TOOLS` is unset:
 - `DOTFILES_TOOLS_REPO`: git URL to clone (default `https://github.com/eldenmanking/tools.git`)
 - `DOTFILES_TOOLS_DIR`: checkout location (default `~/tools`)
 - `DOTFILES_TOOLS_REF`: branch or tag to check out (default: the repo's default branch)

```bash
# ~/.config/dotfiles/tools.conf
DOTFILES_TOOLS="
https://github.com/eldenmanking/tools.git            # ~/tools
git@github.com:someone/tools.git  ~/git/someone-tools  # same repo name, so give it its own dir
git@github.com:work/claude-config.git  -  stable       # ~/claude-config, on the stable branch
"
```
