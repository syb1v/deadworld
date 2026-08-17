# Security

## Secrets

Не коммитить:

- `.env`;
- production credentials;
- PostgreSQL passwords;
- signing keys;
- Android release keystores;
- TLS private keys;
- Nakama server/admin secrets;
- SSH private keys.

## Client trust

Клиент считается потенциально модифицированным.

Любое действие клиента может быть:

- повторено;
- задержано;
- изменено;
- отправлено слишком часто;
- отправлено с невозможными значениями.

Поэтому gameplay mutation валидирует сервер.

## MVP anti-abuse baseline

Минимум:

- movement bounds;
- rate limits;
- max packet/message size;
- opcode validation;
- inventory ownership validation;
- container versioning;
- structured audit logs для критичных mutations.

## Vulnerability reports

До появления публичного security contact не публиковать реальные production secrets в issue. Для pre-alpha использовать приватный канал владельца проекта.
