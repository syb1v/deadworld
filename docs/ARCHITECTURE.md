# Architecture

## 1. MVP topology

```text
Windows / Linux / Android
          │
          │ HTTP + realtime socket
          ▼
       Nakama
   ┌──────┴────────┐
   │ authoritative │
   │ world runtime │
   └──────┬────────┘
          │
          ▼
     PostgreSQL
```

На MVP один authoritative world/session может обслуживать весь test world.

Не строим production MMO cluster раньше времени.

## 2. Responsibilities

### Godot client

Отвечает за:

- input;
- rendering;
- UI;
- local presentation;
- interpolation;
- optional prediction;
- sound/effects.

Не отвечает за окончательное gameplay state.

### Nakama

На MVP:

- auth;
- sessions;
- socket/realtime;
- authoritative world runtime;
- storage/backend primitives.

### TypeScript runtime

Отвечает за:

- authoritative player state;
- validation;
- zombie simulation;
- combat decisions;
- inventory mutations;
- shared loot;
- persistence coordination.

### PostgreSQL

Persistent state.

Клиент **никогда** не подключается к PostgreSQL напрямую.

## 3. Trust boundary

```text
UNTRUSTED
┌────────────────┐
│     Client     │
└───────┬────────┘
        │ intention/input
        ▼
TRUST BOUNDARY
┌────────────────┐
│     Server     │
│ validation     │
│ simulation     │
│ persistence    │
└────────────────┘
```

## 4. Tick

MVP target:

```text
server tick: 15 Hz
render:      60+ FPS desktop
mobile:      30/60 FPS target
```

15 Hz означает ~66.7 ms на tick, но server code должен иметь запас и не использовать весь budget стабильно.

## 5. Movement

Wire:

```text
client -> INPUT_MOVE(direction, sequence)
server -> authoritative simulation
server -> PLAYER_SNAPSHOT
client -> local correction / remote interpolation
```

Не:

```text
client -> "my position is X/Y, trust me"
```

## 6. Entity model

Минимальные типы:

```text
Player
Zombie
WorldItem
Container
```

ID форматы:

```text
player:<uuid>
zombie:<world-id>
item:<uuid>
container:<world-id>
```

## 7. Persistence classes

### Persistent

- player inventory;
- player progression;
- player equipment;
- bases позже;
- persistent containers;
- unique/important world item state.

### Snapshot / recoverable

- player position;
- health;
- world object states.

### Ephemeral

- current attack animation;
- bullet visual;
- temporary noise event;
- UI state.

## 8. Inventory invariant

Любой item instance может иметь **одного владельца/местоположение**:

```text
WORLD
CONTAINER:<id>
PLAYER:<id>:INVENTORY
PLAYER:<id>:EQUIPPED
DESTROYED
```

Серверная mutation должна атомарно переводить item из A в B.

## 9. Container concurrency

Container имеет `version`.

Mutation request несёт expected version.

Если версии расходятся:

- server не применяет stale mutation;
- отправляет актуальный state/version;
- клиент пересинхронизируется.

## 10. Interest Management — post-MVP

Когда мир вырастет:

```text
player
  │
  └─ Area of Interest
       ├ nearby players
       ├ nearby zombies
       ├ nearby items
       └ relevant world events
```

Клиент не получает весь shard.

## 11. Zombie simulation LOD — post-MVP

### Near
full AI/pathfinding/combat

### Mid
lower tick / simplified movement

### Far
aggregate/statistical simulation

## 12. MMO scaling — future

Не один процесс на 5000 человек.

```text
EU-1
├ Region A -> process A
├ Region B -> process B
├ Region C -> process C
└ Instances
```

Понадобятся:

- AOI;
- zone ownership;
- handoff token;
- transfer protocol;
- no-double-ownership invariant;
- cross-zone events.

Это **не MVP**.

## 13. Dependency policy

Версии фиксируются.

Engine/API upgrades:

1. отдельный change;
2. backup/branch;
3. build;
4. smoke test;
5. protocol compatibility check.

Не смешивать engine upgrade с новой gameplay feature.

## 14. Observability

MVP:

- structured server logs;
- Docker healthchecks;
- clear errors.

Post-MVP:

- online_players;
- server_tick_ms;
- entities_per_zone;
- socket_messages/sec;
- persistence latency;
- disconnect rate;
- Prometheus/Grafana/Loki/Sentry при необходимости.

## 15. Architecture rule

> Не добавлять компонент, пока нельзя назвать конкретную текущую проблему, которую он решает.

## 16. Day 1 implementation

- Nakama `3.40.0` authoritative match, fixed at 15 Hz.
- PostgreSQL `17.6` stores Nakama accounts and active main-world lookup state.
- Godot `4.7.1` with Nakama Godot SDK `3.4.0` handles device auth, realtime input and interpolation.
- The client sends movement intent; the runtime owns velocity and position.

## 17. Day 2 zombie simulation

- The world creates three stable server-owned zombie IDs.
- At each 15 Hz tick, each living zombie selects the nearest living player in detection range.
- The server owns `IDLE`, `CHASE`, `ATTACK`, `DEAD`, position, target, HP, damage and attack cooldown.
- Zombie state is included in the authoritative world snapshot, so join and reconnect receive current state without client reconstruction.
- One deterministic corpse fixture verifies `DEAD` replication until server-validated combat is introduced on Day 4.
- Day 2 does not add client damage requests, inventory, loot or weapons.
