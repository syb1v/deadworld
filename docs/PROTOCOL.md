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

## 6. ITEM_PICKUP — planned Day 3

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

## 7. CONTAINER_MUTATE — planned Day 3

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

## 8. INPUT_ATTACK — planned Day 4

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

Точные числа устанавливаются после первой реализации и нагрузочного теста.
