.PHONY: help env-check preflight repo-tree

help:
	@echo "Project Deadworld"
	@echo "  make env-check   - verify local development environment"
	@echo "  make preflight   - verify repository/docs/secrets baseline"
	@echo "  make repo-tree   - show repository directories"
	@echo ""
	@echo "Day 1 agent must add real up/down/logs/test commands."

env-check:
	@./scripts/check_env.sh

preflight:
	@./scripts/preflight_repo.sh

repo-tree:
	@find . -maxdepth 2 -type d -not -path './.git*' -not -path './node_modules*' | sort
