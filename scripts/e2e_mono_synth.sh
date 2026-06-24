#!/usr/bin/env bash
# Ubuntu E2E: MonoSynth engine + plugin simulator (Python UDP client).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fuser -k 5004/udp 5005/udp 2>/dev/null || true
sleep 0.3

make -C hdl-modules-tester test_hdl_net
make -C synths/mono_synth obj_dir/MonoSynth

./synths/mono_synth/obj_dir/MonoSynth \
  --sample-rate 44100 &
ENGINE_PID=$!
trap 'kill "$ENGINE_PID" 2>/dev/null || true' EXIT

sleep 2
python3 hdl-modules-tester/scripts/udp_smoke_test.py --duration 2.0 --wav /tmp/mono_synth_e2e.wav --cc-attack 0
echo "E2E mono_synth OK — see /tmp/mono_synth_e2e.wav"
