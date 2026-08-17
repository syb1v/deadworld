# AGENTS.md — правила для AI coding agents

Этот файл обязателен для любого coding-agent, работающего с репозиторием.

## 1. Перед изменениями

Всегда:

1. прочитай `docs/MVP.md`;
2. прочитай релевантные части `docs/ARCHITECTURE.md`;
3. если меняешь networking — прочитай `docs/PROTOCOL.md`;
4. осмотри существующий tree и найди уже существующие реализации;
5. сформулируй минимальный Definition of Done.

Не начинай с массового создания файлов.

## 2. Server authoritative — непреложный инвариант

Клиент не является source of truth для:

- position;
- movement speed;
- HP;
- damage;
- ammo;
- item ownership;
- inventory mutations;
- loot;
- container contents;
- zombie state;
- cooldowns;
- death;
- world persistence.

Клиент отправляет **input/intention**. Сервер валидирует и применяет результат.

## 3. Не раздувать scope

Если задача говорит Day 1 — реализуется Day 1.

Запрещено добавлять «заодно»:

- inventory в movement task;
- clans в auth task;
- Redis/Kafka/Kubernetes;
- сложный DI framework;
- plugin system;
- ECS rewrite без доказанной необходимости.

## 4. Один source of truth

Нельзя создавать:

```text
NetworkManager.gd
NetworkManagerNew.gd
NetworkManager2.gd
NetworkingService.gd
NetworkFix.gd
```

Если система уже существует — расширяй или рефактори её осознанно.

Централизовать:

- opcodes;
- protocol version;
- item IDs/definitions;
- environment variable names;
- build/version identifiers.

## 5. Изменения должны быть маленькими

Перед патчем перечисли:

- какие файлы изменяешь;
- зачем;
- какой test подтвердит результат.

После патча:

- запусти build/lint/test;
- исправь ошибки;
- дай manual test для того, что автоматикой не проверяется.

## 6. Не выдумывать API

Если API Godot/Nakama/SDK не уверен:

- проверь установленную версию;
- используй её документацию;
- не создавай фиктивные методы ради того, чтобы код выглядел законченным.

## 7. Secrets

Никогда не коммитить:

- `.env`;
- DB passwords;
- server keys;
- admin credentials;
- signing keystores;
- private certificates;
- service-account JSON.

Допустим только `.env.example` с безопасными placeholders.

## 8. Persistence

Любая операция, способная создать dupe/loss, рассматривается как transactional boundary.

Особое внимание:

- pickup;
- drop;
- container transfer;
- trade;
- death;
- reconnect;
- shutdown;
- retry после timeout.

## 9. Protocol compatibility

При несовместимом wire change:

- обновить `PROTOCOL_VERSION`;
- обновить `docs/PROTOCOL.md`;
- явно указать migration/compatibility impact.

## 10. Code style

- понятные имена;
- небольшие функции;
- минимум скрытого global state;
- комментарии объясняют «почему», а не переписывают код словами;
- placeholders помечаются `TODO(MVP)` или `TODO(post-MVP)`.

## 11. Documentation is code

Если изменился:

- запуск;
- env;
- порт;
- protocol;
- архитектурный invariant;
- dependency version;

обнови соответствующую документацию в том же change.

## 12. Финальный отчёт агента

В конце задачи всегда:

1. Summary.
2. Files changed.
3. Commands/checks executed.
4. Manual test.
5. Known limitations.
6. Следующий логичный task — только назвать, не реализовывать без запроса.
