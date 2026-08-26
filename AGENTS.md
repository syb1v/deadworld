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

## 12. Release/version gate перед commit и push

Любое изменение, которое должно попасть в новый prerelease/release, обязано иметь новый tag в `VERSION`. Нельзя пушить release-bound изменения с прежним `VERSION`: обычный push в `main` запускает проверки, но не публикует приложения.

Перед commit и особенно перед push release-bound изменений агент обязан:

1. увеличить prerelease номер в `VERSION` (например, `v0.1.0-prealpha.6` → `v0.1.0-prealpha.7`);
2. выполнить `python3 scripts/version.py stamp`, чтобы обновить все generated version fields;
3. выполнить `python3 scripts/version.py check` или `make version-check`;
4. проверить `git diff`, чтобы в одном commit были `VERSION` и все затронутые platform metadata;
5. прогнать релевантные tests/build checks;
6. создать annotated tag, строго равный значению `VERSION`;
7. передать в push и commit только согласованные `main` и matching version tag.

`version-stamp` должен обновлять как минимум `client/export_presets.cfg`, `client/scenes/Boot.tscn`, `client/scripts/world/World.gd`, `admin/server.mjs`, `infra/docker-compose.prod.yml` и `.env.example`, если эти файлы содержат version metadata. Не редактируй отдельные версии вручную, если это можно сделать через `scripts/version.py`.

Минимальный release checklist:

```bash
printf 'v0.1.0-prealpha.N\n' > VERSION
python3 scripts/version.py stamp
make version-check
make test
git diff --check
git tag -a "$(python3 scripts/version.py print --field tag)" -m "Release $(python3 scripts/version.py print --field tag)"
git push origin main "$(python3 scripts/version.py print --field tag)"
```

Перед объявлением release опубликованные assets нужно проверить через `gh run list` и `gh release view <tag>`. Если build job не запускался по tag или release не содержит ожидаемые assets, не считать push успешной публикацией.

## 13. Финальный отчёт агента

В конце задачи всегда:

1. Summary.
2. Files changed.
3. Commands/checks executed.
4. Manual test.
5. Known limitations.
6. Следующий логичный task — только назвать, не реализовывать без запроса.
