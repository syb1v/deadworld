# MVP — v0.1.0 Online Survival Vertical Slice

## Deadline

Цель — получить игровой vertical slice примерно за 7 сфокусированных дней разработки.

Это aggressive target. Срок достигается только за счёт жёсткого scope cut.

## Product promise

Два или больше игроков на разных устройствах/сетях подключаются к одному persistent миру и могут вместе пройти базовый survival loop.

## Must Have

### Networking

- [ ] device/guest authentication;
- [ ] realtime connection;
- [ ] authoritative world session;
- [ ] уникальные player IDs;
- [ ] player join/leave;
- [ ] authoritative movement;
- [ ] remote interpolation;
- [ ] reconnect;
- [ ] protocol version.

### World

- [ ] одна маленькая карта;
- [ ] collision;
- [ ] spawn zone;
- [ ] 6–10 простых зданий/областей максимум.

### Zombies

- [ ] один тип зомби;
- [ ] server spawn;
- [ ] idle;
- [ ] detect;
- [ ] chase;
- [ ] attack;
- [ ] death;
- [ ] shared state.

### Combat

- [ ] melee;
- [ ] pistol;
- [ ] ammo;
- [ ] server damage validation.

### Items

- [ ] 10–15 definitions;
- [ ] world item;
- [ ] pickup;
- [ ] drop;
- [ ] simple slot inventory.

### Containers

- [ ] один generic container;
- [ ] open;
- [ ] shared contents;
- [ ] versioned mutation;
- [ ] duplicate pickup prevention.

### Death

- [ ] player death;
- [ ] respawn;
- [ ] server-owned state reset/drop policy.

### Persistence

- [ ] save/load player;
- [ ] inventory persists;
- [ ] important world mutations persist;
- [ ] restart does not respawn already-taken unique loot.

### Platforms

- [ ] Windows build;
- [ ] Android build;
- [ ] PC ↔ Android crossplay.

## Nice to Have

Удаляются первыми при риске дедлайна:

- hunger;
- thirst;
- stamina;
- rarity colors;
- extra container types;
- audio polish;
- more buildings;
- Linux package.

## Explicitly Out of Scope

- clans;
- parties;
- market;
- trading;
- vehicles;
- farming;
- electricity;
- weather;
- advanced medicine/body parts;
- bosses;
- quests;
- NPC factions;
- procedural huge world;
- zone handoff;
- MMO-scale orchestration;
- voice chat;
- Steam integration;
- App Store release.

## 7 days

### Day 1 — Online movement

Definition of Done:

> Два клиента подключаются, видят друг друга и server-authoritative movement.

### Day 2 — Shared zombies

Definition of Done:

> Оба клиента видят одних и тех же server-owned zombies.

### Day 3 — Inventory + shared loot

Definition of Done:

> Предмет нельзя забрать дважды; inventory меняется сервером.

### Day 4 — Combat + death

Definition of Done:

> Полный маленький цикл: найти оружие → убить зомби → умереть → respawn.

### Day 5 — Persistence

Definition of Done:

> Client/server restart не уничтожает нужный state и не создаёт duplication.

### Day 6 — Android crossplay

Definition of Done:

> Windows и Android играют в одном мире.

### Day 7 — Internet playtest

Definition of Done:

> Чистый build можно дать 2–5 тестерам; они подключатся к production test VPS по инструкции.

## Cut order

Если времени не хватает:

1. polish UI;
2. hunger/thirst;
3. stamina;
4. rarity;
5. extra containers;
6. extra buildings;
7. animations/audio.

Нельзя вырезать:

- server authority;
- shared world;
- shared zombies;
- loot consistency;
- persistence;
- reconnect.

## Release tag

```text
v0.1.0-mvp
```

Публично называть:

> Pre-alpha multiplayer survival tech test
