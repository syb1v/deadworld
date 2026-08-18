.PHONY: help env-check preflight repo-tree up down logs test test-restart prod-config export-linux export-windows export-android export-all client

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
	@echo "  make prod-config  - validate the production Compose configuration"
	@echo "  make export-all  - build Linux, Windows and Android clients"
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
	$(COMPOSE) up -d --wait
	sleep 6

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

test:
	npm --prefix server run check
	npm --prefix server test
	npm --prefix server run build
	$(COMPOSE) config --quiet
	NAKAMA_SERVER_KEY=$$(grep '^NAKAMA_SERVER_KEY=' .env | cut -d= -f2-) NAKAMA_HTTP_KEY=$$(grep '^NAKAMA_HTTP_KEY=' .env | cut -d= -f2-); NAKAMA_SERVER_KEY=$${NAKAMA_SERVER_KEY:-deadworld-local-key} NAKAMA_HTTP_KEY=$${NAKAMA_HTTP_KEY:-deadworld-local-http-key} npm --prefix server run test:integration
	godot --headless --path client --editor --quit

test-restart:
	npm --prefix server run check
	npm --prefix server test
	npm --prefix server run build
	$(COMPOSE) down
	$(COMPOSE) up -d --wait
	sleep 6
	docker run --rm --network host --env-file .env -v "$(CURDIR)/server:/work" -v "/tmp/opencode:/tmp/opencode" -w /work -e GAME_HOST=127.0.0.1 node:24-alpine npm run test:restart:prepare
	$(COMPOSE) down
	$(COMPOSE) up -d --wait
	docker run --rm --network host --env-file .env -v "$(CURDIR)/server:/work" -v "/tmp/opencode:/tmp/opencode" -w /work -e GAME_HOST=127.0.0.1 node:24-alpine npm run test:restart:verify

prod-config:
	docker compose --env-file .env -f infra/docker-compose.prod.yml config --quiet

export-linux:
	mkdir -p dist
	godot --headless --path client --export-release Linux ../dist/deadworld-linux.x86_64

export-windows:
	mkdir -p dist
	godot --headless --path client --export-release Windows ../dist/deadworld-windows.exe

export-android:
	mkdir -p dist
	godot --headless --path client --export-debug Android ../dist/deadworld-android.apk

export-all: export-linux export-windows export-android

client:
	@NAKAMA_SERVER_KEY=$$(grep '^NAKAMA_SERVER_KEY=' .env | cut -d= -f2-); godot --path client -- --server-host=127.0.0.1 --server-port=7350 --server-scheme=http --server-key=$${NAKAMA_SERVER_KEY:-deadworld-mvp-client-v1}
COMPOSE = docker compose --env-file .env -f infra/docker-compose.yml -f infra/docker-compose.host.yml
