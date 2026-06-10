#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -n "${1:-}" ]]; then
  exec python3 "$ROOT/tools/render_images.py" --id "$1"
fi

exec python3 "$ROOT/tools/render_images.py"
