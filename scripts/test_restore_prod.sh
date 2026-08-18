#!/usr/bin/env bash
set -Eeuo pipefail

DEPLOY_PATH="${DEADWORLD_DEPLOY_PATH:-/opt/deadworld}"
BACKUP_PATH="${1:?Usage: test_restore_prod.sh /path/to/deadworld-TIMESTAMP.sql.gz}"
NETWORK="deadworld_backend"
CONTAINER="deadworld-restore-test-$$"

cd "${DEPLOY_PATH}"
set -a
# shellcheck disable=SC1091
source .env
set +a

cleanup() {
	docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

gzip -t "${BACKUP_PATH}"
docker run -d --rm --name "${CONTAINER}" --network "${NETWORK}" \
	-e POSTGRES_DB=deadworld_restore_test \
	-e POSTGRES_USER="${POSTGRES_USER}" \
	-e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
	postgres:17.6-alpine >/dev/null

for _ in $(seq 1 30); do
	if docker exec "${CONTAINER}" pg_isready -U "${POSTGRES_USER}" -d deadworld_restore_test >/dev/null 2>&1; then
		break
	fi
	sleep 1
done
docker exec "${CONTAINER}" pg_isready -U "${POSTGRES_USER}" -d deadworld_restore_test >/dev/null
gzip -dc "${BACKUP_PATH}" | docker exec -i "${CONTAINER}" \
	psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" -d deadworld_restore_test >/dev/null
TABLE_COUNT="$(docker exec "${CONTAINER}" psql -At -U "${POSTGRES_USER}" -d deadworld_restore_test -c "SELECT count(*) FROM pg_catalog.pg_tables WHERE schemaname = 'public';")"
if [[ ! "${TABLE_COUNT}" =~ ^[0-9]+$ ]] || (( TABLE_COUNT == 0 )); then
	printf 'Restore test failed: restored database has no public tables\n' >&2
	exit 1
fi
printf 'Deadworld restore test passed: %s public tables\n' "${TABLE_COUNT}"
