.PHONY: help env-check preflight repo-tree up down logs test test-restart client

help:
	@echo "Project Deadworld"
	@echo "  make env-check   - verify local development environment"
	@echo "  make preflight   - verify repository/docs/secrets baseline"
	@echo "  make repo-tree   - show repository directories"
	@echo "  make up          - build and start backend"
	@echo "  make down        - stop backend"
	@echo "  make logs        - follow backend logs"
	@echo "  make test        - run Day 1 checks"
	@echo "  make test-restart - destructive isolated Day 5 full restart test"
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
	sleep 6

down:
	docker compose --env-file .env -f infra/docker-compose.yml down

logs:
	docker compose --env-file .env -f infra/docker-compose.yml logs -f

test:
	npm --prefix server run check
	npm --prefix server test
	npm --prefix server run build
	docker compose --env-file .env -f infra/docker-compose.yml config --quiet
	NAKAMA_SERVER_KEY=$$(grep '^NAKAMA_SERVER_KEY=' .env | cut -d= -f2-) NAKAMA_HTTP_KEY=$$(grep '^NAKAMA_HTTP_KEY=' .env | cut -d= -f2-); NAKAMA_SERVER_KEY=$${NAKAMA_SERVER_KEY:-deadworld-local-key} NAKAMA_HTTP_KEY=$${NAKAMA_HTTP_KEY:-deadworld-local-http-key} npm --prefix server run test:integration
	godot --headless --path client --editor --quit

test-restart:
	npm --prefix server run check
	npm --prefix server test
	npm --prefix server run build
	docker compose --env-file .env -f infra/docker-compose.yml down
	docker compose --env-file .env -f infra/docker-compose.yml up -d --wait
	sleep 6
	docker run --rm --network infra_default --env-file .env -v "$(CURDIR)/server:/work" -v "/tmp/opencode:/tmp/opencode" -w /work -e GAME_HOST=nakama node:24-alpine npm run test:restart:prepare
	docker compose --env-file .env -f infra/docker-compose.yml down
	docker compose --env-file .env -f infra/docker-compose.yml up -d --wait
	docker run --rm --network infra_default --env-file .env -v "$(CURDIR)/server:/work" -v "/tmp/opencode:/tmp/opencode" -w /work -e GAME_HOST=nakama node:24-alpine npm run test:restart:verify

client:
	godot --path client
