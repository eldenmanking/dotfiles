# Testing
Checks come in three kinds, each with a make target; `make check` runs all three. Fixtures (`make fixtures`) are a fourth, kept out of `make check` since they need docker or podman and network access.

- [Validation](testing/validation.md) (`make validate`, `tests/validation/`): the repo's structure, which has to keep holding as files are added, moved or removed
- [Lint](testing/lint.md) (`make lint`, `tests/lint/`): code quality: syntax, shellcheck, function docs, portability
- [Tests](testing/tests.md) (`make test`, `tests/install.sh`): behavior: `install.sh` in scratch homes
- [Fixtures](testing/fixtures.md) (`make fixtures`, `tests/fixtures.sh`): exactly what an install does to existing files, in containers
- [CI](testing/ci.md): which of these run where

zsh and python3 checks are skipped with a warning when those are missing, except in CI.
