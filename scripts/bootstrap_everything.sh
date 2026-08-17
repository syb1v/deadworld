#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${DEADWORLD_TARGET:-$HOME/Projects/deadworld}"

echo "Project Deadworld — workstation + repository bootstrap"
echo "Target: $TARGET"

"$SCRIPT_DIR/setup_dev_env.sh"

if [[ -f "$HOME/.config/deadworld/env.sh" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.config/deadworld/env.sh"
fi

"$SCRIPT_DIR/prepare_repo.sh" "$TARGET"

echo
echo "Running checks..."
"$TARGET/scripts/preflight_repo.sh"
"$TARGET/scripts/check_env.sh" || true

cat <<EOF

Bootstrap completed as far as the current shell permits.

Open this folder in the coding agent:
  $TARGET

Master instructions:
  $TARGET/PASTE_TO_AGENT.md

If Docker permissions were changed, a full logout/login may still be required.
EOF
