# Project Deadworld Roadmap

Roadmap is directional, not a promise of dates. Каждая версия начинается только после игрового теста предыдущей.

Главное правило: каждая MMO-фича должна усиливать survival, а не заменять его. Оптимальный gameplay не должен сводиться к стоянию в хабе, аукциону и ежедневным заданиям.

```text
v0.1 MVP
  -> v0.1.1 POLISH
  -> v0.2 SURVIVAL
  -> v0.3 BASES + WORLD SYSTEMS
  -> v0.4 SOCIAL / MMO
  -> v0.5 ECONOMY + SETTLEMENTS
  -> v0.6 VEHICLES + INFRASTRUCTURE
  -> v0.7 BIG WORLD + EVENTS
  -> v0.8 PVP + FACTIONS
  -> v0.9 SCALE / BETA
  -> v1.0
```

## v0.1.0 - MVP checkpoint

Готовый фундамент: единый persistent backend, authoritative movement/combat/zombies/loot/inventory/containers/death, restart safety, HTTPS/WSS, backups и сборки Windows/Linux/Android/iOS.

До тега `v0.1.0-mvp`:

- [ ] PC <-> Android;
- [ ] PC <-> iPhone;
- [ ] Android <-> iPhone;
- [ ] 3-5 одновременных игроков;
- [ ] clean-device regression всех gameplay/persistence gates.

Тег ставится только после этих проверок. Фундамент MVP после этого меняется только по доказанной необходимости.

## v0.1.1 - Polish

Цель: превратить технический vertical slice в читаемую игру без добавления survival-систем.

- responsive desktop/mobile layouts, safe areas и разные aspect ratios;
- twin-stick mobile input: движение слева, aim/fire справа;
- interaction prompt and explicit authoritative container/inventory take/deposit are implemented; drag/drop, split, context actions and take all remain;
- combat feedback: muzzle/hit flash, blood, recoil, reaction, restrained shake, reload/cooldown, death/body presentation;
- sound pass: movement, weapons, zombies, interactions, damage/death, UI и ambience;
- coherent tileset, roads, buildings, furniture, debris, decals, shadows, character/zombie sprites и item icons;
- исправление playtest blockers, crashes и operational tooling;
- Google Play Internal Testing; официальный Apple signing/TestFlight отдельно от unsigned test flow.

Current delivery checkpoint: `v0.1.0-prealpha.6` introduces single-source versioning (`VERSION` + `scripts/version.py`), version-stamped Android/iOS build numbers and fully versioned artifact filenames for every platform, so devices and installers always replace the previous build instead of reusing a cached one.

## v0.2 - Survival Foundation

- hunger, thirst, stamina и encumbrance;
- food/water definitions и простые consumables;
- medicine v1: HP, bleeding, pain, infection;
- body parts и понятные movement/aim/melee consequences;
- Zombie AI 2.0: idle, wander, hear, investigate, search, chase, attack;
- server-side pathfinding и noise events для footsteps, running, breaking, weapons, alarms и будущих vehicles;
- stealth и первые weather/temperature foundations только после основного survival loop.

## v0.3 - Bases + World Systems

- doors, windows, locks, breaking, climbing и barricades;
- building v1: wall, door, floor, storage, bed, campfire;
- building expansion: window, roof, stairs, fence, gate и workbench;
- building-bound safehouses с ownership, permissions и maintenance вместо магического claim radius;
- persistent containers: cupboards, crates, fridges и weapon lockers;
- data-driven crafting: survival, construction, medicine, cooking, weapons, mechanics и electronics;
- action-based skills: combat, survival и technical, с anti-grind rules.

## v0.4 - Social / MMO

- friends, presence и invites;
- parties, shared markers, party HP/chat и friendly-fire policy;
- text channels: local, party, clan, global и system; proximity voice рассматривается позже;
- clans, roles, permissions, storage и safehouse access;
- persistent player traces: looted stores, corpses, bases, blood, broken doors, fires и abandoned assets.

## v0.5 - Economy + Settlements

- barter first, затем одна settlement currency с контролируемыми sources/sinks;
- server-authoritative atomic player trade;
- market listings с fee, expiry, audit и transaction history;
- player shops только после стабильного market core;
- player-driven settlement upgrades: clinic, workshop, market, garage, radio tower и defences;
- professions должны создавать зависимость между врачами, механиками, строителями и оружейниками.

## v0.6 - Vehicles + Infrastructure

- sedan v1: fuel, health, speed, trunk и passengers;
- component expansion: battery, engine, tires, windows, doors, repair и hotwire;
- vehicle noise как обязательный risk/reward;
- generators, fuel и power network для lights, fridges, workbenches и radios;
- water через taps, wells, collectors, pumps и filters, включая world-age shutdown;
- simple farming: seed, plant, water, grow, harvest; disease/seasons/fertilizer позже.

## v0.7 - Big World + Events

- handcrafted/semi-procedural downtown, suburbs, forest, farms, industrial, hospital, police, military, laboratory, gas station и supermarket;
- у каждой зоны своя gameplay-причина и loot profile;
- scarcity по building/room/region/world age/events с осторожным replenishment;
- diegetic world events: crashes, drops, convoys, hordes, distress calls, fire, power failures и lab breaches;
- aggregate far hordes, group simulation на средней дистанции и реальные entities рядом.

## v0.8 - PvP + Factions

- safe, normal, dangerous и dead zones с разными PvP/loot/threat rules;
- crime score, settlement restrictions, bounty и player hunting;
- military remnants, survivors, raiders, researchers и traders;
- faction reputation от hostile до trusted и distinct rewards;
- professions и player economy без pay-to-win преимуществ.

## v0.9 - Scale / Beta

- region processes и seamless player/entity handoff только когда один world process доказанно недостаточен;
- spatial AOI/interest management;
- zombie LOD: full near, low-frequency mid, aggregate far;
- load bots на 10/25/50/100/250/500 игроков с tick/CPU/RAM/bandwidth/DB telemetry;
- movement/fire/inventory/crafting anomaly detection, duplication audit, rate limits и admin alerts;
- GM panel: players, inventory, position, deaths, reports, bans, events, economy и health, с audit всех actions;
- moderation, reports, mute/ban, filters и evidence metadata;
- environment-driven onboarding, UI overhaul, map discovery и character customization;
- feature freeze на crashes, exploits, economy, backups, mobile UX и compatibility.

## v1.0 - Release Gate

- survival: health/body, hunger, thirst, stamina, weight, food, medicine и basic weather;
- zombies: hearing, vision, pathfinding, search, hordes и variants;
- world: large purposeful map, dynamic events и scarce loot;
- bases: building, storage, power, water и farming;
- transport: vehicles, fuel, repair и storage;
- MMO: friends, parties, clans, trade, market, settlements и economy;
- PvP: safe/danger zones, crime и bounty;
- backend: zones, AOI, load tests, monitoring, backups, moderation и admin tools;
- Windows, Linux, Android и iOS release acceptance.

## Product Boundaries

- no energy timers or paid survival resources;
- no premium damage, weapons, ammo, revives, XP multipliers or PvP immunity;
- acceptable monetization is cosmetic: clothing, skins, emotes, decorations and supporter packs;
- no class lock-in: skills grow through validated actions;
- no infrastructure rewrite before telemetry proves a scaling bottleneck.

## Target Gameplay Loop

```text
prepare food, water and equipment
  -> receive a diegetic lead
  -> assemble a group
  -> travel and loot a purposeful location
  -> gunfire attracts a horde
  -> negotiate or fight another group
  -> treat injuries and recover damaged transport
  -> return resources to specialists, base and settlement
  -> react to a changing persistent world
  -> plan the next expedition
```
