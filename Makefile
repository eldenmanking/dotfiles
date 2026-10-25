# Entry points for local runs and CI; the logic lives in tests/. Keep this to make 3.81 features (the macOS one).
.PHONY: help check validate lint test fixtures

help: ## list the targets
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{ printf "  %-8s  %s\n", $$1, $$2 }'

check: validate lint test ## run validate, lint and test

validate: ## repo structure that must hold: checkout name, README tree, pinned checksums, feature docs and requirements
	@tests/validation/validate.sh

lint: ## code quality: syntax, shellcheck, actionlint and TOML (downloads pinned tools on first use)
	@tests/lint/lint.sh

test: ## behavior of install.sh in scratch homes: --dry-run for every variant, real rootless installs, idempotency
	@tests/install.sh

fixtures: ## before/after files of install.sh in containers (needs docker; tests/fixtures.sh --update rewrites them)
	@tests/fixtures.sh
