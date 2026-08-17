#!/usr/bin/env bash
set -Eeuo pipefail

REMOTE_URL="${DEADWORLD_REMOTE_URL:-https://github.com/syb1v/deadworld}"
TARGET="${1:-$HOME/Projects/deadworld}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\033[0;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git is not installed"
command -v rsync >/dev/null 2>&1 || die "rsync is not installed"

mkdir -p "$(dirname "$TARGET")"

if [[ ! -e "$TARGET" ]]; then
  log "Cloning existing repository"
  git clone "$REMOTE_URL" "$TARGET"
elif [[ -d "$TARGET/.git" ]]; then
  log "Existing Git repository found: $TARGET"
  origin="$(git -C "$TARGET" remote get-url origin 2>/dev/null || true)"
  if [[ "$origin" != "$REMOTE_URL" && "$origin" != "git@github.com:syb1v/deadworld.git" ]]; then
    die "Unexpected origin '$origin'. Refusing to modify target."
  fi
  if [[ -n "$(git -C "$TARGET" status --porcelain)" ]]; then
    die "Target has uncommitted changes. Refusing to overwrite them."
  fi
  git -C "$TARGET" fetch origin
  if [[ "$(git -C "$TARGET" branch --show-current)" == "main" ]]; then
    git -C "$TARGET" pull --ff-only origin main
  fi
else
  die "Target exists but is not a Git repository: $TARGET"
fi

log "Overlaying starter pack"
rsync -a --no-owner --no-group \
  --exclude='.git/' \
  --exclude='.env' \
  --exclude='LICENSE' \
  --exclude='SHA256SUMS.txt' \
  "$PACK_ROOT/" "$TARGET/"

find "$TARGET/scripts" -maxdepth 1 -type f -name '*.sh' -exec chmod +x {} \;

if [[ ! -f "$TARGET/.env" ]]; then
  cp "$TARGET/.env.example" "$TARGET/.env"
  chmod 600 "$TARGET/.env"
fi

origin="$(git -C "$TARGET" remote get-url origin)"
branch="$(git -C "$TARGET" branch --show-current)"

echo
echo "Repository prepared:"
echo "  path:   $TARGET"
echo "  origin: $origin"
echo "  branch: $branch"

git -C "$TARGET" check-ignore .env >/dev/null || die ".env is not ignored"

echo
git -C "$TARGET" status --short
echo
echo "Next:"
echo "  cd \"$TARGET\""
echo "  ./scripts/preflight_repo.sh"
echo "  ./scripts/check_env.sh"
