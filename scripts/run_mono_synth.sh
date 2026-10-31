#!/usr/bin/env bash
# Start MonoSynth UDP engine (synths/mono_synth).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fuser -k 5004/udp 2>/dev/null || true
sleep 0.2

make -C synths/mono_synth obj_dir/MonoSynth
exec ./synths/mono_synth/obj_dir/MonoSynth \
  --sample-rate "${SAMPLE_RATE:-48000}" \
  --udp-bind "${UDP_BIND:-0.0.0.0:5004}" \
  "$@"
