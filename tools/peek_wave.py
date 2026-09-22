#!/usr/bin/env python3
"""Run wavepeek against a module's out.vcd (resolves id via modules.yaml)."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent


def find_module(module_id: str) -> dict:
    with (ROOT / "modules.yaml").open(encoding="utf-8") as fh:
        data = yaml.safe_load(fh)

    for category in data["categories"]:
        if category["id"] in ("common", "io"):
            for entry in category["modules"]:
                if entry["id"] == module_id:
                    return entry
        elif category["id"] == "generation":
            for entry in category["packages"]:
                if entry["id"] == module_id:
                    return entry

    raise SystemExit(f"Unknown module id: {module_id}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        epilog="Everything after -- is passed to wavepeek. Example:\n"
        "  make peek ID=adsr -- info\n"
        "  make peek ID=adsr -- value --at 1ms --signals testbench.gate",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--id", required=True, help="Module id from modules.yaml")
    args, wavepeek_args = parser.parse_known_args()

    if wavepeek_args and wavepeek_args[0] == "--":
        wavepeek_args = wavepeek_args[1:]

    if not wavepeek_args:
        parser.error("missing wavepeek subcommand (e.g. info, scope, value)")

    wavepeek = shutil.which("wavepeek")
    if wavepeek is None:
        print(
            "wavepeek not found in PATH. Install:\n"
            "  curl --proto '=https' --tlsv1.2 -LsSf "
            "https://kleverhq.github.io/wavepeek/install.sh | sh\n"
            "See docs/DEPENDENCIES.md",
            file=sys.stderr,
        )
        return 1

    module = find_module(args.id)
    vcd = ROOT / module["test_dir"] / "out.vcd"
    if not vcd.is_file():
        print(f"Missing {vcd}. Run: make sim ID={args.id}", file=sys.stderr)
        return 1

    # Insert --waves after the subcommand path if the caller did not pass it.
    cmd = [wavepeek, *wavepeek_args]
    if "--waves" not in wavepeek_args:
        # Subcommand may be multi-word (e.g. extract generic). Put --waves
        # after the first token that is not a global flag; simplest: append.
        cmd.extend(["--waves", str(vcd)])
    else:
        # Caller provided --waves; still prefer resolved path if they used a placeholder.
        pass

    env = os.environ.copy()
    return subprocess.run(cmd, cwd=ROOT, env=env).returncode


if __name__ == "__main__":
    sys.exit(main())
