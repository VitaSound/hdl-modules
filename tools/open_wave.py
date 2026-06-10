#!/usr/bin/env python3
"""Open GTKWave interactively for a module test directory."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent


def find_module(module_id: str) -> dict:
    with (ROOT / "modules.yaml").open(encoding="utf-8") as fh:
        data = yaml.safe_load(fh)

    for category in data["categories"]:
        if category["id"] == "common":
            for entry in category["modules"]:
                if entry["id"] == module_id:
                    return entry
        elif category["id"] == "generation":
            for entry in category["packages"]:
                if entry["id"] == module_id:
                    return entry

    raise SystemExit(f"Unknown module id: {module_id}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--id", required=True, help="Module id from modules.yaml")
    args = parser.parse_args()

    module = find_module(args.id)
    test_dir = ROOT / module["test_dir"]
    vcd = test_dir / "out.vcd"
    gtkw = ROOT / module["gtkw"] if module.get("gtkw") else None

    if not vcd.is_file():
        print(f"Missing {vcd}. Run: make sim ID={args.id}", file=sys.stderr)
        return 1

    cmd = ["gtkwave", str(vcd.name)]
    if gtkw and gtkw.is_file():
        cmd.append(str(gtkw.name))

    return subprocess.run(cmd, cwd=test_dir).returncode


if __name__ == "__main__":
    sys.exit(main())
