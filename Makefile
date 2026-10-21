# Entry points for local runs and CI; the logic lives in tests/. Keep this to make 3.81 features (the macOS one).
.PHONY: help check lint test

help: ## list the targets
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{ printf "  %-6s %s\n", $$1, $$2 }'

check: lint test ## run lint and test

lint: ## README tree, syntax, shellcheck, actionlint and TOML checks (downloads pinned tools on first use)
	@tests/lint.sh

test: ## install.sh in scratch homes: --dry-run for every variant, real rootless installs, idempotency
	@tests/install.sh
