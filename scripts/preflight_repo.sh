#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

fail() { echo "[FAIL] $*" >&2; exit 1; }
ok() { echo "[OK] $*"; }

origin="$(git remote get-url origin 2>/dev/null || true)"
case "$origin" in
  "https://github.com/syb1v/deadworld"|"git@github.com:syb1v/deadworld.git") ok "origin: $origin" ;;
  *) fail "unexpected origin: ${origin:-none}" ;;
esac

[[ "$(git branch --show-current)" == "main" ]] || fail "current branch is not main"

if [[ -f .env ]]; then
  git check-ignore .env >/dev/null || fail ".env exists but is not ignored"
  ok ".env ignored"
fi

for f in \
  START_HERE.md AGENTS.md README.md \
  docs/GDD.md docs/MVP.md docs/ARCHITECTURE.md \
  docs/PROTOCOL.md docs/ROADMAP.md docs/REPO_BOOTSTRAP.md \
  docs/prompts/DAY_01.md PASTE_TO_AGENT.md
do
  [[ -f "$f" ]] || fail "missing $f"
  ok "$f"
done

echo
git status --short
echo
echo "Repository preflight: READY"
