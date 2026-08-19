# Project Deadworld

> **Pre-alpha / vertical-slice stage**

Current client metadata version: `0.1.0`; public test label/tag: `v0.1.0-prealpha.6`. The final MVP tag `v0.1.0-mvp` remains gated by physical cross-platform acceptance of the updated client.

Versioning is driven by the repository-root `VERSION` file. `make version-stamp` writes that tag into the Godot menu label, in-game build marker, Android `versionCode`/`versionName`, iOS `CFBundleShortVersionString`/`CFBundleVersion`, DEB/RPM package versions and the deployment defaults; `make version-check` fails when any of them drift. Every published artifact is named `deadworld-<tag>-<platform>-<arch>.<ext>`, so downloads, installers and GBox imports never collide with a previously cached file.

Production pre-alpha backend: `https://game.staydev.org` (HTTPS/WSS). Physical Android crossplay and clean-install acceptance remain release gates.

The public landing groups every asset actually published in the selected release: Linux TAR.GZ/DEB/RPM architectures, Windows ZIP/EXE architectures, universal Android APK, optional unsigned iOS IPA and checksum files. iOS IPA filenames include the release tag so GBox and iOS import caches cannot silently reuse an older payload with the same filename. Linux x86_64, Windows x86_64 and Android remain the automatic release-selection core; the separately uploaded iOS artifact does not delay selection and is shown as soon as GitHub reports it.

Temporary authenticated test operations are served at `https://game.staydev.org/admin/`. Credentials are production-host secrets; the panel exposes recent authoritative events and a persisted dead-zombie respawn action without exposing Nakama console or raw backend ports.

The Russian landing page at `https://game.staydev.org/` shows live server/player status and links to the current GitHub prerelease builds.

Project Deadworld — рабочее название кроссплатформенной persistent online survival RPG с изометрическим/2.5D представлением, server-authoritative сетевой моделью и постепенным развитием от небольшого multiplayer vertical slice до MMO-архитектуры.

Главный принцип проекта:

> Сначала доказать, что 2–5 игроков могут весело и надёжно выживать на одном persistent сервере. Потом масштабировать контент и онлайн.

## GitHub

Основной repository:

```text
https://github.com/syb1v/deadworld
```

Для автоматического старта открой `START_HERE.md` и `PASTE_TO_AGENT.md`.

## Целевые платформы

### MVP

- Windows x86_64, x86_32 и ARM64
- Android ARMv7 + ARM64
- Linux x86_64, x86_32, ARMv7 и ARM64

### Позже

- macOS
- Steam / Google Play / App Store

## Установка игры

Все пользовательские сборки находятся на `https://game.staydev.org/` и в текущем GitHub prerelease. Перед запуском сверяйте файл с `SHA256SUMS.txt`.

### Как выбрать архитектуру

| Устройство | Сборка |
|---|---|
| Обычный современный ПК Intel/AMD | `x86_64` |
| Старый 32-битный ПК | `x86_32` / `i386` / `i686` |
| Windows on ARM | `windows-arm64` |
| Raspberry Pi 4/5, ARM64 Linux | `linux-arm64` / `arm64` / `aarch64` |
| Старый 32-битный ARM Linux | `linux-arm32` / `armhf` / `armv7hl` |
| Android | universal APK: ARMv7 + ARM64 |

### Windows

Рекомендуемый вариант: скачать `deadworld-windows-x86_64.zip`, распаковать папку и запустить `deadworld.exe`. Game data встроены в executable.

Отдельный самодостаточный `deadworld-windows-<arch>.exe` также публикуется. Windows SmartScreen может предупредить о новом неподписанном EXE: Microsoft Authenticode certificate пока отсутствует.

### Debian, Ubuntu, Linux Mint

```bash
sudo apt install ./deadworld-linux-amd64.deb
/opt/deadworld/deadworld
```

Для других процессоров выберите `i386`, `armhf` или `arm64`.

### Fedora, RHEL, Rocky, openSUSE

```bash
sudo dnf install ./deadworld-linux-x86_64.rpm
/opt/deadworld/deadworld
```

Для других процессоров выберите `i686`, `armv7hl` или `aarch64`. На системах без `dnf` используйте штатный RPM package manager.

### Arch, Manjaro и другие Linux

Скачайте подходящий `deadworld-linux-<arch>.tar.gz`:

```bash
tar -xzf deadworld-linux-x86_64.tar.gz
cd deadworld
chmod +x deadworld
./deadworld
```

Godot runtime динамически использует системные библиотеки Linux. На очень старых дистрибутивах может потребоваться более новая glibc; минимальная совместимость конкретного ARM-устройства подтверждается отдельным hardware test.

### Android

Скачайте `deadworld-android-universal.apk`. APK поддерживает ARMv7 и ARM64 и подписан постоянным release key. Certificate SHA-256:

```text
9cebee147a1946f48083a6798480cc314f936833282384aa20d36ab00595233c
```

Android, Google Play Protect, Samsung Auto Blocker и Xiaomi Security могут предупреждать о любом APK, установленном не из Google Play. Release signature снижает подозрительность и обеспечивает безопасные обновления, но полностью убрать OEM warnings можно только распространением через Google Play. Следующий шаг публикации — настроить reproducible AAB export и закрытый Play Internal Testing track.

Не отключайте защиту устройства глобально. Разрешайте установку только браузеру/файловому менеджеру, которым скачан APK, проверяйте checksum и certificate fingerprint, затем возвращайте настройку в исходное состояние.

### iOS и iPadOS

iOS test build создаётся отдельным macOS GitHub Actions workflow без Apple signing. Это дополнительная testing platform, а не обязательный MVP gate и не App Store build.

## iOS test build

### Automatic build

```text
GitHub -> Actions -> iOS unsigned build -> Run workflow
```

Workflow использует Godot `4.7.1`, экспортирует Xcode project, собирает `iphoneos` arm64 с полностью отключённым code signing и создаёт:

```text
deadworld-ios-arm64-unsigned.ipa
```

### Installation

```text
Download IPA
-> import into GBox
-> sign with owner's existing certificate/profile
-> install
```

Unsigned IPA нельзя установить стандартными средствами iOS напрямую. Его необходимо переподписать совместимыми certificate и provisioning profile. CI не требует Apple Developer Program, Apple certificate или provisioning profile и не хранит их. Совместимость конкретного стороннего сертификата с bundle ID `org.staydev.deadworld` должна быть подтверждена физической установкой.

Для локальной сборки на Mac с Xcode:

```bash
make ios
```

На Linux команда сообщает, что нужен macOS + Xcode, и направляет в GitHub Actions. Checklist физического теста: `docs/IOS_TESTING.md`.

## Стек MVP

- **Godot 4.7.1 stable**
- **GDScript** — игровой клиент
- **Nakama** — auth/realtime/server runtime
- **TypeScript** — authoritative server runtime
- **PostgreSQL** — persistent storage
- **Docker Compose** — локальная и серверная инфраструктура
- **Caddy** — TLS/reverse proxy
- **OpenJDK 17 + Android SDK** — Android export

Версии фиксируем в репозитории. Не обновляем движок/SDK посреди недельного MVP без причины.

## Что считать MVP

MVP готов, когда два или больше реальных клиента могут через интернет:

1. подключиться к одному серверу;
2. иметь разные аккаунты/guest IDs;
3. появиться в одном мире;
4. видеть друг друга;
5. двигаться с server-authoritative validation;
6. видеть одинаковых зомби;
7. драться с ними;
8. подбирать общий loot без duplication;
9. использовать inventory/container;
10. умереть и respawn;
11. переподключиться;
12. после выхода/рестарта получить корректно сохранённый state.

Это **не релиз MMO**. Это proof-of-architecture + playable vertical slice.

## Быстрый старт на Linux

Поддерживаемые установщиком семейства:

- Arch Linux / CachyOS / Manjaro;
- Debian / Ubuntu / Linux Mint.

### 1. Установить окружение

```bash
chmod +x scripts/*.sh
./scripts/setup_dev_env.sh
```

Скрипт ставит/настраивает:

- Git;
- curl/wget/jq/zip/unzip/rsync;
- Docker Engine + Compose;
- Node.js LTS через nvm;
- Godot 4.7.1;
- Godot export templates;
- OpenJDK 17;
- Android Command-line Tools;
- Android platform-tools;
- Android Build Tools 35.0.1;
- Android Platform 35;
- CMake 3.10.2.4988404;
- Android NDK 28.1.13356709.

Android SDK licenses принимаются интерактивно через официальный `sdkmanager`.

### 2. Перезапустить shell

После установки:

```bash
exec "$SHELL" -l
```

Если пользователь был добавлен в группу `docker`, может потребоваться logout/login.

### 3. Проверить окружение

```bash
./scripts/check_env.sh
```

В конце должно быть:

```text
Environment status: READY
```

или понятный список того, что осталось исправить.

### 4. Сформировать будущий рабочий репозиторий

Например:

```bash
./scripts/create_repo.sh ~/Projects/deadworld
cd ~/Projects/deadworld
```

Скрипт:

- создаст структуру;
- скопирует документацию и служебные файлы;
- создаст `.env` из `.env.example`;
- выставит executable bit скриптам;
- выполнит `git init -b main`.

Он не создаёт удалённый GitHub-репозиторий и ничего никуда не пушит.

### 5. Читать перед кодом

В таком порядке:

1. `docs/MVP.md`
2. `docs/ARCHITECTURE.md`
3. `docs/PROTOCOL.md`
4. `docs/GDD.md`
5. `AGENTS.md`
6. `docs/prompts/DAY_01.md`

## Структура

```text
deadworld/
├── AGENTS.md
├── CONTRIBUTING.md
├── README.md
├── SECURITY.md
├── .editorconfig
├── .env.example
├── .gitignore
├── Makefile
├── client/
├── server/
├── shared/
│   ├── data/
│   └── protocol/
├── infra/
├── tools/
├── scripts/
└── docs/
    ├── GDD.md
    ├── ARCHITECTURE.md
    ├── PROTOCOL.md
    ├── MVP.md
    ├── ROADMAP.md
    ├── DEV_SETUP.md
    ├── DECISIONS.md
    └── prompts/
```

## Scope discipline

Во время MVP запрещено добавлять «раз уж мы здесь»:

- кланы;
- рынок;
- автомобили;
- procedural мегаполис;
- skill tree;
- десятки видов оружия;
- полноценную медицину;
- weather simulation;
- Kubernetes;
- Kafka;
- Redis;
- микросервисы.

Если функция не нужна для текущего Definition of Done — она идёт в backlog.

## Day 5: persistent authoritative world

Pinned dependencies: Godot `4.7.1`, Nakama `3.40.0`, Nakama Godot SDK `3.4.0`, PostgreSQL `17.6`.

```bash
make up
make client
```

`make client` passes the local Nakama client key from ignored `.env` and overrides the production project default with `http://127.0.0.1:7350`. If the backend is unavailable, the main menu now remains interactive and reports the endpoint after a bounded three-second connection attempt instead of showing an empty map indefinitely.

Launch two independent guests without editing sources:

```bash
godot --path client -- --profile=one
godot --path client --position 1300,100 -- --profile=two
```

Automated auth/socket/shared-world/movement/zombie/item and combat lifecycle coverage runs with `make test`. The Russian HUD shows health, selected weapon, magazine, reserve ammo, inventory slots and finite zombie population. Press `E` to pick up/take, `Q` to drop, `1`-`8` to select, `Space` or left mouse to attack, `R` to reload, and `Esc` to pause. Player state, inventory stacks, magazine ammo, world items, containers/versions and dead zombies persist in private versioned Nakama Storage.

`make test-restart` is the Day 5 gate: it performs gameplay mutations, completely tears down PostgreSQL and Nakama containers, starts them again, reconnects the same account and verifies restored state with no duplicated/lost item instances.

The local Compose profile binds Nakama API and console ports to loopback. Test-world RPCs require the private runtime HTTP key and reject normal user sessions.

Day 6 includes a shared logical 1280x720 world with seven named areas, server-authoritative player/zombie collision and cross-platform exports. Mobile HUD controls adapt to the landscape viewport and display safe area: the left joystick moves, while the right joystick aims and emits one attack when dragged into its outer ring. Release the right stick or return it below the inner reset threshold before firing again. Physical cross-platform combinations remain acceptance gates and use the production HTTPS/WSS backend.

Nearby interaction now identifies the exact target. `E` or the mobile `ДЕЙСТВИЕ` button picks up a world item or opens a container. The container panel lists authoritative contents beside the private backpack and sends explicit whole-instance Take/Deposit intentions; it never moves ownership locally before server confirmation. Split stacks, drag/drop and Take All remain later `v0.1.1` work.

Desktop exports consist of the executable and its adjacent `.pck`; distribute both files together. Initial and reconnect world discovery retry short transient RPC failures before reporting an error.

Create the same portable archives used by GitHub Releases:

```bash
make package-release
```

## Production deployment

On a fresh Ubuntu 24.04 host, clone the repository and run the interactive idempotent deployment:

```bash
sudo scripts/deploy_prod.sh
```

The script asks for hostname, admin login, prerelease tag and edge mode; installs Docker/Compose, generates host-only secrets, builds the Nakama runtime, starts PostgreSQL/Nakama/portal/Caddy, configures UFW, creates the backup cron and validates HTTPS health. `shared-caddy` mode safely backs up, validates and reloads an existing Caddy configuration.

CI runs from `.github/workflows/ci-release.yml`. Tags matching `v*-prealpha.*` build the documented architecture/package matrix and create a GitHub prerelease. `v0.1.0-mvp` must not be created until physical PC ↔ Android acceptance passes.

```bash
make logs
make test
make test-restart
make export-all
make down
```

## Основные команды

```bash
make help
make env-check
make repo-tree
make up
make down
make logs
make test
make test-restart
make client
```

## Документ истины

При конфликте документов приоритет:

1. текущий `docs/MVP.md` — scope текущей недели;
2. `docs/ARCHITECTURE.md` — технические инварианты;
3. `docs/PROTOCOL.md` — wire contract;
4. `docs/GDD.md` — продуктовое видение;
5. backlog/идеи.

## Лицензирование и чужой контент

Project Deadworld вдохновляется жанровыми механиками, но не должен копировать код, ассеты, карты, UI, тексты, названия, звук или другой защищённый контент конкретных игр.

---

**Текущий milestone:** `v0.1.0-mvp — Online Survival Vertical Slice`
