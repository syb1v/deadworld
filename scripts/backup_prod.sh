#!/usr/bin/env bash
set -Eeuo pipefail

DEPLOY_PATH="${DEADWORLD_DEPLOY_PATH:-/opt/deadworld}"
BACKUP_DIR="${DEADWORLD_BACKUP_DIR:-/var/backups/deadworld}"
RETENTION_DAYS="${DEADWORLD_BACKUP_RETENTION_DAYS:-14}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TARGET="${BACKUP_DIR}/deadworld-${STAMP}.sql.gz"
TEMP="${TARGET}.tmp"

install -d -m 700 "${BACKUP_DIR}"
cd "${DEPLOY_PATH}"

cleanup() {
	rm -f "${TEMP}"
}
trap cleanup EXIT

docker compose --env-file .env -f infra/docker-compose.prod.yml exec -T postgres \
	sh -c 'exec pg_dump --clean --if-exists --no-owner --no-privileges -U "$POSTGRES_USER" "$POSTGRES_DB"' \
	| gzip -9 > "${TEMP}"
gzip -t "${TEMP}"
mv "${TEMP}" "${TARGET}"
chmod 600 "${TARGET}"
find "${BACKUP_DIR}" -maxdepth 1 -type f -name 'deadworld-*.sql.gz' -mtime "+${RETENTION_DAYS}" -delete
trap - EXIT
printf 'Deadworld backup created: %s\n' "${TARGET}"
