#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
	printf 'Run as root: sudo %q\n' "$0" >&2
	exit 1
fi

REPO_URL="${DEADWORLD_REPOSITORY_URL:-https://github.com/syb1v/deadworld.git}"
DEPLOY_PATH="${DEADWORLD_DEPLOY_PATH:-/opt/deadworld}"
BACKUP_DIR="${DEADWORLD_BACKUP_DIR:-/var/backups/deadworld}"

read -r -p "Production hostname (example: game.example.com): " GAME_HOSTNAME
[[ "${GAME_HOSTNAME}" =~ ^[A-Za-z0-9.-]+$ ]] || { echo "Invalid hostname" >&2; exit 1; }
read -r -p "Admin login [operator]: " ADMIN_USERNAME
ADMIN_USERNAME="${ADMIN_USERNAME:-operator}"
	read -r -p "Release tag [v0.1.0-prealpha.5]: " RELEASE_TAG
	RELEASE_TAG="${RELEASE_TAG:-v0.1.0-prealpha.5}"
read -r -p "GitHub repository [syb1v/deadworld]: " GITHUB_REPOSITORY
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-syb1v/deadworld}"
read -r -p "Edge mode: standalone or shared-caddy [standalone]: " EDGE_MODE
EDGE_MODE="${EDGE_MODE:-standalone}"
[[ "${EDGE_MODE}" == "standalone" || "${EDGE_MODE}" == "shared-caddy" ]] || { echo "Unsupported edge mode" >&2; exit 1; }

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl git openssl python3 ufw docker.io docker-compose-v2
systemctl enable --now docker

if [[ -d "${DEPLOY_PATH}/.git" ]]; then
	git -C "${DEPLOY_PATH}" pull --ff-only
else
	install -d -m 755 "$(dirname "${DEPLOY_PATH}")"
	git clone "${REPO_URL}" "${DEPLOY_PATH}"
fi

if [[ ! -f "${DEPLOY_PATH}/.env" ]]; then
	ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
	umask 077
	cat > "${DEPLOY_PATH}/.env" <<EOF
PROJECT_NAME=deadworld
ENVIRONMENT=production
GAME_HOSTNAME=${GAME_HOSTNAME}
POSTGRES_DB=deadworld
POSTGRES_USER=deadworld
POSTGRES_PASSWORD=$(openssl rand -hex 32)
NAKAMA_SERVER_KEY=deadworld-mvp-client-v1
NAKAMA_HTTP_KEY=$(openssl rand -hex 32)
NAKAMA_CONSOLE_USERNAME=deadworld_admin
NAKAMA_CONSOLE_PASSWORD=$(openssl rand -hex 32)
NAKAMA_CONSOLE_SIGNING_KEY=$(openssl rand -hex 32)
NAKAMA_SESSION_ENCRYPTION_KEY=$(openssl rand -hex 32)
NAKAMA_SESSION_REFRESH_ENCRYPTION_KEY=$(openssl rand -hex 32)
ADMIN_USERNAME=${ADMIN_USERNAME}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
ADMIN_SESSION_KEY=$(openssl rand -hex 32)
RELEASE_TAG=${RELEASE_TAG}
GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
EOF
	chmod 600 "${DEPLOY_PATH}/.env"
	printf '\nAdmin credentials (store now):\n  URL: https://%s/admin/\n  Login: %s\n  Password: %s\n\n' "${GAME_HOSTNAME}" "${ADMIN_USERNAME}" "${ADMIN_PASSWORD}"
else
	printf 'Using existing mode-600 %s/.env; secrets were not replaced.\n' "${DEPLOY_PATH}"
	chmod 600 "${DEPLOY_PATH}/.env"
fi

docker run --rm -v "${DEPLOY_PATH}:/work" -w /work node:24-alpine npm --prefix server ci
docker run --rm -v "${DEPLOY_PATH}:/work" -w /work node:24-alpine npm --prefix server run build

COMPOSE=(docker compose --env-file "${DEPLOY_PATH}/.env" -f "${DEPLOY_PATH}/infra/docker-compose.prod.yml")
if [[ "${EDGE_MODE}" == "shared-caddy" ]]; then
	read -r -p "Existing Caddy Docker network [perum_internal]: " CADDY_NETWORK
	CADDY_NETWORK="${CADDY_NETWORK:-perum_internal}"
	read -r -p "Existing Caddy container name [caddy]: " CADDY_CONTAINER
	CADDY_CONTAINER="${CADDY_CONTAINER:-caddy}"
	read -r -p "Existing host Caddyfile path [/opt/perum-node/caddy/Caddyfile]: " SHARED_CADDYFILE
	SHARED_CADDYFILE="${SHARED_CADDYFILE:-/opt/perum-node/caddy/Caddyfile}"
	[[ -f "${SHARED_CADDYFILE}" ]] || { echo "Caddyfile not found: ${SHARED_CADDYFILE}" >&2; exit 1; }
	grep -q '^CADDY_NETWORK=' "${DEPLOY_PATH}/.env" || printf 'CADDY_NETWORK=%s\n' "${CADDY_NETWORK}" >> "${DEPLOY_PATH}/.env"
	COMPOSE+=(-f "${DEPLOY_PATH}/infra/docker-compose.shared-caddy.yml")
fi

"${COMPOSE[@]}" config --quiet
"${COMPOSE[@]}" up -d --wait

ufw allow OpenSSH
ufw limit 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

install -d -m 700 "${BACKUP_DIR}"
install -d -m 700 /var/log/deadworld
cat > /etc/cron.d/deadworld-backup <<EOF
17 3 * * * root DEADWORLD_DEPLOY_PATH=${DEPLOY_PATH} DEADWORLD_BACKUP_DIR=${BACKUP_DIR} ${DEPLOY_PATH}/scripts/backup_prod.sh >>/var/log/deadworld/backup.log 2>&1
EOF
chmod 644 /etc/cron.d/deadworld-backup
DEADWORLD_DEPLOY_PATH="${DEPLOY_PATH}" DEADWORLD_BACKUP_DIR="${BACKUP_DIR}" "${DEPLOY_PATH}/scripts/backup_prod.sh"

if [[ "${EDGE_MODE}" == "standalone" ]]; then
	curl --retry 12 --retry-delay 5 --fail --silent --show-error "https://${GAME_HOSTNAME}/status" >/dev/null
else
	docker network inspect "${CADDY_NETWORK}" >/dev/null
	docker network connect "${CADDY_NETWORK}" "${CADDY_CONTAINER}" 2>/dev/null || true
	# Perum owns dynamic Caddy routes through its Admin API. Reloading the
	# static file would erase tenant routes, so only verify the existing route.
	curl --retry 12 --retry-delay 5 --fail --silent --show-error "https://${GAME_HOSTNAME}/status" >/dev/null
fi

"${COMPOSE[@]}" ps
printf '\nDeployment complete: https://%s/\n' "${GAME_HOSTNAME}"
