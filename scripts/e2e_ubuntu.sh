#!/usr/bin/env bash
# Ubuntu E2E: engine + plugin simulator (Python UDP client).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fuser -k 5004/udp 5005/udp 2>/dev/null || true
sleep 0.3

make -C hdl-modules-tester test_hdl_net obj_dir/Vgenerator

./hdl-modules-tester/obj_dir/Vgenerator \
  --sample-rate 48000 &
ENGINE_PID=$!
trap 'kill "$ENGINE_PID" 2>/dev/null || true' EXIT

sleep 2
python3 hdl-modules-tester/scripts/udp_smoke_test.py --duration 2.0 --wav /tmp/hdl_e2e.wav
echo "E2E Ubuntu OK — see /tmp/hdl_e2e.wav"
