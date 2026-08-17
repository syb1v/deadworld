# Coding Agent Prompt — Day 1

Ты — lead game/network engineer проекта Project Deadworld.

Перед началом:

1. прочитай `AGENTS.md`;
2. прочитай `docs/MVP.md`;
3. прочитай `docs/ARCHITECTURE.md`;
4. прочитай `docs/PROTOCOL.md`;
5. осмотри repository tree;
6. используй API фактически установленных версий зависимостей.

## Goal

К концу Day 1 два Godot-клиента подключаются к одному backend, проходят guest/device authentication, входят в один authoritative world, появляются и видят движение друг друга.

## Stack

- Godot 4.7.1 stable
- GDScript client
- Nakama
- TypeScript runtime
- PostgreSQL
- Docker Compose
- Caddy только если нужен уже на этом шаге

## Scope

### Repository

Подготовь рабочие:

```text
client/
server/
shared/
infra/
```

Не уничтожай существующую документацию.

### Infra

Создай:

- Docker Compose;
- PostgreSQL;
- Nakama;
- persistent DB volume;
- `.env`-driven configuration;
- healthchecks;
- понятные команды запуска/логов.

Локальный Day 1 может работать без TLS.

### Server

Реализуй один authoritative test world.

Нужно:

- TypeScript runtime;
- player join/leave;
- unique player state;
- fixed 15 Hz tick;
- `INPUT_MOVE`;
- authoritative velocity/position integration;
- input validation;
- server snapshot/state broadcast;
- disconnect cleanup;
- structured logs.

### Client

Нужно:

- minimal Godot project;
- boot/main scene;
- Network autoload;
- auth;
- socket connect;
- join world;
- LocalPlayer;
- RemotePlayer;
- WASD;
- movement input send;
- authoritative correction;
- remote interpolation;
- connection status;
- placeholder visuals.

## Critical movement rule

Клиент отправляет vector/input, не trusted final position.

Сервер:

- reject/non-crash malformed input;
- clamp components;
- normalize magnitude;
- enforce max speed.

## Explicitly do NOT implement

- zombies;
- inventory;
- loot;
- combat;
- crafting;
- bases;
- clans;
- quests;
- vehicles;
- hunger/thirst;
- production art.

## Definition of Done

- backend запускается одной документированной командой;
- healthchecks проходят;
- два client instances подключаются без правки исходников между запусками;
- разные player IDs;
- один world;
- оба видят друг друга;
- movement replicated;
- server authoritative;
- speed-hack style input не даёт лишнюю скорость;
- disconnect удаляет remote player;
- README/Makefile обновлены под фактический запуск;
- secrets не попали в Git.

## Workflow

Перед кодом выведи:

1. current state;
2. краткий план;
3. files to create/change;
4. risks.

После реализации:

1. запусти доступные tests/build/lint/docker checks;
2. исправь ошибки;
3. выведи exact commands;
4. дай manual two-client test;
5. перечисли known limitations;
6. назови Day 2 как следующий task, но не реализуй его.
