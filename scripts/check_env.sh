#!/usr/bin/env bash
set -uo pipefail

ok=0
warn=0
fail=0

green='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
reset='\033[0m'

pass() { printf "${green}[OK]${reset} %s\n" "$*"; ok=$((ok+1)); }
warning() { printf "${yellow}[WARN]${reset} %s\n" "$*"; warn=$((warn+1)); }
failure() { printf "${red}[FAIL]${reset} %s\n" "$*"; fail=$((fail+1)); }

version_cmd() {
  local name="$1"; shift
  if command -v "$name" >/dev/null 2>&1; then
    local out
    out="$("$@" 2>&1 | head -n 1 || true)"
    pass "$name: $out"
  else
    failure "$name not found"
  fi
}

echo "Project Deadworld — environment check"
echo

version_cmd git git --version
version_cmd curl curl --version
version_cmd node node --version
version_cmd npm npm --version

if command -v godot >/dev/null 2>&1; then
  gv="$(godot --version 2>/dev/null | head -n1 || true)"
  pass "godot: $gv"
  if [[ "$gv" != 4.7.1* ]]; then
    warning "Starter pack is pinned to Godot 4.7.1; current: $gv"
  fi
else
  failure "godot not found"
fi

if command -v docker >/dev/null 2>&1; then
  pass "docker: $(docker --version 2>/dev/null | head -n1)"
  if docker compose version >/dev/null 2>&1; then
    pass "docker compose: $(docker compose version 2>/dev/null | head -n1)"
  else
    failure "docker compose plugin not available"
  fi

  if docker info >/dev/null 2>&1; then
    pass "Docker daemon is reachable"
  else
    warning "Docker CLI exists but daemon is not reachable. Start docker or re-login after group change."
  fi
else
  failure "docker not found"
fi

if command -v java >/dev/null 2>&1; then
  jv="$(java -version 2>&1 | head -n1)"
  pass "java: $jv"
  if ! java -version 2>&1 | grep -qE '"17[.]| 17[.]'; then
    warning "Godot Android setup recommends JDK 17; verify JAVA_HOME/JDK selection."
  fi
else
  failure "java not found"
fi

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/Sdk}}"
echo
echo "Android SDK root: $ANDROID_SDK_ROOT"

if [[ -x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]]; then
  pass "sdkmanager found"
else
  failure "sdkmanager missing under $ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
fi

if [[ -x "$ANDROID_SDK_ROOT/platform-tools/adb" ]]; then
  pass "adb found"
else
  failure "adb missing under Android SDK"
fi

for required in \
  "build-tools/35.0.1" \
  "platforms/android-35" \
  "cmake/3.10.2.4988404" \
  "ndk/28.1.13356709"
do
  if [[ -d "$ANDROID_SDK_ROOT/$required" ]]; then
    pass "Android package: $required"
  else
    failure "Android package missing: $required"
  fi
done

template_dir="$HOME/.local/share/godot/export_templates/4.7.1.stable"
if [[ -d "$template_dir" ]] && [[ -n "$(find "$template_dir" -maxdepth 1 -type f -print -quit 2>/dev/null || true)" ]]; then
  pass "Godot 4.7.1 export templates installed"
else
  failure "Godot export templates missing: $template_dir"
fi

echo
echo "Summary: OK=$ok WARN=$warn FAIL=$fail"

if (( fail == 0 )); then
  printf "${green}Environment status: READY${reset}\n"
  exit 0
else
  printf "${red}Environment status: NOT READY${reset}\n"
  echo "Run: ./scripts/setup_dev_env.sh"
  exit 1
fi
