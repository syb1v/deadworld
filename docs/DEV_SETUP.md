# Development setup

## Supported local Linux families

Installer currently targets:

- Arch / CachyOS / Manjaro;
- Debian / Ubuntu / Linux Mint.

Другие системы можно настроить вручную по этому документу.

## Required tools

### Core

- Git
- curl / wget
- unzip / zip
- jq
- rsync
- Docker Engine
- Docker Compose
- Node.js LTS + npm
- Godot 4.7.1 stable
- Godot export templates

### Android

- OpenJDK 17
- Android SDK Command-line Tools
- Platform Tools
- Build Tools 35.0.1
- Platform 35
- CMake 3.10.2.4988404
- NDK 28.1.13356709

## Automated setup

```bash
chmod +x scripts/*.sh
./scripts/setup_dev_env.sh
```

Skip Android:

```bash
./scripts/setup_dev_env.sh --skip-android
```

Skip Docker:

```bash
./scripts/setup_dev_env.sh --skip-docker
```

Custom Godot maintenance version:

```bash
GODOT_VERSION=4.7.1 ./scripts/setup_dev_env.sh
```

## Environment file

Installer creates:

```text
~/.config/deadworld/env.sh
```

It exports:

```bash
ANDROID_HOME
ANDROID_SDK_ROOT
PATH additions
```

Installer attempts to source this file from `.profile`, `.bashrc` and `.zshrc` when those files exist.

Reload:

```bash
exec "$SHELL" -l
```

## Verify

```bash
./scripts/check_env.sh
```

Manual useful commands:

```bash
godot --version
docker --version
docker compose version
node --version
npm --version
java -version
adb version
sdkmanager --version
```

## Docker permissions

If installer adds the current user to `docker`, the new group membership may require a full logout/login.

Do not work around this with:

```bash
sudo chmod 666 /var/run/docker.sock
```

The local Linux Make targets merge `infra/docker-compose.host.yml`. Nakama and PostgreSQL bind directly to loopback through host networking, avoiding Docker published-port stalls observed on some local Docker installations. PostgreSQL is configured with `listen_addresses=127.0.0.1` and is not exposed externally.

## Android SDK licenses

The script intentionally invokes official interactive license acceptance rather than silently accepting licenses.

After acceptance it installs the package set required by the chosen Godot 4.7 Android setup.

## Android device test

On phone:

- enable Developer options;
- enable USB debugging;
- connect cable;
- approve host.

Then:

```bash
adb devices
```

Device should show as `device`, not `unauthorized`.

## Day 6 exports

Build all local artifacts:

```bash
make export-all
```

Or separately:

```bash
make export-linux
make export-windows
make export-android
```

Artifacts are written to ignored `dist/`. Android uses a debug signature; no release keystore is committed.

Desktop builds accept command-line endpoint overrides:

```bash
godot --path client -- --server-host=192.168.1.10
```

The main menu also accepts and remembers a complete backend URL. Android target SDK 36 blocks cleartext HTTP by default, so use an HTTPS URL such as `https://game.example.com`; Day 7 provides this through Caddy/TLS. `127.0.0.1` points to the phone itself and cannot reach the development PC. Physical Android crossplay is not complete until tested against that reachable TLS endpoint.

## Godot Android editor paths

If Godot does not autodetect them, set:

```text
Java SDK Path    -> JDK 17 location
Android SDK Path -> ~/Android/Sdk
```

## iOS

iOS is intentionally not automated by this Linux script.

Нужны:

- macOS;
- Xcode;
- Apple signing configuration.

Архитектура клиента остаётся общей, но iOS build не блокирует недельный MVP.


## Existing GitHub repository

Remote уже существует:

```text
https://github.com/syb1v/deadworld
```

Подготовить clone:

```bash
./scripts/prepare_repo.sh "$HOME/Projects/deadworld"
```

Установить окружение + подготовить clone:

```bash
./scripts/bootstrap_everything.sh
```

Существующий `LICENSE` сохраняется.

## Day 1 local backend

```bash
make up
make test
make client
```

Nakama API is on `http://127.0.0.1:7350`; local console is on `http://127.0.0.1:7351`. Configuration comes from ignored `.env`.

## Day 7 production operations

The standard deployment path is `/opt/deadworld`. Copy `.env.example` to an ignored `.env`, replace every local credential with a random production value, set `GAME_HOSTNAME`, then keep the file at mode `600`.

Preferred automated path on Ubuntu 24.04:

```bash
git clone https://github.com/syb1v/deadworld.git /opt/deadworld
cd /opt/deadworld
sudo scripts/deploy_prod.sh
```

The interactive script supports `standalone` Caddy and an existing `shared-caddy` Docker edge. It is idempotent: existing `.env` secrets and database volumes are preserved. On first deployment it prints the generated admin password once; store it in a password manager. In `shared-caddy` mode the script never reloads or restarts Caddy: Perum tenant routes are dynamic runtime configuration and would be lost by loading only the static Caddyfile.

```bash
npm --prefix server ci
npm --prefix server run build
docker compose --env-file .env -f infra/docker-compose.prod.yml config --quiet
docker compose --env-file .env -f infra/docker-compose.prod.yml up -d --wait
```

Only SSH and Caddy ports `80/443` are public. PostgreSQL and raw Nakama ports remain on Docker networks. On a shared host where another Caddy already owns `80/443`, set `CADDY_NETWORK` and add `-f infra/docker-compose.shared-caddy.yml`; this disables the bundled Caddy unless its explicit profile is selected and attaches Nakama to the existing proxy network. Add a validated hostname route to that proxy.

The Nakama socket server key is a public application client key shipped in every build; it is not an administrative secret. Database, runtime HTTP, console, signing and session encryption credentials are never included in clients or Git.

Back up and perform a non-destructive restore test:

```bash
sudo DEADWORLD_DEPLOY_PATH=/opt/deadworld scripts/backup_prod.sh
sudo DEADWORLD_DEPLOY_PATH=/opt/deadworld scripts/test_restore_prod.sh /var/backups/deadworld/deadworld-TIMESTAMP.sql.gz
```

The restore test starts a temporary PostgreSQL container, restores the dump, checks that public tables exist, and removes the container. To restore after an actual incident, stop Nakama, create an additional safety dump, then feed the reviewed archive to `psql -v ON_ERROR_STOP=1` in the PostgreSQL container before restarting Nakama.

The MVP endpoint is `https://game.staydev.org`. The current VPS shares an existing Caddy edge: Deadworld Nakama joins `perum_internal`, while the host-specific Caddy route proxies `game.staydev.org` to `nakama:7350`. Do not publish Nakama or PostgreSQL ports as a workaround.

The temporary test admin is available at `https://game.staydev.org/admin/`. Production `ADMIN_USERNAME`, `ADMIN_PASSWORD` and `ADMIN_SESSION_KEY` are random host-only values in `/opt/deadworld/.env`; never place them in client builds or Git. Admin actions are visible in `docker compose logs admin nakama`. Zombie respawn is for MVP testing and should be removed or redesigned before a public operational release. The separate `Лендинг` tab edits persisted public copy and chooses automatic or manual release selection.

The landing and public status endpoint are `https://game.staydev.org/` and `https://game.staydev.org/status`. Status contains aggregate availability/player/zombie counts only, never player IDs, credentials or storage contents. Automatic download links use the newest non-draft GitHub release or prerelease that contains all three platform assets, with a 15-minute cache and persisted last-known fallback.

### GitHub prerelease

Run `make package-release` for local packages. Tags matching `v*-prealpha.*` build the supported Linux/Windows architecture matrix, a release-signed universal Android APK, native Linux packages and checksums before creating a GitHub prerelease. Android signing uses repository secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`; never put their values in files or logs. Play Console AAB requires a separate custom-Gradle pipeline and remains pending. Do not tag `v0.1.0-mvp` before physical crossplay acceptance.
