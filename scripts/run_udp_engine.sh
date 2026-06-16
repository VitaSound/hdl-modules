#!/usr/bin/env bash
# Start UDP engine for VST bridge (hdl-modules-tester).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fuser -k 5004/udp 2>/dev/null || true
sleep 0.2

make -C hdl-modules-tester obj_dir/Vgenerator
exec ./hdl-modules-tester/obj_dir/Vgenerator \
  --sample-rate "${SAMPLE_RATE:-48000}" \
  --udp-bind "${UDP_BIND:-0.0.0.0:5004}" \
  "$@"
