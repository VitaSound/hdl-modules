#!/usr/bin/env bash
# Copy freshly built Windows VST3 into Common Files and remove stale HdlVerilator.vst3.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build-win"
VST3_DIR="$BUILD_DIR/HdlVerilator_artefacts/Release/VST3"
DEST="/mnt/c/Program Files/Common Files/VST3"

VST3="$(find "$VST3_DIR" -maxdepth 1 -type d -name '*.vst3' | sort | tail -1)"
if [[ -z "$VST3" ]]; then
  echo "ERROR: build first: ./scripts/build_windows_mingw.sh" >&2
  exit 1
fi

if [[ ! -d /mnt/c/Program\ Files/Common\ Files/VST3 ]]; then
  echo "ERROR: $DEST not found (run from WSL with C: mounted)" >&2
  exit 1
fi

NAME="$(basename "$VST3")"
echo "Removing old bundles (if any)..."
rm -rf "$DEST/HdlVerilator.vst3" "$DEST/$NAME"
echo "Installing $NAME ..."
cp -r "$VST3" "$DEST/"
echo "Done: $DEST/$NAME"
echo "Rescan plugins in Reaper (Preferences -> Plug-ins -> VST -> Clear cache / rescan)."
