#!/usr/bin/env bash
# Package Verilator engine binaries for GitHub release.
# Usage:
#   PACKAGE_TARGET=<target> ./scripts/package_engine_release.sh <version> <staging_dir>
#
# Targets:
#   tester-linux | tester-windows | legacy-linux
#   engine-mono_synth-linux | engine-mono_synth-windows
#   engine-mini_fx-linux | engine-mini_fx-windows
#   engine-noise_box-linux | engine-noise_box-windows
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

package_linux_bin() {
  local bin="$1"
  local out_name="$2"
  local slug="$3"
  local readme_body="$4"
  local out="$STAGING/${slug}-${VERSION}-linux-x86_64.zip"
  local out_abs="$ROOT/$out"
  local stage="$STAGING/stage-${slug}-linux"

  if [[ ! -x "$bin" ]]; then
    echo "ERROR: missing $bin" >&2
    exit 1
  fi

  rm -rf "$stage"
  mkdir -p "$stage"
  cp "$bin" "$stage/$out_name"
  chmod +x "$stage/$out_name"
  write_readme "$stage" "$slug" "$readme_body"
  rm -f "$out_abs"
  mkdir -p "$(dirname "$out_abs")"
  (cd "$stage" && zip -rq "$out_abs" "$out_name" README.txt)
  rm -rf "$stage"
  echo "Packaged $out_abs"
}

package_windows_bin() {
  local bin="$1"
  local out_name="$2"
  local slug="$3"
  local readme_body="$4"
  local out="$STAGING/${slug}-${VERSION}-windows-x86_64.zip"
  local out_abs="$ROOT/$out"
  local stage="$STAGING/stage-${slug}-win"

  if [[ ! -f "$bin" ]]; then
    echo "ERROR: missing $bin" >&2
    exit 1
  fi

  rm -rf "$stage"
  mkdir -p "$stage"
  cp "$bin" "$stage/$out_name"
  write_readme "$stage" "$slug" "$readme_body"
  rm -f "$out_abs"
  mkdir -p "$(dirname "$out_abs")"
  (cd "$stage" && zip -rq "$out_abs" "$out_name" README.txt)
  rm -rf "$stage"
  echo "Packaged $out_abs"
}

engine_readme() {
  local id="$1"
  local kind="$2"
  cat <<EOF
VitaSound UDP engine (${kind}).

Public binary: VitaSound-Engine-${id}
Source: synths/${id}/
Sample rate: 48000 (match DAW project)

Run:
  ./VitaSound-Engine-${id} --udp-bind 0.0.0.0:5004 --sample-rate 48000
  # Windows: VitaSound-Engine-${id}.exe ...

DAW:
  1. Install VitaSound Remote VST3
  2. Project sample rate 48000, buffer 512-1024
  3. Insert VitaSound Remote (effect) on MIDI (synth) or audio (fx) track
  4. Engine host 127.0.0.1, Play / Test note

Only one engine may bind UDP :5004.
Docs: docs/ENGINES.md
EOF
}

INTERNAL_BIN_NAME() {
  case "$1" in
    mono_synth) echo MonoSynth ;;
    mini_fx) echo MiniFX ;;
    noise_box) echo NoiseBox ;;
  esac
}

KIND_FOR() {
  case "$1" in
    mini_fx) echo fx ;;
    *) echo synth ;;
  esac
}

package_engine_linux() {
  local id="$1"
  local internal
  internal="$(INTERNAL_BIN_NAME "$id")"
  local public="VitaSound-Engine-${id}"
  local slug="$public"
  package_linux_bin \
    "$ROOT/synths/$id/obj_dir/$internal" \
    "$public" \
    "$slug" \
    "$(engine_readme "$id" "$(KIND_FOR "$id")")"
}

package_engine_windows() {
  local id="$1"
  local public="VitaSound-Engine-${id}"
  local slug="$public"
  package_windows_bin \
    "$ROOT/synths/$id/obj_dir_win/${public}.exe" \
    "${public}.exe" \
    "$slug" \
    "$(engine_readme "$id" "$(KIND_FOR "$id")")"
}

case "${PACKAGE_TARGET:?}" in
  tester-linux)
    package_linux_bin \
      "$ROOT/hdl-modules-tester/obj_dir/Vgenerator" \
      Vgenerator \
      HdlModulesTester \
      "UDP pull-only MVP engine (internal / CI). Prefer VitaSound-Engine-* for demos.

Run:
  ./Vgenerator --udp-bind 0.0.0.0:5004 --sample-rate 48000"
    ;;
  tester-windows)
    package_windows_bin \
      "$ROOT/hdl-modules-tester/obj_dir_win/Vgenerator.exe" \
      Vgenerator.exe \
      HdlModulesTester \
      "UDP pull-only MVP engine (internal / CI). Prefer VitaSound-Engine-* for demos.

Run:
  Vgenerator.exe --udp-bind 0.0.0.0:5004 --sample-rate 48000"
    ;;
  legacy-linux)
    package_linux_bin \
      "$ROOT/verilator_tests/obj_dir/Vgenerator" \
      Vgenerator \
      VgeneratorLegacy \
      "Legacy local synth: keyboard/MIDI -> soundcard/WAV (Linux).

Requires: portaudio, ALSA (libasound).

Example:
  ./Vgenerator --input-source midi --output-mode wav"
    ;;
  engine-mono_synth-linux) package_engine_linux mono_synth ;;
  engine-mono_synth-windows) package_engine_windows mono_synth ;;
  engine-mini_fx-linux) package_engine_linux mini_fx ;;
  engine-mini_fx-windows) package_engine_windows mini_fx ;;
  engine-noise_box-linux) package_engine_linux noise_box ;;
  engine-noise_box-windows) package_engine_windows noise_box ;;
  *)
    echo "Unknown PACKAGE_TARGET=$PACKAGE_TARGET" >&2
    exit 1
    ;;
esac
