.PHONY: help env-check preflight repo-tree up down logs test test-restart prod-config export-linux export-windows export-android export-all package-release ios client version-stamp version-check

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
	@echo "  make version-stamp - write VERSION into client/package metadata"
	@echo "  make version-check - fail when metadata drifted from VERSION"
	@echo "  make export-all  - build Linux, Windows and Android clients"
	@echo "  make package-release - create portable prerelease archives"
	@echo "  make ios         - build unsigned resignable IPA on macOS"
	@echo "  make client      - run Godot client"

version-stamp:
	@python3 scripts/version.py stamp

version-check:
	@python3 scripts/version.py check

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
	python3 scripts/version.py check
	npm --prefix server run check
	npm --prefix server test
	npm --prefix server run build
	node --test admin/server.test.mjs
	$(COMPOSE) config --quiet
	NAKAMA_SERVER_KEY=$$(grep '^NAKAMA_SERVER_KEY=' .env | cut -d= -f2-) NAKAMA_HTTP_KEY=$$(grep '^NAKAMA_HTTP_KEY=' .env | cut -d= -f2-); NAKAMA_SERVER_KEY=$${NAKAMA_SERVER_KEY:-deadworld-local-key} NAKAMA_HTTP_KEY=$${NAKAMA_HTTP_KEY:-deadworld-local-http-key} npm --prefix server run test:integration
	godot --headless --path client --editor --quit
	godot --headless --path client --script res://tests/touch_controls_test.gd
	godot --headless --path client --script res://tests/interaction_ux_test.gd
	godot --headless --path client --script res://tests/nakama_socket_test.gd

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
	mkdir -p dist/linux-x86_64 dist/linux-arm64
	godot --headless --path client --export-release "Linux x86_64"
	godot --headless --path client --export-release "Linux arm64"

export-windows:
	mkdir -p dist/windows-x86_64 dist/windows-arm64
	godot --headless --path client --export-release "Windows x86_64"
	godot --headless --path client --export-release "Windows arm64"

export-android:
	mkdir -p dist
	./scripts/export_android_release.sh

export-all: export-linux export-windows export-android

package-release: export-all
	python3 scripts/package_release.py

ios:
	@./scripts/build_ios_unsigned.sh

client:
	@NAKAMA_SERVER_KEY=$$(grep '^NAKAMA_SERVER_KEY=' .env | cut -d= -f2-); godot --path client -- --server-host=127.0.0.1 --server-port=7350 --server-scheme=http --server-key=$${NAKAMA_SERVER_KEY:-deadworld-mvp-client-v1}
COMPOSE = docker compose --env-file .env -f infra/docker-compose.yml -f infra/docker-compose.host.yml
