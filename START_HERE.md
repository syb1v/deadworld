# START HERE — Project Deadworld

Цель этого архива: **распаковать → открыть в coding-agent → вставить один master prompt → дать агенту работать**.

Удалённый репозиторий уже существует:

```text
https://github.com/syb1v/deadworld
```

Bootstrap не создаёт новый GitHub-репозиторий и не уничтожает историю. Он клонирует существующий `main`, сохраняет имеющийся `LICENSE`, накладывает starter-pack, создаёт локальный `.env` и проверяет окружение.

## Минимум действий владельца

1. Распаковать архив.
2. Открыть распакованную папку в coding-agent с terminal/shell access.
3. Вставить агенту содержимое `PASTE_TO_AGENT.md`.
4. Разрешить ему выполнять команды.

Ваше участие понадобится только если операционная система или GitHub требуют интерактивное действие:

- ввод sudo-пароля;
- принятие Android SDK licenses;
- GitHub authentication для push, если её ещё нет.

## Если хочется подготовить всё одной командой

```bash
chmod +x scripts/*.sh
./scripts/bootstrap_everything.sh
```

Рабочий clone по умолчанию появится здесь:

```text
~/Projects/deadworld
```

После bootstrap coding-agent должен работать уже **из `~/Projects/deadworld`**, а не из распакованного starter-pack.

## Главные документы

```text
AGENTS.md
docs/GDD.md
docs/MVP.md
docs/ARCHITECTURE.md
docs/PROTOCOL.md
docs/ROADMAP.md
docs/DEV_SETUP.md
docs/REPO_BOOTSTRAP.md
docs/prompts/DAY_01.md
```

При конфликте:

```text
MVP.md
  ↓
ARCHITECTURE.md
  ↓
PROTOCOL.md
  ↓
GDD.md
```
