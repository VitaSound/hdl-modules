#!/usr/bin/env bash
# Cross-compile HdlVerilator VST3 (.dll inside .vst3) for Windows from Ubuntu/WSL.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TOOLCHAIN_DIR="$ROOT/.toolchains/llvm-mingw"
LLVM_TAR="llvm-mingw-20251216-ucrt-ubuntu-22.04-x86_64.tar.xz"
LLVM_URL="https://github.com/mstorsje/llvm-mingw/releases/download/20251216/$LLVM_TAR"

if [[ -x /usr/bin/cmake ]]; then
  CMAKE=/usr/bin/cmake
else
  CMAKE=cmake
fi

ensure_llvm_mingw() {
  if [[ -x "$TOOLCHAIN_DIR/bin/x86_64-w64-mingw32-clang++" ]]; then
    return 0
  fi
  echo "Downloading llvm-mingw (~78 MB, one-time)..."
  mkdir -p "$ROOT/.toolchains"
  cd "$ROOT/.toolchains"
  curl -fsSL -o "$LLVM_TAR" "$LLVM_URL"
  rm -rf llvm-mingw
  mkdir llvm-mingw
  tar xf "$LLVM_TAR" -C llvm-mingw --strip-components=1
  rm -f "$LLVM_TAR"
}

if [[ "${USE_APT_MINGW:-}" == "1" ]] && command -v x86_64-w64-mingw32-g++-posix >/dev/null; then
  TOOLCHAIN_FILE="$ROOT/cmake/mingw-w64.cmake"
  echo "Using apt MinGW-w64 POSIX (USE_APT_MINGW=1)"
  ensure_llvm_mingw
elif [[ -x "$TOOLCHAIN_DIR/bin/x86_64-w64-mingw32-clang++" ]] || ensure_llvm_mingw; then
  TOOLCHAIN_FILE="$ROOT/cmake/llvm-mingw.cmake"
  export LLVM_MINGW="$TOOLCHAIN_DIR"
  echo "Using llvm-mingw at $TOOLCHAIN_DIR (recommended for JUCE 8 / Direct2D 1.3)"
elif command -v x86_64-w64-mingw32-g++-posix >/dev/null; then
  echo "ERROR: only apt MinGW found; JUCE 8 needs newer Windows SDK headers." >&2
  echo "Re-run without USE_APT_MINGW or delete .toolchains/llvm-mingw to re-download." >&2
  exit 1
elif command -v x86_64-w64-mingw32-g++ >/dev/null; then
  echo "ERROR: only win32 MinGW found; JUCE needs POSIX thread model." >&2
  echo "Run: sudo update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix" >&2
  echo "     sudo update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix" >&2
  exit 1
else
  echo "ERROR: no Windows cross-compiler found." >&2
  echo "Install: sudo apt install mingw-w64 curl" >&2
  exit 1
fi

BUILD_DIR=build-win

if [[ "${1:-}" == "--clean" || "${CLEAN:-}" == "1" ]]; then
  echo "Clean rebuild: removing $BUILD_DIR"
  rm -rf "$BUILD_DIR"
elif [[ -d "$BUILD_DIR" ]]; then
  echo "Incremental build in $BUILD_DIR (use --clean for full rebuild)"
fi

CMAKE_ARGS=(
  -B "$BUILD_DIR"
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE"
  -DCMAKE_BUILD_TYPE=Release
  -DCOPY_PLUGIN_AFTER_BUILD=FALSE
)
if [[ -n "${LLVM_MINGW:-}" ]]; then
  CMAKE_ARGS+=(-DLLVM_MINGW="$LLVM_MINGW")
fi

SECONDS=0
"$CMAKE" "${CMAKE_ARGS[@]}"
"$CMAKE" --build "$BUILD_DIR" --parallel "$(nproc)"
echo "Build finished in ${SECONDS}s"

VST3_DIR="$BUILD_DIR/HdlVerilator_artefacts/Release/VST3"
VST3="$(find "$VST3_DIR" -maxdepth 1 -type d -name '*.vst3' | sort | tail -1)"
if [[ -z "$VST3" ]]; then
  echo "ERROR: no .vst3 bundle under $VST3_DIR" >&2
  exit 1
fi
VST3_NAME="$(basename "$VST3")"
DLL="$(find "$VST3" -name '*.dll' -print -quit 2>/dev/null || true)"

echo
echo "Windows VST3 bundle: $VST3"
if [[ -n "$DLL" ]]; then
  echo "Windows DLL: $DLL"
fi
echo
echo "Install on Windows (remove OLD HdlVerilator.vst3 if present):"
echo "  rm -rf \"/mnt/c/Program Files/Common Files/VST3/HdlVerilator.vst3\""
echo "  rm -rf \"/mnt/c/Program Files/Common Files/VST3/$VST3_NAME\""
echo "  cp -r \"$VST3\" \"/mnt/c/Program Files/Common Files/VST3/\""
echo "Then rescan plugins in the DAW (Reaper: Clear cache / rescan)."
