# Infrastructure

Local development uses `docker-compose.yml` plus the Linux host-network override. Production uses the separate `docker-compose.prod.yml`: PostgreSQL is isolated on an internal network, Nakama is reachable only by Caddy, and Caddy publishes `80/443` with public ACME TLS.

Production configuration is loaded from an ignored `/opt/deadworld/.env`. Validate it with:

```bash
docker compose --env-file .env -f infra/docker-compose.prod.yml config --quiet
```

Daily backups use `scripts/backup_prod.sh`; `scripts/test_restore_prod.sh` restores a selected dump into an isolated temporary PostgreSQL container and never modifies the production database. A shared host that already owns `80/443` must reuse its existing Caddy with `docker-compose.shared-caddy.yml`, set `CADDY_NETWORK`, and add a validated hostname route instead of starting a second proxy.
