# Contributing

## Главная идея

Project Deadworld развивается вертикальными срезами. Предпочтение отдаётся работающей end-to-end функции вместо большого количества незавершённых подсистем.

## Branches

На MVP достаточно:

```text
main
feature/*
fix/*
```

`main` всегда должен быть запускаемым.

## Commit style

Примеры:

```text
chore: bootstrap godot project
chore: add local nakama stack
feat: add device authentication
feat: replicate authoritative movement
feat: add zombie chase state
fix: reject duplicate container pickup
docs: define movement protocol
```

## Definition of Done

Feature считается готовой, если:

- happy path работает;
- invalid input не валит server;
- server validation присутствует;
- reconnect/duplicate request рассмотрены, если релевантно;
- logs позволяют диагностировать проблему;
- tests/checks прошли;
- manual test описан;
- документация обновлена.

## Pull request checklist

- [ ] Scope соответствует текущему milestone.
- [ ] Нет secrets.
- [ ] Нет дублирующего manager/service.
- [ ] Сервер остаётся authoritative.
- [ ] Protocol docs обновлены при wire changes.
- [ ] Tests/checks запущены.
- [ ] Есть понятный manual test.
