#!/usr/bin/env bash
set -Eeuo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.1}"
ANDROID_CMDLINE_REV="15859902"
ANDROID_CMDLINE_SHA256="4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
INSTALL_ANDROID=1
INSTALL_DOCKER=1

usage() {
  cat <<EOF
Project Deadworld development environment installer

Usage:
  $0 [--skip-android] [--skip-docker]

Supported:
  - Arch / CachyOS / Manjaro
  - Debian / Ubuntu / Linux Mint
  - x86_64 Linux

Environment overrides:
  GODOT_VERSION=4.7.1
  ANDROID_SDK_ROOT=\$HOME/Android/Sdk
EOF
}

for arg in "$@"; do
  case "$arg" in
    --skip-android) INSTALL_ANDROID=0 ;;
    --skip-docker) INSTALL_DOCKER=0 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "ERROR: this installer currently supports Linux only." >&2
  exit 1
fi

ARCH="$(uname -m)"
if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
  echo "ERROR: automatic Godot install is currently implemented for x86_64 only. Detected: $ARCH" >&2
  exit 1
fi

SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo is required for system package installation." >&2
    exit 1
  fi
  SUDO="sudo"
fi

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok() { printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[WARN]\033[0m %s\n' "$*"; }

detect_distro() {
  if command -v pacman >/dev/null 2>&1; then
    DISTRO_FAMILY="arch"
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    DISTRO_FAMILY="debian"
    return
  fi

  echo "ERROR: unsupported package manager. Need pacman or apt." >&2
  exit 1
}

install_base_arch() {
  log "Installing base packages with pacman"
  $SUDO pacman -Syu --needed --noconfirm \
    git curl wget unzip zip jq rsync openssh xz \
    ca-certificates base-devel jdk17-openjdk
}

install_base_debian() {
  log "Installing base packages with apt"
  $SUDO apt-get update
  $SUDO apt-get install -y \
    ca-certificates curl wget git unzip zip jq rsync openssh-client \
    xz-utils gnupg lsb-release openjdk-17-jdk build-essential
}

install_docker_arch() {
  log "Installing Docker + Compose with pacman"
  $SUDO pacman -S --needed --noconfirm docker docker-compose
  $SUDO systemctl enable --now docker
}

install_docker_debian() {
  log "Installing Docker Engine from Docker's official apt repository"

  # shellcheck disable=SC1091
  . /etc/os-release

  local docker_os codename
  case "${ID:-}" in
    debian)
      docker_os="debian"
      codename="${VERSION_CODENAME}"
      ;;
    ubuntu)
      docker_os="ubuntu"
      codename="${VERSION_CODENAME}"
      ;;
    linuxmint)
      docker_os="ubuntu"
      codename="${UBUNTU_CODENAME:-${VERSION_CODENAME}}"
      ;;
    *)
      if [[ "${ID_LIKE:-}" == *ubuntu* ]]; then
        docker_os="ubuntu"
        codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
      elif [[ "${ID_LIKE:-}" == *debian* ]]; then
        docker_os="debian"
        codename="${VERSION_CODENAME:-}"
      else
        echo "ERROR: apt is available, but Docker repository mapping is unknown for ID=${ID:-unknown}" >&2
        exit 1
      fi
      ;;
  esac

  if [[ -z "$codename" ]]; then
    echo "ERROR: unable to determine apt codename for Docker." >&2
    exit 1
  fi

  $SUDO apt-get remove -y \
    docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc \
    >/dev/null 2>&1 || true

  $SUDO install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${docker_os}/gpg" \
    | $SUDO tee /etc/apt/keyrings/docker.asc >/dev/null
  $SUDO chmod a+r /etc/apt/keyrings/docker.asc

  local arch
  arch="$(dpkg --print-architecture)"

  echo \
    "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${docker_os} ${codename} stable" \
    | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

  $SUDO apt-get update
  $SUDO apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  $SUDO systemctl enable --now docker
}

configure_docker_user() {
  if ! getent group docker >/dev/null 2>&1; then
    $SUDO groupadd docker
  fi

  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
      $SUDO usermod -aG docker "$USER"
      warn "Added $USER to docker group. Full logout/login may be required."
    fi
  fi
}

install_node() {
  log "Installing Node.js LTS through nvm"

  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  fi

  # shellcheck disable=SC1090
  . "$NVM_DIR/nvm.sh"

  nvm install --lts
  nvm alias default 'lts/*'
  nvm use default

  ok "Node $(node --version), npm $(npm --version)"
}

install_godot() {
  log "Installing Godot ${GODOT_VERSION} stable"

  local base_url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable"
  local zip_name="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
  local templates_name="Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
  local install_dir="$HOME/.local/opt/godot-${GODOT_VERSION}"
  local bin_dir="$HOME/.local/bin"
  local tmp

  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp:-}"' RETURN

  mkdir -p "$install_dir" "$bin_dir"

  curl -fL --retry 3 \
    "$base_url/$zip_name" \
    -o "$tmp/godot.zip"

  rm -rf "$install_dir"/*
  unzip -q "$tmp/godot.zip" -d "$install_dir"

  local exe
  exe="$(find "$install_dir" -maxdepth 1 -type f -name 'Godot*' | head -n1)"
  if [[ -z "$exe" ]]; then
    echo "ERROR: Godot executable not found after extraction." >&2
    exit 1
  fi
  chmod +x "$exe"
  ln -sfn "$exe" "$bin_dir/godot"

  log "Installing Godot export templates"
  curl -fL --retry 3 \
    "$base_url/$templates_name" \
    -o "$tmp/templates.tpz"

  mkdir -p "$tmp/templates"
  unzip -q "$tmp/templates.tpz" -d "$tmp/templates"

  local template_dir="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
  rm -rf "$template_dir"
  mkdir -p "$template_dir"

  if [[ -d "$tmp/templates/templates" ]]; then
    cp -a "$tmp/templates/templates/." "$template_dir/"
  else
    cp -a "$tmp/templates/." "$template_dir/"
  fi

  ok "Godot installed: $("$bin_dir/godot" --version | head -n1)"
}

write_env_file() {
  log "Writing persistent development environment"

  local cfg_dir="$HOME/.config/deadworld"
  local env_file="$cfg_dir/env.sh"
  mkdir -p "$cfg_dir" "$HOME/.local/bin"

  cat >"$env_file" <<EOF
# Project Deadworld development environment
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export PATH="\$HOME/.local/bin:\$ANDROID_SDK_ROOT/platform-tools:\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$PATH"
export NVM_DIR="\${NVM_DIR:-\$HOME/.nvm}"
if [ -s "\$NVM_DIR/nvm.sh" ]; then
  . "\$NVM_DIR/nvm.sh"
fi
EOF

  local marker='source "$HOME/.config/deadworld/env.sh"'
  local rc
  for rc in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc" ]]; then
      if ! grep -Fq "$marker" "$rc"; then
        printf '\n# Project Deadworld dev environment\n%s\n' "$marker" >>"$rc"
      fi
    fi
  done

  # shellcheck disable=SC1090
  . "$env_file"
  ok "Environment file: $env_file"
}

install_android() {
  log "Installing Android command-line tools"

  local url="https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_REV}_latest.zip"
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp:-}"' RETURN

  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"

  curl -fL --retry 3 "$url" -o "$tmp/cmdline-tools.zip"

  local actual_sha
  actual_sha="$(sha256sum "$tmp/cmdline-tools.zip" | awk '{print $1}')"
  if [[ "$actual_sha" != "$ANDROID_CMDLINE_SHA256" ]]; then
    echo "ERROR: Android command-line tools SHA256 mismatch." >&2
    echo "Expected: $ANDROID_CMDLINE_SHA256" >&2
    echo "Actual:   $actual_sha" >&2
    exit 1
  fi

  unzip -q "$tmp/cmdline-tools.zip" -d "$tmp/unpacked"
  rm -rf "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  cp -a "$tmp/unpacked/cmdline-tools/." "$ANDROID_SDK_ROOT/cmdline-tools/latest/"

  export ANDROID_HOME="$ANDROID_SDK_ROOT"
  export ANDROID_SDK_ROOT
  export PATH="$HOME/.local/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"

  local sdkmanager="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"

  echo
  echo "Android SDK requires license acceptance."
  echo "The official sdkmanager will now show licenses interactively."
  echo "Read them and answer y/n yourself."
  echo
  "$sdkmanager" --sdk_root="$ANDROID_SDK_ROOT" --licenses || true

  log "Installing Android packages required by Godot 4.7 Android export"
  "$sdkmanager" --sdk_root="$ANDROID_SDK_ROOT" \
    "platform-tools" \
    "build-tools;35.0.1" \
    "platforms;android-35" \
    "cmdline-tools;latest" \
    "cmake;3.10.2.4988404" \
    "ndk;28.1.13356709"

  ok "Android SDK installed at $ANDROID_SDK_ROOT"
}

main() {
  detect_distro

  case "$DISTRO_FAMILY" in
    arch) install_base_arch ;;
    debian) install_base_debian ;;
  esac

  if (( INSTALL_DOCKER )); then
    case "$DISTRO_FAMILY" in
      arch) install_docker_arch ;;
      debian) install_docker_debian ;;
    esac
    configure_docker_user
  else
    warn "Skipping Docker installation"
  fi

  install_node
  install_godot
  write_env_file

  if (( INSTALL_ANDROID )); then
    install_android
  else
    warn "Skipping Android SDK installation"
  fi

  cat <<'EOF'

============================================================
Project Deadworld development environment setup completed.
============================================================

Next:

  exec "$SHELL" -l

Then from the starter pack/repository:

  ./scripts/check_env.sh

If Docker says permission denied after installation:
  - fully log out from your desktop session and log in again.

Then create your working repo if needed:

  ./scripts/create_repo.sh "$HOME/Projects/deadworld"

EOF
}

main "$@"
