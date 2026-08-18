# MVP — v0.1.0 Online Survival Vertical Slice

## Deadline

Цель — получить игровой vertical slice примерно за 7 сфокусированных дней разработки.

Это aggressive target. Срок достигается только за счёт жёсткого scope cut.

## Product promise

Два или больше игроков на разных устройствах/сетях подключаются к одному persistent миру и могут вместе пройти базовый survival loop.

## Must Have

### Networking

- [x] device/guest authentication;
- [x] realtime connection;
- [x] authoritative world session;
- [x] уникальные player IDs;
- [x] player join/leave;
- [x] authoritative movement;
- [x] remote interpolation;
- [x] reconnect;
- [x] protocol version.

### World

- [x] одна маленькая карта;
- [x] collision;
- [x] spawn zone;
- [x] 6–10 простых зданий/областей максимум.

### Zombies

- [x] один тип зомби;
- [x] server spawn;
- [x] idle;
- [x] detect;
- [x] chase;
- [x] attack;
- [x] death;
- [x] shared state.

### Combat

- [x] melee;
- [x] pistol;
- [x] ammo;
- [x] server damage validation.

### Items

- [x] 10–15 definitions;
- [x] world item;
- [x] pickup;
- [x] drop;
- [x] simple slot inventory.

### Containers

- [x] один generic container;
- [x] open;
- [x] shared contents;
- [x] versioned mutation;
- [x] duplicate pickup prevention.

### Death

- [x] player death;
- [x] respawn;
- [x] server-owned state reset/drop policy.

### Persistence

- [x] save/load player;
- [x] inventory persists;
- [x] important world mutations persist;
- [x] restart does not respawn already-taken unique loot.

### Platforms

- [x] Windows build;
- [x] Android build;
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
- Linux package (Day 6 build готов).

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

### Day 6 — World + crossplatform

Definition of Done:

> Маленькая authoritative collision map и Windows/Linux/Android builds готовы; Windows и Android играют в одном мире после device acceptance test.

### Day 7 — Internet playtest

Definition of Done:

> Чистый build можно дать 2–5 тестерам; они подключатся к production test VPS по инструкции.

Current acceptance status:

- [x] Ubuntu production host prepared at `/opt/deadworld`;
- [x] PostgreSQL and raw Nakama ports are private;
- [x] production secrets are host-only and default signing/session keys are replaced;
- [x] healthchecks, restart policies, firewall and structured logs verified;
- [x] daily compressed backup with retention;
- [x] isolated restore test;
- [x] remote full-stack restart preserves ownership and world state without duplication;
- [x] three concurrent accounts share one authoritative world;
- [x] Linux, Windows and Android artifacts built with visible `v0.1.0-mvp` label;
- [x] exported Linux build connects from an empty user profile over production HTTPS/WSS;
- [x] `game.staydev.org` DNS points to the production VPS;
- [x] public Let's Encrypt TLS and HTTPS/WSS acceptance;
- [x] Russian landing with live server/player status and prerelease downloads;
- [x] protected Russian test admin with authoritative event feed and persisted zombie respawn;
- [x] automated interactive deployment and GitHub prerelease workflow;
- [ ] physical PC ↔ Android crossplay;
- [ ] clean installs on Windows and Android (Linux empty-profile smoke passed).

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

Current public test prerelease:

```text
v0.1.0-prealpha.1
```

Final MVP tag after all mandatory acceptance gates:

```text
v0.1.0-mvp
```

Публично называть:

> Pre-alpha multiplayer survival tech test
