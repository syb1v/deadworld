# Project Deadworld

> **Pre-alpha / vertical-slice stage**

Current client metadata version: `0.1.0`; release label/tag: `v0.1.0-mvp`.

Production pre-alpha backend: `https://game.staydev.org` (HTTPS/WSS). Physical Android crossplay and clean-install acceptance remain release gates.

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

- Windows
- Android
- Linux — если не мешает сроку

### Позже

- iOS/iPadOS
- macOS
- Steam / Google Play / App Store

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

Day 6 now includes a shared 1280x720 map with seven named areas, server-authoritative player/zombie collision, touch intentions and Linux/Windows/Android export presets. The generated Android build is landscape arm64 with Internet permission. Physical PC-to-Android crossplay remains an acceptance gate because no Android device is currently connected; Android should use the HTTPS backend URL provided by Day 7.

Desktop exports consist of the executable and its adjacent `.pck`; distribute both files together. Initial and reconnect world discovery retry short transient RPC failures before reporting an error.

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
