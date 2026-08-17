# Project Deadworld

> **Pre-alpha / vertical-slice stage**

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

## Основные команды

Пока код ещё не создан, Makefile содержит безопасные helpers:

```bash
make help
make env-check
make repo-tree
```

После появления `infra/docker-compose.yml` coding-agent должен добавить:

```bash
make up
make down
make logs
make test
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
