#!/usr/bin/env bash
# Start MiniFX UDP engine (insert SVF filter test rig).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fuser -k 5004/udp 2>/dev/null || true
sleep 0.2

make -C synths/mini_fx obj_dir/MiniFX
exec ./synths/mini_fx/obj_dir/MiniFX \
  --sample-rate "${SAMPLE_RATE:-44100}" \
  --udp-bind "${UDP_BIND:-0.0.0.0:5004}" \
  "$@"
