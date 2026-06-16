#!/usr/bin/env bash
# Quick WSL network hints for VST bridge.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== WSL network check (HDL Verilator bridge) ==="
echo

if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "Environment: WSL"
else
    echo "Environment: native Linux (no WSL NAT; localhost tests are most relevant)"
fi

echo
echo "WSL IP (legacy NAT mode - Engine host in VST):"
hostname -I | awk '{print "  " $1}'

echo
echo "Listening UDP 5004 (engine):"
if ss -uln 2>/dev/null | grep -q ':5004 '; then
    ss -uln | grep ':5004 ' || true
    echo "  OK: engine appears to be running"
else
    echo "  NOT listening - run: ./scripts/run_udp_engine.sh"
fi

echo
if [[ -f /mnt/c/Users/*/.wslconfig ]]; then
    wslcfg=$(ls /mnt/c/Users/*/.wslconfig 2>/dev/null | head -1)
    if grep -q 'networkingMode=mirrored' "$wslcfg" 2>/dev/null; then
        echo "Mirrored networking: ENABLED in $wslcfg"
        echo "  Use Engine host 127.0.0.1 in VST"
    else
        echo "Mirrored networking: not set in $wslcfg"
        echo "  See docs/WSL_NETWORKING.md - try networkingMode=mirrored"
    fi
else
    echo "Mirrored networking: .wslconfig not found on Windows side"
    echo "  See docs/WSL_NETWORKING.md"
fi

echo
echo "Local smoke test (2 s):"
if ss -uln 2>/dev/null | grep -q ':5004 '; then
    python3 "$ROOT/hdl-modules-tester/scripts/udp_smoke_test.py" \
        --engine-host 127.0.0.1 --duration 1.5 --wav /tmp/hdl_net_check.wav 2>&1 | tail -3
else
    echo "  skipped (engine not running)"
fi

echo
echo "Full guide: docs/WSL_NETWORKING.md"
