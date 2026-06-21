#!/usr/bin/env bash
# Build HdlVerilator VST3 on Linux. Requires dev packages (see README).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "${1:-}" == "--clean" || "${CLEAN:-}" == "1" ]]; then
  echo "Clean rebuild: removing build/"
  rm -rf build
fi

if ! command -v cmake >/dev/null; then
  echo "cmake not found. Install: sudo apt install cmake  OR  pip install --user cmake"
  exit 1
fi

# Prefer system CMake (apt); pip cmake 4.x can confuse some generators.
if [[ -x /usr/bin/cmake ]]; then
  CMAKE=/usr/bin/cmake
else
  CMAKE=cmake
fi

if ! command -v pkg-config >/dev/null; then
  echo "pkg-config not found. Install: sudo apt install pkg-config"
  exit 1
fi

missing=()

check_pkg() {
  local pc_name="$1"
  local apt_pkg="$2"
  if ! pkg-config --exists "$pc_name" 2>/dev/null; then
    missing+=("$apt_pkg")
  fi
}

check_header() {
  local header="$1"
  local apt_pkg="$2"
  if [[ ! -f "$header" ]]; then
    missing+=("$apt_pkg")
  fi
}

check_header /usr/include/X11/extensions/Xinerama.h libxinerama-dev
check_pkg fontconfig libfontconfig1-dev
check_pkg gtk+-x11-3.0 libgtk-3-dev
if ! pkg-config --exists webkit2gtk-4.1 2>/dev/null && \
   ! pkg-config --exists webkit2gtk-4.0 2>/dev/null; then
  if apt-cache show libwebkit2gtk-4.1-dev >/dev/null 2>&1; then
    missing+=(libwebkit2gtk-4.1-dev)
  else
    missing+=(libwebkit2gtk-4.0-dev)
  fi
fi
check_pkg libcurl libcurl4-openssl-dev

if ((${#missing[@]} > 0)); then
  # Deduplicate (same pkg may appear twice)
  mapfile -t missing < <(printf '%s\n' "${missing[@]}" | sort -u)
  echo "Missing JUCE build dependencies:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  echo >&2
  echo "Install:" >&2
  echo "  ./scripts/install_linux_deps.sh" >&2
  echo "  # or: sudo apt install -y ${missing[*]}" >&2
  exit 1
fi

"$CMAKE" -B build -DCMAKE_BUILD_TYPE=Release -DCOPY_PLUGIN_AFTER_BUILD=FALSE
BUILD_JOBS="${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc)}"
"$CMAKE" --build build --parallel "$BUILD_JOBS"
VST3_DIR="$ROOT/build/HdlVerilator_artefacts/Release/VST3"
VST3="$(find "$VST3_DIR" -maxdepth 1 -type d -name '*.vst3' | sort | tail -1)"
echo "VST3 bundle: ${VST3:-$VST3_DIR/*.vst3 (not found)}"
