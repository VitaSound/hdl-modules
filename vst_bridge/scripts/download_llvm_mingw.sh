#!/usr/bin/env bash
# Install llvm-mingw for Windows cross-compile (Ubuntu 22.04 x86_64 host).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLCHAIN_DIR="$ROOT/.toolchains/llvm-mingw"
TC="$TOOLCHAIN_DIR/bin/x86_64-w64-mingw32-clang++"
IMAGE="${LLVM_MINGW_DOCKER_IMAGE:-mstorsjo/llvm-mingw:20251216}"

if [[ -x "$TC" ]]; then
  echo "llvm-mingw already installed at $TOOLCHAIN_DIR"
  exit 0
fi

install_from_docker() {
  if ! command -v docker >/dev/null; then
    return 1
  fi
  echo "Pulling $IMAGE ..."
  docker pull "$IMAGE"
  mkdir -p "$ROOT/.toolchains"
  rm -rf "$ROOT/.toolchains/llvm-mingw" "$ROOT/.toolchains/opt"
  docker run --rm "$IMAGE" tar -cf - /opt/llvm-mingw | tar -xf - -C "$ROOT/.toolchains"
  mv "$ROOT/.toolchains/opt/llvm-mingw" "$TOOLCHAIN_DIR"
  rm -rf "$ROOT/.toolchains/opt"
  [[ -x "$TC" ]]
}

install_from_github() {
  mkdir -p "$ROOT/.toolchains"
  cd "$ROOT/.toolchains"
  local TAGS=(20260602 20251216 20251202)
  for TAG in "${TAGS[@]}"; do
    local LLVM_TAR="llvm-mingw-${TAG}-ucrt-ubuntu-22.04-x86_64.tar.xz"
    local URL="https://github.com/mstorsje/llvm-mingw/releases/download/${TAG}/${LLVM_TAR}"
    echo "Trying $URL"
    rm -f "$LLVM_TAR"
    if curl --connect-timeout 30 --max-time 600 --retry 3 --retry-delay 5 \
        -fsSL -o "$LLVM_TAR" "$URL"; then
      rm -rf llvm-mingw
      mkdir llvm-mingw
      tar xf "$LLVM_TAR" -C llvm-mingw --strip-components=1
      rm -f "$LLVM_TAR"
      [[ -x "$TC" ]] && return 0
      rm -rf llvm-mingw
    fi
  done
  return 1
}

if install_from_docker; then
  echo "Installed llvm-mingw from Docker image $IMAGE"
  exit 0
fi

if install_from_github; then
  echo "Installed llvm-mingw from GitHub release"
  exit 0
fi

echo "ERROR: could not install llvm-mingw (docker and GitHub download failed)" >&2
exit 1
