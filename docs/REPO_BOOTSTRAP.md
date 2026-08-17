# Repository Bootstrap

## Remote

```text
https://github.com/syb1v/deadworld
```

Primary branch:

```text
main
```

## Безопасность Git

Запрещено автоматически:

```bash
git push --force
git reset --hard origin/main
rm -rf .git
```

Существующая история и `LICENSE` сохраняются.

## Fresh machine flow

```text
starter-pack
    │
    ├── install dev environment
    │
    └── clone syb1v/deadworld
             │
             └── overlay starter files
                     │
                     ├── preserve LICENSE
                     ├── create local .env
                     └── verify origin
```

## Existing target

Если `~/Projects/deadworld` уже существует:

- если это правильный clone и working tree clean — `fetch`/`pull --ff-only`;
- если есть пользовательские незакоммиченные изменения — остановиться, ничего не уничтожать;
- если origin другой — остановиться;
- если папка не Git repository — остановиться.

## First scaffold commit

После overlay:

```bash
git check-ignore .env
git status
git add .
git diff --cached --name-only
git commit -m "chore: bootstrap deadworld project"
git push -u origin main
```

`.env` не должен попадать в staged files.

## Day 1 commit

Только после реального Definition of Done:

```bash
git add .
git commit -m "feat: add authoritative multiplayer movement"
git push
```
