# Development setup

## Supported local Linux families

Installer currently targets:

- Arch / CachyOS / Manjaro;
- Debian / Ubuntu / Linux Mint.

Другие системы можно настроить вручную по этому документу.

## Required tools

### Core

- Git
- curl / wget
- unzip / zip
- jq
- rsync
- Docker Engine
- Docker Compose
- Node.js LTS + npm
- Godot 4.7.1 stable
- Godot export templates

### Android

- OpenJDK 17
- Android SDK Command-line Tools
- Platform Tools
- Build Tools 35.0.1
- Platform 35
- CMake 3.10.2.4988404
- NDK 28.1.13356709

## Automated setup

```bash
chmod +x scripts/*.sh
./scripts/setup_dev_env.sh
```

Skip Android:

```bash
./scripts/setup_dev_env.sh --skip-android
```

Skip Docker:

```bash
./scripts/setup_dev_env.sh --skip-docker
```

Custom Godot maintenance version:

```bash
GODOT_VERSION=4.7.1 ./scripts/setup_dev_env.sh
```

## Environment file

Installer creates:

```text
~/.config/deadworld/env.sh
```

It exports:

```bash
ANDROID_HOME
ANDROID_SDK_ROOT
PATH additions
```

Installer attempts to source this file from `.profile`, `.bashrc` and `.zshrc` when those files exist.

Reload:

```bash
exec "$SHELL" -l
```

## Verify

```bash
./scripts/check_env.sh
```

Manual useful commands:

```bash
godot --version
docker --version
docker compose version
node --version
npm --version
java -version
adb version
sdkmanager --version
```

## Docker permissions

If installer adds the current user to `docker`, the new group membership may require a full logout/login.

Do not work around this with:

```bash
sudo chmod 666 /var/run/docker.sock
```

## Android SDK licenses

The script intentionally invokes official interactive license acceptance rather than silently accepting licenses.

After acceptance it installs the package set required by the chosen Godot 4.7 Android setup.

## Android device test

On phone:

- enable Developer options;
- enable USB debugging;
- connect cable;
- approve host.

Then:

```bash
adb devices
```

Device should show as `device`, not `unauthorized`.

## Godot Android editor paths

If Godot does not autodetect them, set:

```text
Java SDK Path    -> JDK 17 location
Android SDK Path -> ~/Android/Sdk
```

## iOS

iOS is intentionally not automated by this Linux script.

Нужны:

- macOS;
- Xcode;
- Apple signing configuration.

Архитектура клиента остаётся общей, но iOS build не блокирует недельный MVP.


## Existing GitHub repository

Remote уже существует:

```text
https://github.com/syb1v/deadworld
```

Подготовить clone:

```bash
./scripts/prepare_repo.sh "$HOME/Projects/deadworld"
```

Установить окружение + подготовить clone:

```bash
./scripts/bootstrap_everything.sh
```

Существующий `LICENSE` сохраняется.
