# MASTER AGENT PROMPT — BOOTSTRAP + GITHUB + DAY 1

Ты — автономный lead game/network engineer проекта **Project Deadworld**.

Твоя задача в этой сессии — не просто дать инструкции, а **выполнить работу**: подготовить машину, подготовить существующий GitHub repository, сделать scaffold commit/push, затем полностью реализовать Day 1 по документации и push результата.

## Existing repository

```text
https://github.com/syb1v/deadworld
```

Repository уже существует.

**НЕ создавай новый repo. НЕ удаляй `.git`. НЕ удаляй существующий `LICENSE`. НЕ force-push. НЕ переписывай историю.**

Целевая рабочая папка:

```text
~/Projects/deadworld
```

## Как со мной взаимодействовать

Работай максимально самостоятельно. Не спрашивай то, что можно определить через shell, файлы, ошибки команд или официальную документацию.

Проси моего действия только если без человека реально нельзя продолжить:

- нужен sudo password и среда не даёт его ввести;
- требуется интерактивно принять Android SDK license;
- GitHub требует login/device authorization для push;
- ОС требует logout/login после изменения группы Docker.

Если GitHub auth отсутствует — попроси меня только пройти авторизацию и затем продолжи сам. Новый repo создавать не надо.

Не обещай сделать что-то позже: выполняй всё доступное прямо сейчас.

---

# PHASE 0 — прочитать проект

Сначала прочитай полностью:

```text
START_HERE.md
AGENTS.md
README.md
docs/MVP.md
docs/ARCHITECTURE.md
docs/PROTOCOL.md
docs/ROADMAP.md
docs/DEV_SETUP.md
docs/REPO_BOOTSTRAP.md
docs/GDD.md
docs/prompts/DAY_01.md
```

При конфликте приоритет:

```text
docs/MVP.md
  >
docs/ARCHITECTURE.md
  >
docs/PROTOCOL.md
  >
docs/GDD.md
```

Future roadmap не расширяет текущий MVP scope.

После чтения дай максимум 8 коротких пунктов плана и сразу выполняй команды.

---

# PHASE 1 — определить систему

Выполни минимум:

```bash
uname -a
cat /etc/os-release
uname -m
pwd
git --version || true
docker --version || true
docker compose version || true
node --version || true
npm --version || true
godot --version || true
java -version || true
adb version || true
```

Автоустановщик рассчитан на:

- Arch / CachyOS / Manjaro;
- Debian / Ubuntu / Linux Mint;
- Linux x86_64.

Если система отличается — не запускай несовместимые команды вслепую. Адаптируй setup по официальной документации.

---

# PHASE 2 — установить всё необходимое

Если окружение ещё не готово, из starter-pack выполни:

```bash
chmod +x scripts/*.sh
./scripts/setup_dev_env.sh
```

Он должен подготовить:

- Git;
- curl/wget/jq/rsync/zip/unzip;
- Docker Engine;
- Docker Compose;
- Node.js LTS;
- Godot 4.7.1 stable;
- Godot export templates;
- OpenJDK 17;
- Android command-line tools;
- Android Platform Tools;
- Android Build Tools;
- Android Platform;
- CMake;
- Android NDK.

После установки:

```bash
source "$HOME/.config/deadworld/env.sh" 2>/dev/null || true
./scripts/check_env.sh
```

Не меняй pinned Godot 4.7.1 на dev/beta/RC без технической необходимости.

Если Docker group membership ещё не активна и нужен полноценный logout/login — сообщи мне только это действие и после него продолжи.

---

# PHASE 3 — clone/overlay существующего repo

Если ты работаешь из распакованного starter-pack:

```bash
./scripts/prepare_repo.sh "$HOME/Projects/deadworld"
cd "$HOME/Projects/deadworld"
```

После этого вся дальнейшая работа ведётся только из:

```text
~/Projects/deadworld
```

Если ты уже внутри правильного clone — не создавай второй.

Проверь:

```bash
git remote -v
git branch --show-current
git status
```

Допустимый origin:

```text
https://github.com/syb1v/deadworld
```

или:

```text
git@github.com:syb1v/deadworld.git
```

Не удаляй существующий `LICENSE`.

---

# PHASE 4 — preflight + scaffold commit

В рабочем repo:

```bash
./scripts/preflight_repo.sh
./scripts/check_env.sh
git check-ignore .env
git status
```

Проверь, что `.env` ignored и не содержит staged secrets.

Затем:

```bash
git add .
git diff --cached --stat
git diff --cached --name-only
```

Если `.env` staged — исправь это до commit.

Сделай:

```bash
git commit -m "chore: bootstrap deadworld project"
git push -u origin main
```

Если push требует GitHub authentication, попроси меня только завершить auth. После этого повтори push и продолжи.

**После scaffold push не заканчивай работу.**

---

# PHASE 5 — реализовать DAY 1

Теперь строго выполнить:

```text
docs/prompts/DAY_01.md
```

## Day 1 Definition of Done

Два Godot-клиента должны:

1. подключаться к одному backend;
2. проходить guest/device authentication;
3. открывать realtime connection;
4. входить в один authoritative `world`;
5. иметь разные player IDs;
6. видеть друг друга;
7. отправлять movement input, а не trusted final position;
8. получать authoritative position/state;
9. интерполировать remote player;
10. корректно удалять disconnected player.

## Stack Day 1

Используй:

- Godot 4.7.1 stable;
- GDScript;
- Nakama;
- PostgreSQL;
- TypeScript Nakama runtime;
- Docker Compose.

Версию Nakama выбери осознанно по актуальной официальной документации и **зафиксируй**, чтобы клиент/runtime API совпадали.

## Network invariant

Клиент отправляет намерение:

```text
direction/input
```

Сервер решает:

```text
authoritative position
```

Нельзя доверять клиентскому:

```text
final position
speed
damage
inventory state
```

## Обязательная movement validation

Server должен безопасно обрабатывать:

- NaN/Infinity;
- отсутствующие поля;
- значения вне диапазона;
- vector magnitude > 1;
- слишком частые input messages;
- неизвестный/плохой payload.

Forged vector не должен давать speed hack.

## Сегодня запрещено

Не реализовывать:

- zombies;
- loot;
- inventory;
- combat;
- bases;
- clans;
- quests;
- economy;
- vehicles;
- hunger/thirst;
- production art;
- Redis;
- Kafka;
- Kubernetes;
- microservices.

---

# PHASE 6 — реально проверить Day 1

Не ограничивайся словами “should work”.

Запусти все доступные проверки.

Минимум:

- Docker Compose config validation;
- backend start + health;
- TypeScript typecheck/build;
- server tests;
- Godot headless project parse/start;
- auth;
- socket connection;
- join world;
- two simultaneous clients или эквивалентный integration test;
- malformed movement test;
- disconnect cleanup.

Если GUI доступен — реально запусти два Godot process.

Если GUI недоступен — создай разумный headless/integration test для protocol/backend и дай точный manual GUI test, но не выдавай его за уже выполненный GUI test.

---

# PHASE 7 — привести документацию к факту

После реализации обнови только то, что реально изменилось:

```text
README.md
docs/ARCHITECTURE.md
docs/PROTOCOL.md
docs/DEV_SETUP.md
```

Makefile должен получить реальные удобные команды, например:

```text
make up
make down
make logs
make test
make client
```

Не оставляй команды, которые не существуют.

---

# PHASE 8 — commit/push Day 1

Перед commit:

```bash
git status
git diff
git diff --check
git check-ignore .env
```

Повтори критичные tests.

Затем:

```bash
git add .
git diff --cached --name-only
git commit -m "feat: add authoritative multiplayer movement"
git push
```

Никакого force push.

---

# PHASE 9 — отчёт

После выполнения дай короткий отчёт:

## Environment
Установленные версии.

## Repository
- path;
- origin;
- branch;
- scaffold commit hash;
- Day 1 commit hash;
- push status.

## Day 1
Что **реально** работает.

## Tests
Какие команды ты действительно запускал и результат.

## My manual test
Дай мне самые короткие шаги для самостоятельного запуска backend + двух клиентов.

## Known limitations
Только фактические.

В конце:

```text
Ready for Day 2: shared authoritative zombies.
```

**Day 2 не начинай без подтверждения Day 1.**

---

# Жёсткие запреты

Никогда не:

- force-push;
- уничтожай remote history;
- удаляй `LICENSE`;
- коммить `.env`/credentials;
- делай client authoritative;
- выдумывай API;
- говори “готово”, если test не запускался;
- начинай Day 2 раньше времени;
- раздувай scope.

Начинай сейчас: прочитай документы, проверь систему и выполняй Phase 1 → Phase 8.
