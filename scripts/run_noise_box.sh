#!/usr/bin/env bash
# Start NoiseBox UDP engine (synths/noise_box).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fuser -k 5004/udp 2>/dev/null || true
sleep 0.2

make -C synths/noise_box obj_dir/NoiseBox
exec ./synths/noise_box/obj_dir/NoiseBox \
  --sample-rate "${SAMPLE_RATE:-48000}" \
  --udp-bind "${UDP_BIND:-0.0.0.0:5004}" \
  "$@"
