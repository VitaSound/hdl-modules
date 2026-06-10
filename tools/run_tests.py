#!/usr/bin/env python3
"""Run Icarus Verilog simulations for all modules defined in modules.yaml."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent


def load_modules() -> list[dict]:
    with (ROOT / "modules.yaml").open(encoding="utf-8") as fh:
        data = yaml.safe_load(fh)

    modules: list[dict] = []
    for category in data["categories"]:
        if category["id"] == "common":
            for entry in category["modules"]:
                modules.append(entry)
        elif category["id"] == "generation":
            for entry in category["packages"]:
                modules.append(entry)
    return modules


def run_module(module: dict, root: Path) -> None:
    module_id = module["id"]
    test_dir = root / module["test_dir"]
    if not test_dir.is_dir():
        raise FileNotFoundError(f"{module_id}: test dir not found: {test_dir}")

    sources = [str(root / src) for src in module["sources"]]
    for src in sources:
        if not Path(src).is_file():
            raise FileNotFoundError(f"{module_id}: source not found: {src}")

    testbench = test_dir / "testbench.v"
    if not testbench.is_file():
        raise FileNotFoundError(f"{module_id}: testbench not found: {testbench}")

    binary = test_dir / "testbench"
    vcd = test_dir / "out.vcd"

    print(f"[test] {module_id}: compiling")
    compile_cmd = ["iverilog", "-o", str(binary), str(testbench), *sources]
    subprocess.run(compile_cmd, cwd=test_dir, check=True)

    print(f"[test] {module_id}: simulating")
    subprocess.run(["vvp", str(binary.name)], cwd=test_dir, check=True)

    if not vcd.is_file():
        raise FileNotFoundError(f"{module_id}: out.vcd was not created")

    print(f"[test] {module_id}: OK")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--id", help="Run a single module by id")
    parser.add_argument("--list", action="store_true", help="List module ids")
    args = parser.parse_args()

    modules = load_modules()

    if args.list:
        for module in modules:
            print(module["id"])
        return 0

    selected = modules
    if args.id:
        selected = [m for m in modules if m["id"] == args.id]
        if not selected:
            print(f"Unknown module id: {args.id}", file=sys.stderr)
            return 1

    failed = 0
    for module in selected:
        try:
            run_module(module, ROOT)
        except (subprocess.CalledProcessError, FileNotFoundError) as exc:
            print(f"[test] {module['id']}: FAILED - {exc}", file=sys.stderr)
            failed += 1

    if failed:
        print(f"\n{failed} test(s) failed", file=sys.stderr)
        return 1

    print(f"\nAll {len(selected)} test(s) passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
