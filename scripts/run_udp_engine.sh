#!/usr/bin/env bash
# Start Verilator engine in UDP mode (MIDI in, PCM out).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Kill stale engine instances that block UDP 5004 and ignore Ctrl+C.
fuser -k 5004/udp 2>/dev/null || true
sleep 0.2

make -C verilator_tests obj_dir/Vgenerator
exec ./verilator_tests/obj_dir/Vgenerator \
  --input-source udp \
  --output-mode udp \
  --sample-rate "${SAMPLE_RATE:-48000}" \
  --udp-bind "${UDP_BIND:-0.0.0.0:5004}" \
  "$@"
