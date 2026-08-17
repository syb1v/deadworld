# Network Protocol

> **PROTOCOL_VERSION = 1**

Документ описывает логический wire contract. Фактическая сериализация может на MVP быть JSON/bytes через Nakama, но semantics остаются стабильными.

## 1. Principles

- server authoritative;
- messages versioned;
- unknown opcode ignored/rejected safely;
- malformed payload never crashes server;
- client sequence numbers where useful;
- no trusted final damage/position/inventory state from client.

## 2. Logical opcodes

Зарезервированный draft:

```text
1   INPUT_MOVE
2   INPUT_AIM
3   INPUT_ATTACK
4   INTERACT

10  PLAYER_SNAPSHOT
11  ENTITY_SPAWN
12  ENTITY_DESPAWN

20  DAMAGE_EVENT
21  DEATH_EVENT
22  RESPAWN_EVENT

30  ITEM_PICKUP
31  ITEM_DROP
32  INVENTORY_MOVE
33  INVENTORY_SNAPSHOT

40  CONTAINER_OPEN
41  CONTAINER_MUTATE
42  CONTAINER_SNAPSHOT

50  ERROR_EVENT
51  SERVER_NOTICE
```

Day 1 реализует только необходимый минимум. Не создавать пустые handlers на всё сразу.

## 3. Envelope

Концептуально:

```json
{
  "protocol": 1,
  "opcode": 1,
  "sequence": 42,
  "payload": {}
}
```

Если Nakama transport уже несёт opcode отдельно, не дублировать его без причины.

## 4. INPUT_MOVE

Client -> Server

```json
{
  "x": 0.7,
  "y": -0.3,
  "sequence": 42
}
```

Validation:

- finite numeric values;
- x/y clamped to [-1, 1];
- vector normalized if magnitude > 1;
- rate limited;
- impossible/out-of-order sequences handled safely;
- server applies authoritative speed.

Клиент не передаёт final position как source of truth.

## 5. PLAYER_SNAPSHOT

Server -> Client

Пример:

```json
{
  "tick": 9182,
  "players": [
    {
      "id": "player:...",
      "x": 10.2,
      "y": 3.9,
      "vx": 1.2,
      "vy": 0.0,
      "state": "move"
    }
  ]
}
```

Optimization приходит после корректности.

## 6. ITEM_PICKUP — Day 3

Client:

```json
{
  "item_instance_id": "item:...",
  "expected_world_version": 12
}
```

Server validates:

- item exists;
- player close enough;
- item is still WORLD;
- inventory has capacity;
- expected version acceptable.

Server commits:

```text
WORLD -> PLAYER inventory
```

ровно один раз.

Implemented limits and result:

- payload <= 512 bytes;
- max 10 interaction messages/sec/player;
- interaction distance <= 96 world units;
- inventory capacity: 8 instances;
- successful pickup increments `world_version`;
- rejection is sent only to the requester as opcode `50`.

`ITEM_DROP` (`31`) contains `item_instance_id`. The server verifies inventory ownership, removes the instance from inventory and creates it at the authoritative player position.

## 7. CONTAINER_MUTATE — Day 3

```json
{
  "container_id": "container:17",
  "expected_version": 8,
  "operation": "take",
  "item_instance_id": "item:..."
}
```

Server:

1. validate proximity;
2. validate version;
3. validate ownership;
4. apply atomic mutation;
5. increment container version;
6. broadcast/return updated state.

Implemented operations are `take` and `deposit`. Exactly one mutation can consume a given container version; success increments `container.version`.

`INVENTORY_SNAPSHOT` (`33`) is sent only to its owning presence. Public world snapshots include `world_version`, `world_items`, and generic `containers`, but never another player's inventory.

## 8. INPUT_ATTACK — Day 4

Client сообщает input:

```json
{
  "weapon_slot": 1,
  "aim_x": 0.8,
  "aim_y": 0.2,
  "sequence": 101
}
```

Server проверяет:

- player alive;
- weapon owned/equipped;
- cooldown;
- ammo;
- range;
- authoritative position;
- target/hit;
- damage.

Клиент никогда не сообщает:

```json
{"target":"zombie:12","damage":999999}
```

как доверенный результат.

Implemented semantics:

- `weapon_slot` is a zero-based authoritative inventory slot;
- aim is finite, non-zero and normalized by the server;
- sequence must increase;
- baseball bat: 15 damage, 54 range, 8-tick cooldown;
- pistol: 20 damage, 260 range, 5-tick cooldown;
- pistol has a server-owned six-round magazine stored on the pistol item instance;
- `INPUT_RELOAD` (`5`) contains `weapon_slot` and increasing `sequence`; a successful reload consumes loose `pistol_ammo` instances up to magazine capacity;
- `RELOAD_EVENT` (`24`) returns the pistol's authoritative post-mutation slot because removing loose ammo can compact inventory slots;
- each accepted pistol attack consumes one magazine round, including a valid miss;
- an empty magazine rejects the attack and does not emit `ATTACK_EVENT` (`23`);
- accepted melee/pistol attacks emit `ATTACK_EVENT`, which clients use for presentation; client input alone never starts an authoritative-looking attack effect;
- hit selection uses authoritative player/zombie positions and an aim cone;
- `DAMAGE_EVENT` (`20`) reports the applied result; `DEATH_EVENT` (`21`) and `RESPAWN_EVENT` (`22`) report lifecycle transitions.

Zombie attacks can now reduce player HP to zero. A dead player cannot move, attack, reload or mutate inventory, drops every inventory instance at the death position, and respawns after 45 ticks (3 seconds) with 100 HP at its server-owned spawn. The world contains three fixed zombies; dead zombies remain dead and are not replaced.

## 9. Errors

Server error shape:

```json
{
  "code": "STALE_CONTAINER_VERSION",
  "message": "Container state changed",
  "request_sequence": 123
}
```

Production UI не обязан показывать raw internal message пользователю.

## 10. Compatibility

Если wire semantics ломаются:

```text
PROTOCOL_VERSION += 1
```

Client при connect сообщает/имеет:

```text
CLIENT_BUILD
PROTOCOL_VERSION
CONTENT_VERSION
```

Несовместимый клиент отклоняется понятной ошибкой.

## 11. Security limits — to define during implementation

Обязательно определить:

- max message size;
- max movement messages/sec;
- max interaction requests/sec;
- max chat size позже;
- timeout;
- malformed packet strategy.

Day 1 limits:

- max movement payload: 256 bytes;
- max accepted movement messages: 30/sec/player;
- client input send target: 20 Hz;
- server simulation/snapshot tick: 15 Hz;
- authoritative speed: 180 world units/sec;
- malformed, unknown, non-finite and stale-sequence movement is ignored safely.

## 12. Day 2 zombie snapshot

`PLAYER_SNAPSHOT` now also includes server-owned zombies:

```json
{
  "zombies": [
    {
      "id": "zombie:main-1",
      "x": 420,
      "y": 360,
      "vx": 0,
      "vy": 0,
      "hp": 30,
      "state": "IDLE",
      "target_id": ""
    }
  ]
}
```

Valid states are `IDLE`, `CHASE`, `ATTACK`, and `DEAD`. Clients cannot set zombie target, position, HP, state, attack damage, or cooldown. This is an additive protocol v1 change.
