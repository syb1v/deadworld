.PHONY: help env-check preflight repo-tree up down logs test client

help:
	@echo "Project Deadworld"
	@echo "  make env-check   - verify local development environment"
	@echo "  make preflight   - verify repository/docs/secrets baseline"
	@echo "  make repo-tree   - show repository directories"
	@echo "  make up          - build and start backend"
	@echo "  make down        - stop backend"
	@echo "  make logs        - follow backend logs"
	@echo "  make test        - run Day 1 checks"
	@echo "  make client      - run Godot client"

env-check:
	@./scripts/check_env.sh

preflight:
	@./scripts/preflight_repo.sh

repo-tree:
	@find . -maxdepth 2 -type d -not -path './.git*' -not -path './node_modules*' | sort

up:
	npm --prefix server install
	npm --prefix server run build
	docker compose --env-file .env -f infra/docker-compose.yml up -d --wait

down:
	docker compose --env-file .env -f infra/docker-compose.yml down

logs:
	docker compose --env-file .env -f infra/docker-compose.yml logs -f

test:
	npm --prefix server run check
	npm --prefix server test
	npm --prefix server run build
	docker compose --env-file .env -f infra/docker-compose.yml config --quiet
	NAKAMA_SERVER_KEY=$$(grep '^NAKAMA_SERVER_KEY=' .env | cut -d= -f2-) npm --prefix server run test:integration
	godot --headless --path client --editor --quit

client:
	godot --path client
