#!/usr/bin/env bash
set -euo pipefail

: "${ANDROID_KEYSTORE_PATH:?ANDROID_KEYSTORE_PATH is required}"
: "${ANDROID_KEYSTORE_PASSWORD:?ANDROID_KEYSTORE_PASSWORD is required}"
: "${ANDROID_KEY_ALIAS:?ANDROID_KEY_ALIAS is required}"
: "${ANDROID_KEY_PASSWORD:?ANDROID_KEY_PASSWORD is required}"

PRESETS="client/export_presets.cfg"
BACKUP="${PRESETS}.unsigned"
cp "${PRESETS}" "${BACKUP}"
trap 'mv "${BACKUP}" "${PRESETS}"' EXIT

python3 - "${PRESETS}" <<'PY'
import os, pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
signing = (
    f'keystore/release="{os.environ["ANDROID_KEYSTORE_PATH"]}"\n'
    f'keystore/release_user="{os.environ["ANDROID_KEY_ALIAS"]}"\n'
    f'keystore/release_password="{os.environ["ANDROID_KEYSTORE_PASSWORD"]}"\n'
)
text = text.replace('permissions/internet=true', 'permissions/internet=true\n' + signing)
path.write_text(text)
PY

godot --headless --path client --export-release "Android APK"
