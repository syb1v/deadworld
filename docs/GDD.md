# PROJECT DEADWORLD — GDD + Technical Design + MVP Roadmap

> **Статус:** рабочий дизайн-документ v0.1  
> **Жанр:** persistent online survival RPG / MMO-lite → MMORPG  
> **Рабочее название:** `Project Deadworld` — временное.  
> **Главный ориентир по ощущению:** медленный, системный, опасный изометрический zombie-survival в духе Project Zomboid, но с постоянным онлайновым миром, кроссплатформой, кланами, экономикой, PvE/PvP и MMO-системами.  
> **Цель MVP:** за 7 дней получить не «готовую MMO», а настоящий сетевой vertical slice, который можно дать 2–5 друзьям: сервер в интернете, несколько игроков, общие зомби, общий лут, бой, инвентарь, смерть/респавн и сохранение прогресса.

---

## 1. Концепция в одном предложении

**Project Deadworld — это Zomboid-like survival, перенесённый в постоянный кроссплатформенный онлайн-мир, где игроки добывают ресурсы, переживают зомби-апокалипсис, строят убежища, формируют сообщества, торгуют, сражаются и постепенно меняют состояние мира.**

Игра не должна быть прямым клоном Project Zomboid, Last Day on Earth или Zombix. Мы берём жанровые идеи и строим собственную игру: другие ассеты, UI, карты, тексты, баланс, лор, брендинг и код.

---

## 2. Что игрок должен чувствовать

### 2.1. Опасность

Выход из базы должен иметь цену. Даже прокачанный персонаж может погибнуть из-за плохого решения, шума, нехватки патронов, травмы или другого игрока.

### 2.2. Ценность добычи

Найденные антибиотики, хороший рюкзак, канистра бензина, генератор, магазин к оружию или редкий инструмент должны реально радовать.

### 2.3. Живой мир

Игрок должен видеть следы других людей:

- открытые двери;
- разграбленные магазины;
- выбитые окна;
- трупы;
- брошенные автомобили;
- укреплённые дома;
- игроковые поселения;
- радиообъявления;
- торговые точки;
- клановые территории;
- других игроков в мире, а не только в меню.

### 2.4. Самогенерирующиеся истории

Нужны ситуации вроде:

> Игрок пошёл за лекарствами → услышал стрельбу → помог двум людям отбиться от орды → один погиб → второй попросил довезти его до safe-zone → по дороге кончился бензин → пришлось пережидать ночь в фермерском доме.

Это важнее ста одинаковых квестов «убей 10 зомби».

---

## 3. Игровые столпы

### Survival first

MMO-системы не должны отменять survival. В будущем важны:

- голод;
- жажда;
- усталость;
- ранения;
- кровотечение;
- инфекция;
- температура;
- вес;
- шум;
- освещение;
- состояние одежды;
- состояние оружия;
- боеприпасы;
- медицина.

### Persistent world

Сервер продолжает существовать после выхода игрока. Сохраняются персонажи, контейнеры, базы, важные предметы, двери/окна, транспорт, генераторы, клановые объекты, экономика и глобальные события.

### Server authoritative

Клиент отправляет **намерение**, а не результат.

Плохо:

```text
client: «Я попал и нанёс 120 damage»
server: «Окей»
```

Правильно:

```text
client: INPUT_FIRE + aim_angle + weapon_slot
server:
  проверяет оружие
  проверяет ammo
  проверяет cooldown
  проверяет позицию
  выполняет hit test
  считает damage
  уменьшает ammo
  создаёт noise event
  рассылает результат
```

### Social survival

Игроки полезны друг другу. Развитие skill-based, а не жёсткие классы:

- врач;
- механик;
- строитель;
- электрик;
- оружейник;
- повар;
- фермер;
- разведчик.

### Risk vs Reward

| Тип зоны | Опасность | PvP | Лут |
|---|---:|---:|---:|
| Safe settlement | низкая | OFF | базовый |
| Suburbs | средняя | ограниченный | нормальный |
| Downtown | высокая | условный/ON | редкий |
| Dead Zone | экстремальная | ON | лучший |
| Lab/Bunker | экстремальное PvE | по правилам | уникальный |

---

## 4. Чем игра НЕ должна стать

Не делаем:

- autoplay;
- auto-path-to-quest;
- energy system;
- обязательные дейлики как основную мотивацию;
- VIP +500% damage;
- платное оружие с лучшими характеристиками;
- 20 валют;
- «легендарный автомат +726»;
- отдельную одиночную базу в вакууме, которой нет в общем мире;
- тонны NPC-квестов до появления работающего survival ядра;
- микросервисы и Kubernetes в первой версии «потому что MMO».

---

## 5. Платформы

### MVP

1. Windows x86_64.
2. Android arm64.
3. Linux — если экспорт не мешает сроку.

### После MVP

4. iOS/iPadOS.
5. macOS.
6. Steam.
7. Google Play.
8. App Store.

Архитектура gameplay одна для всех платформ. Различаются только input, UI scaling, platform SDK и графические профили.

---

## 6. Визуальное направление

Рекомендуется **2D/2.5D isometric**:

- камера сверху под углом;
- tile/grid-based world;
- 2D sprites или простые 3D-модели с изометрической подачей;
- динамический свет;
- ограниченная видимость;
- погодные эффекты позже.

Почему не full 3D на старте: оно резко увеличивает стоимость моделей, анимаций, LOD, физики, мобильной оптимизации, сетевой синхронизации и окружения. Для маленькой команды выгоднее вкладываться в системность.

---

## 7. Управление

### Desktop

- WASD — движение;
- Shift — бег;
- Ctrl — stealth/crouch;
- мышь — направление;
- LMB — attack;
- RMB — aim/context;
- E — interact;
- I — inventory;
- M — map;
- 1–9 — hotbar;
- R — reload.

### Mobile

Слева — movement stick. Справа:

- aim stick/drag;
- attack;
- interact;
- sprint;
- crouch;
- reload;
- context button.

Обе схемы должны вызывать одинаковые gameplay actions.

---

## 8. Core gameplay loop

```text
Убежище
   ↓
Подготовка
   ↓
Выбор цели
   ↓
Экспедиция
   ↓
Исследование
   ↓
Лут / бой / встреча с игроками
   ↓
Решение: рисковать дальше или возвращаться
   ↓
Возвращение
   ↓
Лечение / хранение / крафт / торговля
   ↓
Развитие персонажа и базы
   ↓
Более опасная экспедиция
```

Каждые 30–90 секунд желательно давать маленькое решение: зайти в дом, обойти зомби, потратить патрон, взять тяжёлый предмет, помочь человеку или спрятаться.

---

## 9. Мир

### MVP-мир

Не строим infinite procedural world за неделю.

Достаточно:

- одна карта 128×128 или 256×256 условных тайлов;
- 6–10 зданий/помещений;
- дорога;
- лес/пустырь;
- магазин;
- клиника;
- склад;
- безопасная spawn-точка;
- 20–50 активных зомби.

### Будущий мир

```text
World Shard
├ Region A
│  ├ Chunk 0,0
│  ├ Chunk 0,1
│  └ Chunk 1,0
├ Region B
└ Region C
```

Размер chunk/region выбирается после profiling, а не навсегда в GDD.

---

## 10. Interest Management

Клиент не должен получать весь мир сервера.

```text
. . . . . . . . .
. . X X X X X . .
. . X X X X X . .
. . X X P X X . .
. . X X X X X . .
. . X X X X X . .
. . . . . . . . .
```

`P` — игрок. Сервер реплицирует только relevant entities рядом:

- игроков;
- зомби;
- контейнеры;
- двери;
- транспорт;
- world items;
- projectiles/events.

Никогда не отправлять клиенту позиции всех игроков мира или содержимое всех контейнеров заранее.

---

## 11. Zombie AI

Состояния полной версии:

```text
IDLE
WANDER
INVESTIGATE_SOUND
SEARCH
CHASE
ATTACK
STUN
DOWNED
DEAD
```

Stimuli:

- визуальный контакт;
- шаги;
- бег;
- разбитое окно;
- выстрел;
- сигнализация;
- машина;
- генератор;
- крик.

### AI LOD в будущем

**Near:** полный AI/pathfinding/combat.  
**Mid:** упрощённая логика и редкий tick.  
**Far:** агрегированная статистическая симуляция.

### MVP

Только:

```text
IDLE → CHASE → ATTACK → DEAD
```

---

## 12. Игрок и survival stats

Полная модель:

```text
health
stamina
hunger
thirst
fatigue
temperature
carry_weight
infection
bleeding
pain
```

MVP минимум:

```text
health
stamina
carry_weight
```

Если сроки позволяют — hunger/thirst.

---

## 13. Система тела — после MVP

Позже вместо одного HP:

```text
Body
├ Head
├ Torso
├ Left Arm
├ Right Arm
├ Left Hand
├ Right Hand
├ Left Leg
├ Right Leg
├ Left Foot
└ Right Foot
```

У части тела:

```text
condition
bleeding
wound
fracture
burn
bite
infection
bandage
pain
```

Повреждение ноги влияет на скорость, руки — на aim/reload, кровотечение требует лечения и т.д.

---

## 14. Предметы

Все предметы data-driven.

```json
{
  "id": "food_canned_beans",
  "name": "Canned Beans",
  "category": "food",
  "weight": 0.45,
  "stack_size": 4,
  "hunger_restore": 25,
  "rarity": "common"
}
```

Категории:

- food;
- drink;
- medicine;
- melee;
- firearm;
- ammo;
- magazine;
- clothing;
- backpack;
- tool;
- material;
- component;
- vehicle_part;
- building;
- electronics.

MVP: 10–15 предметов.

---

## 15. Item Definition и Item Instance

Это разные сущности.

**Definition:**

```text
pistol_9mm
damage=18
weight=1.1
```

**Instance:**

```text
uuid=<unique>
definition=pistol_9mm
durability=63
magazine_rounds=7
```

Уникальные вещи обязаны иметь instance ID для защиты от duplication.

---

## 16. Инвентарь

MVP — простой slot inventory, не Tetris-grid.

Slot:

```text
slot_id
item_instance_id/item_id
quantity
durability
metadata
```

Операции:

```text
MOVE
SPLIT
STACK
DROP
PICKUP
EQUIP
UNEQUIP
USE
```

Все операции валидирует сервер.

---

## 17. Контейнеры и shared loot

Контейнеры:

- шкаф;
- холодильник;
- аптечка;
- ящик;
- багажник;
- труп;
- stash.

Каждый контейнер:

```text
container_id
world_position
loot_table_id
slots
version
```

### Versioning

Если два игрока видят `version=12`, первый забирает предмет → сервер меняет version на 13. Запрос второго со старой version отклоняется или пересчитывается. Это один из базовых способов избежать duplication races.

---

## 18. Loot tables

```text
pharmacy_basic
├ bandage        40%
├ painkiller     20%
├ medkit          5%
└ empty          35%
```

В будущем таблицы учитывают building, room, region, world age, scarcity и event modifiers.

---

## 19. Combat

### Melee

Сервер проверяет:

- дистанцию;
- угол;
- stamina;
- cooldown;
- weapon;
- target;
- line of sight.

### Firearms

Клиент отправляет:

```text
INPUT_FIRE
aim_angle
weapon_slot
client_sequence
```

Сервер:

1. проверяет оружие;
2. ammo;
3. rate of fire;
4. состояние игрока;
5. authoritative position;
6. hit/raycast;
7. damage;
8. ammo decrement;
9. noise event;
10. replication.

MVP: fists, bat, pistol, один тип ammo.

---

## 20. Шум

Будущая ключевая система.

```text
NoiseEvent {
  position,
  radius,
  strength,
  type,
  timestamp
}
```

Баланс-пример:

| Событие | Условный радиус |
|---|---:|
| шаг | 3 |
| бег | 7 |
| окно | 15 |
| melee | 8 |
| pistol | 70 |
| shotgun | 120 |
| alarm | 200+ |

Числа placeholder, балансируются позже.

---

## 21. Смерть

Основной MMO-режим — не обязательный full permadeath.

Базовая модель:

- инвентарь остаётся на теле полностью или частично;
- skills сохраняются;
- respawn в safe zone/bed;
- временный debuff;
- тело существует ограниченное время.

Позже отдельный Hardcore shard с permadeath.

---

## 22. Прокачка

Без Warrior/Mage.

```text
Combat
├ Melee
├ Pistols
├ Rifles
└ Shotguns

Survival
├ Foraging
├ Cooking
├ Medicine
├ Farming
└ Hunting

Technical
├ Mechanics
├ Electricity
├ Construction
└ Weaponsmithing
```

Нужны diminishing returns и защита от тупого «бить стену 50 000 раз ради XP».

---

## 23. Базы

В недельный MVP база не обязательна.

Если есть запас времени:

- placeable chest;
- campfire;
- simple wall.

После MVP:

- foundation;
- wall;
- door;
- window;
- roof;
- bed;
- storage;
- workbench;
- generator;
- lights;
- water collector;
- farming plots.

---

## 24. Электричество и вода

После MVP.

```text
Generator
   ↓
Cable Network
   ├ Fridge
   ├ Light
   └ Workbench
```

Вода:

- taps;
- barrels;
- rain collectors;
- pumps;
- purification.

Централизованные utilities могут деградировать со временем жизни сервера.

---

## 25. Транспорт

После стабильного сетевого ядра.

Первая машина:

- sedan;
- fuel;
- health;
- trunk.

Позже:

- battery;
- engine;
- tires;
- doors/windows;
- repair;
- hotwire;
- noise;
- collision;
- passengers.

---

## 26. PvP

### Safe Zone

PvP OFF.

### Normal Zone

Ограниченное/consensual PvP + crime/self-defense rules.

### Dead Zone

PvP ON, лучший loot.

### Hardcore shard

Отдельные агрессивные правила.

---

## 27. Crime / Reputation — future

```text
reputation
crime_score
faction_relation
wanted_level
```

Убийство мирного игрока может создавать bounty, запрещать вход в settlement и повышать wanted level.

---

## 28. MMO-системы

Добавляются только после работающего survival.

- friends;
- party;
- proximity chat;
- text chat;
- clans;
- clan roles;
- clan storage;
- trading;
- market;
- player contracts;
- mail;
- settlements;
- territory;
- world bosses;
- caravans;
- player shops.

---

## 29. Экономика

Варианты валют:

1. barter;
2. settlement credits;
3. faction currency;
4. rare pre-collapse cash.

Money sinks:

- repair;
- fuel;
- medicine;
- auction fee;
- taxes;
- base upkeep;
- crafting fee;
- travel.

Не делать «универсальное золото решает всё» автоматически.

---

## 30. World events

Примеры:

- helicopter crash;
- military convoy;
- horde migration;
- supply drop;
- power-station restart;
- distress signal;
- infected boss;
- storm;
- quarantine breach.

Событие должно менять поведение игроков, а не быть просто кнопкой «получить награду».

---

## 31. Уникальные фичи проекта

Чтобы игра не была «просто Zomboid Online»:

### Player settlements
Игроки совместно развивают безопасные поселения.

### Dynamic hordes
Орды мигрируют и меняют маршруты.

### Radio
Частоты, distress signals, координаты, объявления.

### Player contracts
Например: «Нужен механик, 200 credits, починить генератор».

### World infrastructure
Игроки восстанавливают электростанцию, вышку связи, водозабор, мост — и меняют регион.

### Logistics
Грузы, машины, караваны, escort и засады становятся отдельным gameplay loop.

---

## 32. Монетизация — только если понадобится

Нормально:

- cosmetics;
- skins;
- emotes;
- cosmetic base decorations;
- supporter pack;
- cosmetic season track.

Не делать:

- лучшее оружие за деньги;
- ammo за деньги;
- revive currency как обязательную;
- XP x5;
- защиту от PvP за деньги.

---

## 33. Главный продуктовый принцип

> Сначала доказываем, что три человека могут весело выживать на одном persistent сервере. Потом масштабируем до 30. Потом до 300. Не наоборот.


# 34. Технический стек MVP

## Client

**Godot 4.x stable + GDScript.**

Почему:

- одна кодовая база;
- быстрое прототипирование;
- хороший 2D pipeline;
- desktop/mobile export;
- удобно для AI-assisted разработки;
- можно позже иметь отдельный dedicated/headless export, если понадобится игровой zone server на Godot.

## Backend

**Nakama + TypeScript authoritative runtime.**

Использовать для:

- authentication;
- sessions;
- realtime socket;
- authoritative match;
- storage;
- social primitives в будущем.

## Database

**PostgreSQL.**

## Reverse proxy

**Caddy** для TLS и проксирования.

## Deployment

**Docker Compose.**

## Monitoring

В первую неделю:

- container logs;
- healthchecks;
- structured server logs.

После MVP:

- Prometheus;
- Grafana;
- Loki/Sentry/OpenTelemetry при необходимости.

---

## 35. Архитектура недельного MVP

```text
Windows Client ─┐
Android Client ─┼── HTTPS/WebSocket ── Caddy ── Nakama ── PostgreSQL
Linux Client   ─┘                         │
                                          └─ Authoritative World Match
```

Один authoritative match представляет один тестовый мир.

Это не финальная MMO-архитектура, но она позволяет доказать самое важное: серверное состояние, несколько игроков, shared AI, shared loot и persistence.

---

## 36. Архитектура после MVP

```text
                     ┌──────────────┐
 Windows ────────────┤              │
 Linux ──────────────┤ Edge / HTTPS │
 Android ────────────┤ / WebSocket  │
 iOS ────────────────┤              │
                     └──────┬───────┘
                            │
                     ┌──────▼──────┐
                     │   Nakama    │
                     │ Auth        │
                     │ Accounts    │
                     │ Friends     │
                     │ Parties     │
                     │ Clans       │
                     │ Chat        │
                     └──────┬──────┘
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
   ┌──────▼──────┐   ┌──────▼──────┐  ┌─────▼─────┐
   │ Zone Server │   │ Zone Server │  │ Instance  │
   │      A      │   │      B      │  │ Server    │
   └──────┬──────┘   └──────┬──────┘  └─────┬─────┘
          │                 │                 │
          └──────────────┬──┴─────────────────┘
                         │
                  ┌──────▼──────┐
                  │ PostgreSQL  │
                  └─────────────┘
```

Позже при реальной нагрузке могут появиться Redis/NATS/object storage, но не раньше фактической необходимости.

---

## 37. Почему не микросервисы сразу

Не надо делать в первую неделю:

```text
auth-service
inventory-service
loot-service
zombie-service
player-service
world-service
market-service
gateway-service
```

Это создаст больше DevOps, чем игры.

MVP:

```text
Godot Client
    ↓
Nakama authoritative runtime
    ↓
PostgreSQL
```

---

## 38. Networking model

### Server tick

MVP: **10–15 Hz**.

Client render: 60+ FPS.

Клиент интерполирует snapshots. Позже:

- client prediction;
- reconciliation;
- delta snapshots;
- adaptive send rate;
- interest management.

### Network opcodes

```text
1  INPUT_MOVE
2  INPUT_AIM
3  INPUT_ATTACK
4  INTERACT
5  INVENTORY_MOVE
6  ITEM_USE
7  ITEM_DROP
8  CHAT
9  SNAPSHOT
10 ENTITY_SPAWN
11 ENTITY_DESPAWN
12 DAMAGE_EVENT
13 DEATH_EVENT
14 CONTAINER_OPEN
15 CONTAINER_UPDATE
```

Хранить в одном enum/constants module, не размазывать magic numbers по проекту.

---

## 39. Movement networking

Правильный MVP flow:

1. клиент читает input vector;
2. отправляет `INPUT_MOVE`;
3. сервер нормализует/валидирует input;
4. сервер вычисляет authoritative movement;
5. сервер рассылает positions;
6. local player получает correction;
7. remote players интерполируются.

Клиент не должен иметь право сказать «моя позиция теперь x=9000» и заставить сервер поверить.

---

## 40. Persistence model

### Account persistent

- account;
- character;
- skills;
- settings.

### World persistent

- bases;
- containers;
- vehicles;
- important doors/windows;
- world flags;
- important world items.

### Ephemeral

- bullets;
- short-lived noise events;
- visual effects;
- часть AI state.

Не сохранять каждую миллисекунду каждого зомби.

---

## 41. MVP save strategy

- player save после важных inventory mutations;
- world snapshot каждые 30–60 секунд;
- save при graceful shutdown;
- save при disconnect, где возможно;
- критичные item transfers сохранять надёжнее обычной позиции.

Позже:

- event journal;
- snapshot + event replay;
- transactional economy operations.

---

## 42. Пример player state

```json
{
  "version": 1,
  "position": {"x": 20.4, "y": 14.7},
  "health": 91,
  "inventory": [
    {
      "slot": 0,
      "item_id": "food_canned_beans",
      "quantity": 1
    }
  ]
}
```

World state может хранить изменённые контейнеры, placed objects, opened/locked doors и другие persistent deltas.

---

## 43. Entity IDs

Использовать уникальные IDs:

```text
player:<uuid>
zombie:<world-id>
container:<world-id>
vehicle:<world-id>
object:<world-id>
item-instance:<uuid>
```

Никогда не считать индекс массива стабильным ID.

---

## 44. Античит

Главное правило: **never trust the client**.

Сервер проверяет:

- max movement speed;
- teleport;
- attack rate;
- range;
- ammo;
- inventory ownership;
- quantity;
- crafting cost;
- container distance/access;
- damage;
- cooldown;
- state transitions.

Не отправлять клиенту лишнее: hidden loot, позиции всех игроков или содержимое далёких контейнеров.

---

## 45. Protocol versioning

С первого билда:

```text
CLIENT_BUILD=0.1.0
PROTOCOL_VERSION=1
CONTENT_VERSION=1
```

Сервер может отвергнуть несовместимый client build.

---

## 46. Repository layout

```text
deadworld/
├ README.md
├ docs/
│  ├ GDD.md
│  ├ ARCHITECTURE.md
│  ├ NETWORKING.md
│  └ ROADMAP.md
├ client/
│  ├ project.godot
│  ├ scenes/
│  ├ scripts/
│  ├ assets/
│  ├ data/
│  └ tests/
├ server/
│  ├ src/
│  ├ tests/
│  ├ package.json
│  └ tsconfig.json
├ shared/
│  ├ protocol/
│  ├ schemas/
│  └ item_definitions/
├ infra/
│  ├ docker-compose.yml
│  ├ Caddyfile
│  ├ .env.example
│  └ scripts/
└ tools/
   └ content_validation/
```

---

## 47. Godot client structure

```text
client/
├ scenes/
│  ├ boot/
│  ├ login/
│  ├ world/
│  ├ player/
│  ├ zombies/
│  ├ items/
│  └ ui/
├ scripts/
│  ├ autoload/
│  │  ├ Network.gd
│  │  ├ GameState.gd
│  │  ├ ContentDB.gd
│  │  └ Settings.gd
│  ├ networking/
│  ├ entities/
│  ├ inventory/
│  └ ui/
└ data/
   ├ items/
   ├ loot/
   └ balance/
```

---

## 48. Правила AI-assisted разработки

1. Не создавать `ManagerNewFinal2`.
2. Перед новой системой искать существующий код.
3. Один source of truth для protocol.
4. Один source of truth для item definitions.
5. Secrets не коммитить.
6. `.env.example` — да, `.env` — нет.
7. Любая server mutation валидируется.
8. Изменять минимальный набор файлов.
9. После изменений запускать tests/checks.
10. Обновлять документацию вместе с архитектурой.
11. Не реализовывать future scope «заодно».
12. `main` всегда должен запускаться.

---

## 49. Git strategy

Для маленькой команды достаточно:

```text
main
feature/*
fix/*
```

Или `main + dev`, если нужен staging branch.

Примеры commit messages:

```text
chore: bootstrap godot project
chore: add nakama docker stack
feat: add device authentication
feat: add authoritative world match
feat: replicate player movement
feat: add zombie chase state
feat: add server validated item pickup
fix: prevent duplicate container pickup
feat: persist player inventory
build: add android export preset
```

---

## 50. CI minimum

На push:

1. TypeScript build;
2. server tests;
3. JSON/schema validation;
4. Godot headless project parse/check, если доступно;
5. `docker compose config`.

После MVP:

- Windows build;
- Android build;
- artifacts;
- staging deploy.

---

## 51. Logging

Структурированные server logs:

```json
{
  "event": "player_attack",
  "player_id": "abc",
  "weapon": "pistol_9mm",
  "target": "zombie:552",
  "damage": 18
}
```

Никогда не логировать passwords/session tokens целиком.

---

## 52. Метрики после MVP

```text
online_players
server_tick_ms
messages_per_sec
entities_per_zone
active_zombies
db_query_ms
save_duration_ms
disconnect_rate
```

---

## 53. Performance budgets

### Client

- 60 FPS на нормальном desktop target;
- Android 30/60 FPS в зависимости от устройства;
- ограничивать active animated entities.

### Server

При 15 Hz один frame имеет около 66 ms математического окна, но серверный tick должен стабильно занимать заметно меньше, оставляя запас на spikes, GC и сеть.

### Network

Не слать полный world snapshot JSON каждый tick. На раннем MVP допустим простой формат, но сообщения должны быть granular и versioned.

---

## 54. Что считается MVP

MVP готов, если два человека на разных устройствах/сетях могут:

1. установить игру;
2. подключиться к одному интернет-серверу;
3. получить отдельный account/device ID;
4. появиться в одном мире;
5. видеть друг друга;
6. двигаться;
7. видеть одних и тех же зомби;
8. убивать зомби;
9. подбирать shared items;
10. видеть, что предмет, взятый другим, исчез;
11. открывать контейнеры;
12. менять inventory;
13. умереть;
14. respawn;
15. выйти;
16. зайти снова;
17. получить сохранённый state.

Это уже технологическое доказательство настоящей persistent online survival игры.

---

## 55. Что НЕ входит в недельный MVP

- машины;
- электричество;
- farming;
- seasons;
- weather simulation;
- clans;
- market;
- voice chat;
- skill trees;
- quests;
- NPC;
- bosses;
- procedural city;
- base raiding;
- advanced body system;
- огромный crafting tree;
- Steamworks;
- App Store release;
- Kubernetes;
- microservices.

---

## 56. Content scope MVP

### Map

- 1 маленькая карта;
- 6–10 зданий/комнат;
- road/forest;
- safe spawn.

### Enemies

- 1 zombie visual;
- 1 stats profile.

### Weapons

- fists;
- bat;
- pistol.

### Items

10–15.

### Containers

- crate;
- cabinet;
- medical cabinet.

### Core systems

- movement;
- interaction;
- zombies;
- combat;
- inventory;
- loot;
- health;
- death;
- respawn;
- network;
- persistence.

---

## 57. Что купить для MVP-сервера

GPU не нужен.

Рекомендуемый стартовый VPS:

```text
CPU: 4 vCPU
RAM: 8 GB
Disk: 80–160 GB NVMe
OS: Ubuntu 24.04 LTS или другой привычный modern Linux
Network: 1 Gbit/s достаточно для pre-alpha
IPv4: желательно
GPU: нет
```

Самому маленькому тесту, вероятно, хватит 2 vCPU / 4 GB, но 4/8 даёт запас для PostgreSQL, Nakama, runtime, Caddy и логов.

Не покупать дорогой dedicated server до profiling/load test.

---

## 58. DNS и ports

Вариант:

```text
game.example.com
```

или:

```text
api.example.com
game.example.com
```

Желательно публиковать клиентский трафик через TLS/443. PostgreSQL наружу не публиковать.

SSH:

- keys;
- firewall;
- password auth выключить, если удобно;
- backups;
- отдельный deploy user позже.

---

## 59. Docker Compose MVP

Контейнеры:

```text
deadworld-postgres
deadworld-nakama
deadworld-caddy
```

Опционально:

```text
deadworld-backup
```

Не добавлять Redis/Kafka/Kubernetes на первой неделе.

---

## 60. Что установить локально

Обязательно:

- Git;
- Godot 4.x stable;
- Godot export templates;
- Docker;
- Docker Compose;
- Node.js LTS;
- npm/pnpm;
- IDE/coding agent;
- Android SDK;
- JDK 17;
- ADB.

Для iOS позже:

- Mac;
- Xcode;
- Apple signing setup.

---

## 61. Placeholder assets

Никакого art rabbit hole в первую неделю.

Нужны максимум:

- player sprite/shape;
- remote player shape;
- zombie sprite/shape;
- floor;
- wall;
- door;
- crate;
- несколько item icons.

Можно начать цветными геометрическими объектами:

```text
blue = local player
green = remote player
red = zombie
yellow = loot
gray = wall
```

---

## 62. Workflow каждой задачи

1. Определить Definition of Done.
2. AI читает relevant files.
3. AI показывает минимальный план.
4. AI меняет минимальный набор файлов.
5. Запускаются checks.
6. Запускается игра.
7. Manual test.
8. Commit.
9. Следующая задача.

Не давать AI одновременно переписывать половину проекта.


# 63. 7-ДНЕВНЫЙ ROADMAP MVP

## День 0 — подготовка до старта

Не считается полноценным dev day.

Нужно:

- выбрать working title;
- создать Git repo;
- установить current stable Godot 4.x;
- поставить export templates;
- установить Docker/Compose;
- Node.js LTS;
- Android SDK + JDK 17;
- купить VPS;
- настроить SSH;
- подготовить домен/поддомен, если есть;
- положить этот документ в `docs/GDD.md`;
- согласиться на placeholder art;
- **заморозить MVP scope**.

---

## День 1 — фундамент multiplayer

### Цель

Два клиента подключаются к серверу и видят движение друг друга.

### Infra

- Docker Compose;
- PostgreSQL;
- Nakama;
- Caddy/local dev endpoint;
- `.env.example`;
- healthchecks.

### Server

- TypeScript runtime;
- authoritative `world` match;
- player join/leave registry;
- fixed tick 10–15 Hz;
- movement input;
- authoritative position update;
- position/state replication;
- malformed packet validation.

### Client

- Boot scene;
- connection config;
- device/guest auth;
- realtime socket;
- join world;
- LocalPlayer;
- RemotePlayer;
- WASD;
- interpolation;
- disconnect cleanup.

### Definition of Done

Два отдельных клиента:

- входят;
- получают разные IDs;
- находятся в одном мире;
- ходят;
- видят друг друга;
- не могут ускориться, просто прислав огромный input.

### Запрет дня

Не трогать zombies/inventory/loot/combat до стабильного movement.

---

## День 2 — shared zombies

### Цель

Есть одинаковые authoritative zombies у всех клиентов.

### Tasks

- spawn points;
- zombie IDs;
- server-side state;
- detect nearest player;
- chase;
- attack;
- HP;
- death;
- spawn/despawn replication;
- basic map collision.

### Definition of Done

Два клиента видят одного зомби в одной позиции. Он выбирает цель на сервере, атакует серверно и одинаково умирает для обоих.

---

## День 3 — shared items, containers, inventory

### Цель

Общий loot без простейшего duplication.

### Tasks

- item definitions;
- world item IDs;
- server-validated pickup;
- inventory slots;
- drop;
- generic container;
- container version;
- loot generation;
- distance validation.

### Definition of Done

Игрок A забирает банку из шкафа. Игрок B мгновенно видит обновление и уже не может забрать ту же банку.

---

## День 4 — combat slice

### Цель

Игра уже ощущается игрой, а не сетевым демо.

### Tasks

- fists/melee;
- bat;
- pistol;
- ammo;
- reload;
- attack cooldown;
- hit validation;
- damage;
- death;
- respawn;
- простая feedback-анимация/звук, если успеваем.

### Definition of Done

Можно:

```text
найти пистолет
→ найти патроны
→ зарядить
→ убить зомби
→ забрать лут
→ получить урон
→ умереть
→ respawn
```

---

## День 5 — persistence

### Цель

Рестарт игры/сервера не обнуляет основной state.

### Persist

- player position или безопасная fallback-position;
- health;
- inventory;
- equipment;
- changed containers;
- picked/dropped important world items.

### Добавить

- autosave;
- disconnect save;
- graceful shutdown save;
- periodic world snapshot;
- DB backup script.

### Definition of Done

Тест 1:

```text
взял item → вышел → зашёл → item в inventory
```

Тест 2:

```text
забрал world item → server restart → item не появился второй раз
```

---

## День 6 — Android + hardening

### Цель

Windows и Android реально играют вместе.

### Tasks

- Android export;
- touch controls;
- responsive UI;
- reconnect;
- connection timeout;
- disconnect cleanup;
- invalid message handling;
- basic rate limiting;
- latency test;
- profiling.

### Definition of Done

Android и Windows находятся в одном мире, двигаются, убивают одного зомби и делят один контейнер.

---

## День 7 — internet pre-alpha build

### Цель

Отдать билд 2–5 друзьям без ручного шаманства.

### Tasks

- clean Windows build;
- Android APK;
- production server deploy;
- TLS/domain;
- production server URL;
- crash fixes;
- README;
- known issues;
- feedback channel/form;
- backup;
- tag `v0.1.0-mvp`.

### Финальный smoke test

30–60 минут:

- 3+ clients;
- Windows + Android;
- reconnect;
- zombies;
- combat;
- simultaneous loot;
- death/respawn;
- server restart;
- persistence.

---

# 64. Fallback order, если неделя горит

Вырезаем в таком порядке:

1. красивый UI;
2. hunger/thirst;
3. stamina;
4. rarity;
5. несколько типов контейнеров;
6. красивые анимации;
7. много зданий;
8. Android polish.

**Не вырезаем:**

- authoritative networking;
- multiplayer;
- shared zombies;
- shared loot;
- persistence;
- reconnect.

Именно они доказывают технологическую основу проекта.

---

# 65. Недели 2–4 — v0.1.x

### Networking

- movement prediction;
- reconciliation;
- interpolation polish;
- interest management;
- delta/event replication.

### Survival

- hunger;
- thirst;
- stamina;
- bleeding;
- healing;
- weight.

### Content

- 30–50 items;
- 3–5 zombie variants;
- 5+ weapons;
- несколько building archetypes.

### Base

- chest;
- wall;
- door;
- bed;
- primitive claim/safehouse.

### Quality

- settings;
- audio;
- keybinds;
- proper mobile UI;
- first art pass.

---

# 66. v0.2 — Survival Foundation

Цель: **маленький, но уже настоящий Zomboid-like online survival.**

Добавить:

- deeper health/body;
- hunger/thirst;
- food/cooking;
- fatigue;
- basic weather;
- clothing;
- temperature;
- noise;
- stealth;
- doors/windows;
- barricades;
- crafting;
- generators;
- base building.

Target: 20–50 concurrent test players на world instance, затем profiling.

---

# 67. v0.3 — Social Survival

- friends;
- party;
- clans;
- clan roles;
- text/proximity chat;
- trading;
- safe settlement;
- reputation basics;
- player names/visibility rules;
- player contracts alpha.

Цель: игроки начинают создавать социальные истории без scripted quest chains.

---

# 68. v0.4 — Persistent Economy

- barter;
- settlement currency;
- market;
- auction;
- player shops;
- repair economy;
- scarcity;
- crafting professions;
- transaction audit log;
- economy telemetry;
- duplication detection.

---

# 69. v0.5 — Vehicles & Infrastructure

- vehicles;
- fuel;
- trunk;
- damage/repair;
- mechanics;
- battery;
- generators;
- electricity;
- water;
- farming;
- logistics loop.

---

# 70. v0.6 — MMO World Scaling

Только теперь уходим от «один match = один мир».

```text
World EU-1
├ Zone A
├ Zone B
├ Zone C
└ Instances
```

Понадобятся:

- zone ownership;
- player handoff;
- entity handoff;
- shared account state;
- cluster coordination;
- AOI/spatial index;
- AI LOD;
- load tests;
- horizontal scaling.

Цель — сотни игроков на shard, но фактические targets определяются только benchmark'ами.

---

# 71. Handoff — future outline

1. Zone A замечает приближение игрока к границе.
2. Zone B получает preload state.
3. Создаётся signed/short-lived handoff token.
4. Client переключается на новую zone/session route.
5. Zone B становится authoritative owner.
6. Zone A удаляет entity после acknowledgement.
7. Нельзя допустить dual ownership/duplication.

---

# 72. v0.7 — World Content

- большой город;
- suburbs;
- farms;
- military zones;
- hospitals;
- police stations;
- bunkers;
- labs;
- forests;
- industrial zones;
- world events;
- migrating hordes;
- rare locations.

---

# 73. v0.8 — Factions / PvP

- factions;
- crime;
- bounty;
- controlled PvP zones;
- clan territories;
- resource points;
- settlement conflicts;
- hardcore shards.

Основной сервер не должен превращаться в Rust, где новичка убивают через 12 секунд после spawn.

---

# 74. v0.9 — Beta

Не наваливаем новые фичи. Фокус:

- crashes;
- exploits;
- duplication;
- server stability;
- economy;
- onboarding;
- mobile UX;
- device compatibility;
- moderation;
- backups;
- recovery;
- network optimization.

---

# 75. v1.0 — Release target

Минимальное обещание 1.0:

- persistent survival world;
- crossplay PC/mobile;
- bases;
- vehicles;
- clans;
- economy;
- PvE;
- controlled PvP;
- world events;
- skill progression;
- crafting;
- medicine;
- electricity;
- farming;
- large world;
- moderation;
- monitoring;
- backups;
- patch pipeline.

---

# 76. Live Ops после 1.0

Сезонность может менять мир, а не обязательно продавать battle pass:

- winter;
- новый заражённый регион;
- новая faction;
- новая лаборатория;
- большая миграция орд;
- восстановление инфраструктуры;
- story/world event.

Не обнулять персонажей каждые пару месяцев без действительно нужного design reason.

---

# 77. Нагрузочный тест

После MVP создать headless bot clients.

Bots должны:

- connect;
- move;
- attack;
- interact;
- disconnect/reconnect.

Ступени:

```text
10 → 25 → 50 → 100 → дальше по факту
```

Смотреть:

- CPU;
- RAM;
- tick time;
- bandwidth;
- DB latency;
- disconnect rate.

Оптимизировать то, что реально стало bottleneck.

---

# 78. Главные риски

## Scope explosion

Лечение: frozen MVP + backlog.

## Networking spaghetti

Лечение: central protocol + schemas + server authority + versioning.

## Persistence/dupe bugs

Лечение: unique item IDs + container versions + transactional mutations + restart tests.

## Zombie CPU

Лечение: spatial partition + reduced ticks + AI LOD + aggregate far simulation.

## Mobile performance

Лечение: entity limits + quality profiles + interest management + profiling.

## Vibe-code entropy

Лечение: маленькие commits, docs, tests, code review, запрет на duplicate managers.

---

# 79. Admin/Moderation — post-MVP

Нужно заранее понимать, что MMO без moderation долго не живёт.

Позже:

```text
/admin players
/admin inspect
/admin teleport
/admin spawn
/admin kick
/admin ban
/admin world_event
```

Также:

- report player;
- mute;
- ban;
- audit log;
- server announcements.

Все admin actions логируются.

---

# 80. Backups

MVP production:

- ежедневный PostgreSQL dump;
- backup перед deploy;
- несколько поколений backups;
- отдельный restore test.

**Backup, который ни разу не восстанавливали, — это надежда, а не backup.**

---

# 81. Что нужно подготовить ПРЯМО СЕЙЧАС

Минимум:

```text
[ ] Git repository
[ ] текущий stable Godot 4.x
[ ] Godot export templates
[ ] Docker + Compose
[ ] Node.js LTS
[ ] Android SDK
[ ] JDK 17
[ ] VPS 4 vCPU / 8 GB RAM
[ ] SSH key
[ ] domain/subdomain (желательно)
[ ] этот файл как docs/GDD.md
[ ] готовность использовать placeholder art
[ ] 2-й компьютер/телефон для multiplayer test или два client instances
```

Не требуется на неделе 1:

```text
[ ] Steamworks
[ ] Apple Developer account
[ ] Google Play production listing
[ ] production art
[ ] composer
[ ] Kubernetes
[ ] отдельная команда DevOps
```

---

# 82. MVP Issue Board

## Infrastructure

- [x] Docker Compose
- [x] PostgreSQL
- [x] Nakama
- [x] Caddy/TLS
- [x] production env
- [x] backup script
- [x] automated production deploy
- [x] Russian landing/status
- [x] protected test admin

## Networking

- [x] Auth
- [x] Socket
- [x] Join world
- [x] Player spawn
- [x] Movement input
- [x] Remote interpolation
- [x] Reconnect

## World

- [x] Map
- [x] Collision
- [x] Spawn points
- [x] Interactions

## Zombies

- [x] Spawn
- [x] Detect
- [x] Chase
- [x] Attack
- [x] Damage
- [x] Death

## Items

- [x] Definitions
- [x] World items
- [x] Pickup
- [x] Drop
- [x] Inventory

## Loot

- [x] Container
- [x] Open
- [x] Shared state
- [ ] Loot table

## Combat

- [x] Melee
- [x] Pistol
- [x] Ammo
- [x] Server hit validation

## Persistence

- [x] Save player
- [x] Load player
- [x] Save world
- [x] Restart test

## Platforms

- [x] Windows export
- [x] Android export
- [x] Touch controls

---

# 83. Release checklist MVP

## Server

- [x] secrets changed
- [x] TLS works
- [x] DB not public
- [x] backup works
- [x] restore tested
- [x] healthcheck
- [x] logs readable
- [x] restart safe

## Client

- [x] production URL
- [x] no secrets
- [x] reconnect
- [ ] Windows clean install
- [ ] Android clean install
- [x] version visible
- [x] GitHub prerelease downloads

## Gameplay

- [x] movement
- [x] zombies
- [x] combat
- [x] loot
- [x] inventory
- [x] death
- [x] respawn
- [x] persistence

## Multiplayer

- [x] 2 clients
- [x] 3+ clients
- [x] simultaneous pickup
- [x] disconnect
- [x] reconnect
- [x] server restart

---

# 84. ПЕРВЫЙ PROMPT ДЛЯ CODING AGENT

Скопировать целиком после создания репозитория и помещения этого файла в `docs/GDD.md`.

```text
Ты — lead game/network engineer проекта Project Deadworld.

Мы начинаем разработку кроссплатформенной persistent online survival RPG.
Главный gameplay-вектор: медленный системный изометрический zombie survival в духе Project Zomboid, но это НЕ клон. Не копируй чужие ассеты, UI, карты, названия, тексты или код.

Целевые платформы:
- Windows
- Android
- Linux
- архитектурно iOS/macOS позже

MVP должен быть SERVER-AUTHORITATIVE.

Технологии MVP:
- current stable Godot 4.x
- GDScript client
- Nakama
- PostgreSQL
- TypeScript Nakama authoritative runtime
- Docker Compose
- Caddy

Перед любым кодом прочитай:
- docs/GDD.md
- README.md, если он уже есть
- весь релевантный repository tree

ОБЩИЕ ПРАВИЛА:
1. Не переписывай весь проект без необходимости.
2. Не создавай дублирующие Manager/Service классы.
3. Не доверяй клиенту gameplay state.
4. Сервер является source of truth для position, health, combat, inventory, loot и zombie state.
5. Никаких secrets в репозитории.
6. Используй .env и .env.example.
7. Network opcodes/constants должны находиться централизованно.
8. Любая server-side mutation должна проходить validation.
9. Не добавляй системы, которых нет в задаче текущего шага.
10. После изменений запускай доступные tests/checks/build.
11. Если что-то нельзя проверить автоматически, дай точные manual test steps.
12. Не добавляй Kubernetes, Redis, Kafka, микросервисы и прочую инфраструктуру без необходимости.
13. main должен оставаться запускаемым.
14. Делай небольшие логические изменения.
15. Обновляй README/docs, если меняется способ запуска.
16. Не выдумывай API. Если установленная версия Godot/Nakama отличается от твоих знаний, используй фактическую документацию/типизацию установленной версии.

ТЕКУЩАЯ ЗАДАЧА: DAY 1 ONLY.

Цель Day 1:
Два клиента должны подключиться к одному backend, пройти guest/device authentication, войти в один authoritative world match, заспавниться и видеть server-authoritative перемещение друг друга.

СЕЙЧАС НЕ РЕАЛИЗОВЫВАТЬ:
- zombies
- inventory
- loot
- combat
- crafting
- bases
- clans
- quests
- vehicles
- hunger/thirst
- красивый UI

Подготовь monorepo:

deadworld/
├ README.md
├ docs/
├ client/
├ server/
├ shared/
└ infra/

INFRA:
1. docker-compose.yml.
2. PostgreSQL.
3. Nakama.
4. Caddy или чёткий local-dev path без TLS.
5. .env.example.
6. Healthchecks.
7. Persistent DB volume.
8. Понятные команды start/stop/logs.

SERVER:
1. TypeScript Nakama runtime project.
2. Authoritative match handler `world`.
3. Fixed tick 10–15 Hz.
4. Player join/leave state.
5. Input message для movement.
6. Server-side authoritative position update.
7. Snapshot/state broadcast.
8. Validation: normalized vector, max speed, malformed packet rejection.
9. Structured logs.
10. Network opcodes/constants в одном месте.
11. Stable player/session identifiers.

CLIENT:
1. Minimal Godot project.
2. Boot scene.
3. Network autoload/singleton.
4. Connect to Nakama.
5. Guest/device authentication.
6. Open realtime socket.
7. Join/create test world.
8. Spawn LocalPlayer.
9. Spawn RemotePlayer.
10. WASD movement input.
11. Отправлять movement INPUT, а не trusted final position.
12. Receive server snapshots.
13. Apply authoritative correction для local player.
14. Interpolate remote players.
15. Разные placeholder visuals для local/remote players.
16. Connection status label.
17. Player join/leave cleanup.

Не трать время на art. Используй простые placeholder shapes/sprites.

DEFINITION OF DONE:
- `docker compose up` поднимает backend;
- Godot client запускается без ручного редактирования исходников;
- два отдельных client instances одновременно подключаются;
- у каждого уникальный player ID;
- оба находятся в одном world match;
- движение одного видно второму;
- server остаётся authoritative;
- disconnect удаляет remote entity;
- malformed/oversized movement input не даёт превысить max speed;
- README содержит точные команды запуска;
- .env.example содержит необходимые переменные без реальных secrets.

ПОРЯДОК РАБОТЫ:
A. Сначала проанализируй repository и GDD.
B. Покажи короткий план и список файлов, которые собираешься создать/изменить.
C. Реализуй только Day 1.
D. Запусти lint/build/tests/docker config checks, которые доступны.
E. Исправь найденные ошибки.
F. Дай итог:
   - что реализовано;
   - tree изменённых файлов;
   - команды запуска;
   - manual test для двух клиентов;
   - известные ограничения;
   - следующий логичный task, но НЕ реализовывай его.

КРИТИЧНО:
Если фактическая API установленной версии Godot/Nakama расходится с предположениями в prompt, используй API установленной версии и зафиксируй версии зависимостей в репозитории.

Начинай с анализа файлов и Day 1 implementation.
```

---

# 85. Prompt на Day 2 после успешного теста Day 1

```text
Продолжаем Project Deadworld.

Day 1 подтверждён manual test:
- два клиента подключаются;
- видят друг друга;
- server-authoritative movement работает;
- disconnect cleanup работает.

Теперь реализуй DAY 2: shared authoritative zombie simulation.

Прочитай docs/GDD.md и текущий код. Не ломай существующий protocol.

Scope:
- один zombie type;
- server-side spawn;
- IDLE;
- CHASE;
- ATTACK;
- DEAD;
- detect nearest valid player;
- server-authoritative HP;
- position/state replication;
- spawn/despawn/death events;
- placeholder zombie rendering в Godot.

Не реализовывать inventory/loot/guns сегодня.

Definition of Done:
- два клиента видят одних и тех же zombie entities;
- zombie position/state одинаковы для обоих;
- zombie выбирает цель server-side;
- zombie не управляется клиентом;
- zombie наносит server-authoritative damage;
- death state синхронизируется;
- reconnect получает актуальный nearby zombie state.

Сначала дай минимальный план файлов, затем реализацию, checks и manual test.
```

---

# 86. Технические источники для сверки перед стартом

Перед началом закрепить актуальные stable версии зависимостей и свериться с официальными документами:

- Godot Docs — Exporting for dedicated servers;
- Godot Docs — Exporting for Android;
- Godot Docs — Exporting for iOS;
- Heroic Labs — Nakama Godot 4 Client Guide;
- Heroic Labs — Nakama Authoritative Multiplayer;
- Heroic Labs — Authentication.

Не позволять coding agent смешивать API разных релизов.

---

# 87. Финальный sanity check

Перед первым коммитом:

- [ ] делаем vertical slice, не «MMO за неделю»;
- [ ] сервер authoritative;
- [ ] клиент не пишет напрямую в PostgreSQL;
- [ ] protocol имеет один source of truth;
- [ ] item definitions имеют один source of truth;
- [ ] secrets не коммитятся;
- [ ] Docker stack воспроизводим;
- [ ] два клиента можно запустить локально;
- [ ] есть VPS для internet test;
- [ ] есть Windows build target;
- [ ] Android toolchain работает;
- [ ] iOS не блокирует MVP;
- [ ] scope Day 1 заморожен;
- [ ] после каждого дня есть playable build.

---

# 88. Итоговая стратегия

```text
Неделя 1  → Network Proof
Месяц 1   → Survival Proof
Месяцы 2–3→ Persistent Social World Proof
Дальше     → MMO Scaling
```

Самый важный первый успех проекта — не 1000 CCU.

Первый успех выглядит так:

> Три человека заходят вечером на один сервер, идут лутать клинику, привлекают орду выстрелами, один погибает, второй забирает его рюкзак, третий возвращается с лекарствами, а после рестарта сервера мир всё это помнит.

Если это работает и в это уже весело играть — фундамент правильный. Всё остальное можно наращивать поверх него.
