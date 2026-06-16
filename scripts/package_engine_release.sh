#!/usr/bin/env bash
# Package Verilator engine binaries for GitHub release.
# Usage: ./scripts/package_engine_release.sh <version> <staging_dir>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?version required}"
STAGING="${2:?staging dir required}"

mkdir -p "$STAGING"

write_readme() {
  local dest="$1"
  local title="$2"
  local body="$3"
  cat >"$dest/README.txt" <<EOF
$title v$VERSION

$body
EOF
}

package_linux() {
  local project="$1"
  local slug="$2"
  local bin="$ROOT/$project/obj_dir/Vgenerator"
  local out="$STAGING/${slug}-${VERSION}-linux-x86_64.zip"
  local out_abs="$ROOT/$out"
  local stage="$STAGING/stage-${slug}-linux"

  if [[ ! -x "$bin" ]]; then
    echo "ERROR: missing $bin" >&2
    exit 1
  fi

  rm -rf "$stage"
  mkdir -p "$stage"
  cp "$bin" "$stage/Vgenerator"
  chmod +x "$stage/Vgenerator"
  write_readme "$stage" "$slug" "$3"
  rm -f "$out_abs"
  mkdir -p "$(dirname "$out_abs")"
  (cd "$stage" && zip -rq "$out_abs" Vgenerator README.txt)
  rm -rf "$stage"
  echo "Packaged $out_abs"
}

package_windows() {
  local project="$1"
  local slug="$2"
  local bin="$ROOT/$project/obj_dir_win/Vgenerator.exe"
  local out="$STAGING/${slug}-${VERSION}-windows-x86_64.zip"
  local out_abs="$ROOT/$out"
  local stage="$STAGING/stage-${slug}-win"

  if [[ ! -f "$bin" ]]; then
    echo "ERROR: missing $bin" >&2
    exit 1
  fi

  rm -rf "$stage"
  mkdir -p "$stage"
  cp "$bin" "$stage/Vgenerator.exe"
  write_readme "$stage" "$slug" "$3"
  rm -f "$out_abs"
  mkdir -p "$(dirname "$out_abs")"
  (cd "$stage" && zip -rq "$out_abs" Vgenerator.exe README.txt)
  rm -rf "$stage"
  echo "Packaged $out_abs"
}

case "${PACKAGE_TARGET:?}" in
  tester-linux)
    package_linux hdl-modules-tester HdlModulesTester \
      "UDP pull-only engine for VitaSound Remote Synth.

Run:
  ./Vgenerator --udp-bind 0.0.0.0:5004 --sample-rate 48000

Or from repo root: ./scripts/run_udp_engine.sh"
    ;;
  tester-windows)
    package_windows hdl-modules-tester HdlModulesTester \
      "UDP pull-only engine for VitaSound Remote Synth (Windows).

Run:
  Vgenerator.exe --udp-bind 0.0.0.0:5004 --sample-rate 48000

VST Engine host: 127.0.0.1 (profile Local)"
    ;;
  legacy-linux)
    package_linux verilator_tests VgeneratorLegacy \
      "Legacy local synth: keyboard/MIDI -> soundcard/WAV (Linux).

Requires: portaudio, ALSA (libasound).

Example:
  ./Vgenerator --input-source midi --output-mode wav"
    ;;
  *)
    echo "Unknown PACKAGE_TARGET=$PACKAGE_TARGET" >&2
    exit 1
    ;;
esac
