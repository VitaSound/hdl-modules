#!/usr/bin/env bash
# Build VitaSound Remote Synth VST3 for Linux + Windows and pack release zips.
#
# Usage:
#   ./scripts/build_release.sh              # both platforms
#   ./scripts/build_release.sh --clean      # clean rebuild both
#   ./scripts/build_release.sh --linux-only
#   ./scripts/build_release.sh --windows-only
#   ./scripts/build_release.sh --skip-build # package existing build/ artifacts
#
# Output: vst_bridge/dist/VitaSound-Remote-Synth-<ver>-{linux,windows}-x86_64.zip
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SCRIPTS="$ROOT/scripts"

PRODUCT_SLUG="VitaSound-Remote-Synth"
DIST_DIR="$ROOT/dist"

DO_LINUX=1
DO_WINDOWS=1
DO_CLEAN=0
SKIP_BUILD=0

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --linux-only) DO_WINDOWS=0 ;;
    --windows-only) DO_LINUX=0 ;;
    --clean) DO_CLEAN=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    -h|--help) usage 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage 1
      ;;
  esac
  shift
done

read_version() {
  local line
  line="$(grep -E '^project\(HdlVerilator VERSION ' "$ROOT/CMakeLists.txt" | head -1)"
  if [[ "$line" =~ VERSION[[:space:]]+([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  echo "ERROR: cannot parse VERSION from CMakeLists.txt" >&2
  exit 1
}

find_vst3_bundle() {
  local vst3_dir="$1"
  find "$vst3_dir" -maxdepth 1 -type d -name '*.vst3' | sort | tail -1
}

write_install_txt() {
  local dest="$1"
  local platform="$2"
  cat >"$dest/INSTALL.txt" <<EOF
VitaSound Remote Synth VST3
Version: $VERSION
Platform: $platform

Install
-------
Linux (Reaper / Bitwig):
  unzip VitaSound-Remote-Synth-${VERSION}-linux-x86_64.zip
  cp -r "VitaSound Remote Synth.vst3" ~/.vst3/
  rescan plugins in your DAW

Windows (Reaper / FL Studio):
  unzip VitaSound-Remote-Synth-${VERSION}-windows-x86_64.zip
  copy "VitaSound Remote Synth.vst3" to:
    C:\\Program Files\\Common Files\\VST3\\
  remove old HdlVerilator.vst3 if present
  rescan plugins (Reaper: Clear cache / rescan)

Runtime
-------
  Engine host: 127.0.0.1 (native Windows engine)
  UDP ports: 5004 (control), 5005 (audio)
  Network profile: Local (native engine) or WSL for engine in WSL2
  Reserve packets: auto-tuned; pull protocol v2

Docs: https://github.com/UA3MQJ/hdl-modules/tree/master/vst_bridge
EOF
}

package_release() {
  local platform="$1"   # linux | windows
  local vst3="$2"
  local zip_name="${PRODUCT_SLUG}-${VERSION}-${platform}-x86_64.zip"
  local staging="$DIST_DIR/staging-${platform}"
  local bundle_name
  bundle_name="$(basename "$vst3")"

  rm -rf "$staging"
  mkdir -p "$staging"
  cp -a "$vst3" "$staging/"
  write_install_txt "$staging" "$platform"

  mkdir -p "$DIST_DIR"
  rm -f "$DIST_DIR/$zip_name"
  (cd "$staging" && zip -rq "$DIST_DIR/$zip_name" "$bundle_name" INSTALL.txt)

  rm -rf "$staging"
  echo "Release: $DIST_DIR/$zip_name"
  ls -lh "$DIST_DIR/$zip_name"
}

if ! command -v zip >/dev/null; then
  echo "ERROR: zip not found. Install: sudo apt install zip" >&2
  exit 1
fi

VERSION="$(read_version)"
echo "=== VitaSound Remote Synth release v${VERSION} ==="
echo "Output directory: $DIST_DIR"
echo

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  CLEAN_ARG=()
  [[ "$DO_CLEAN" -eq 1 ]] && CLEAN_ARG=(--clean)

  if [[ "$DO_LINUX" -eq 1 ]]; then
    echo "--- Linux build ---"
    "$SCRIPTS/build_linux.sh" "${CLEAN_ARG[@]}"
    echo
  fi

  if [[ "$DO_WINDOWS" -eq 1 ]]; then
    echo "--- Windows cross-build ---"
    "$SCRIPTS/build_windows_mingw.sh" "${CLEAN_ARG[@]}"
    echo
  fi
fi

if [[ "$DO_LINUX" -eq 1 ]]; then
  LINUX_VST3="$(find_vst3_bundle "$ROOT/build/HdlVerilator_artefacts/Release/VST3")"
  if [[ -z "$LINUX_VST3" || ! -d "$LINUX_VST3" ]]; then
    echo "ERROR: Linux VST3 not found under build/. Run build or drop --skip-build." >&2
    exit 1
  fi
  echo "--- Packaging Linux ---"
  package_release linux "$LINUX_VST3"
  echo
fi

if [[ "$DO_WINDOWS" -eq 1 ]]; then
  WIN_VST3="$(find_vst3_bundle "$ROOT/build-win/HdlVerilator_artefacts/Release/VST3")"
  if [[ -z "$WIN_VST3" || ! -d "$WIN_VST3" ]]; then
    echo "ERROR: Windows VST3 not found under build-win/. Run build or drop --skip-build." >&2
    exit 1
  fi
  echo "--- Packaging Windows ---"
  package_release windows "$WIN_VST3"
  echo
fi

echo "Done. Archives in $DIST_DIR/"
