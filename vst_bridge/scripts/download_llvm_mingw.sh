#!/usr/bin/env bash
# Download and extract llvm-mingw for Windows cross-compile (Ubuntu 22.04 x86_64).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLCHAIN_DIR="$ROOT/.toolchains/llvm-mingw"
TC="$TOOLCHAIN_DIR/bin/x86_64-w64-mingw32-clang++"

if [[ -x "$TC" ]]; then
  echo "llvm-mingw already installed at $TOOLCHAIN_DIR"
  exit 0
fi

mkdir -p "$ROOT/.toolchains"
cd "$ROOT/.toolchains"

TAGS=(20260602 20251216 20251202)
for TAG in "${TAGS[@]}"; do
  LLVM_TAR="llvm-mingw-${TAG}-ucrt-ubuntu-22.04-x86_64.tar.xz"
  URL="https://github.com/mstorsje/llvm-mingw/releases/download/${TAG}/${LLVM_TAR}"
  echo "Trying $URL"
  rm -f "$LLVM_TAR"
  if curl --connect-timeout 30 --max-time 600 --retry 3 --retry-delay 5 \
      -fsSL -o "$LLVM_TAR" "$URL"; then
    rm -rf llvm-mingw
    mkdir llvm-mingw
    tar xf "$LLVM_TAR" -C llvm-mingw --strip-components=1
    rm -f "$LLVM_TAR"
    if [[ -x "$TC" ]]; then
      echo "Installed llvm-mingw from release $TAG"
      exit 0
    fi
    echo "Archive extracted but compiler missing, trying next tag..." >&2
    rm -rf llvm-mingw
  else
    echo "Download failed for $TAG" >&2
  fi
done

echo "ERROR: could not download llvm-mingw (tried tags: ${TAGS[*]})" >&2
exit 1
