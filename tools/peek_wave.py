#!/usr/bin/env python3
"""Run wavepeek against a module or synth dump (resolves id → VCD/FST)."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent

# Verilator UDP engines under synths/ (not in modules.yaml).
SYNTH_DIRS = {
    "mono_synth": ROOT / "synths" / "mono_synth",
    "mini_fx": ROOT / "synths" / "mini_fx",
    "noise_box": ROOT / "synths" / "noise_box",
}

DUMP_HINT = {
    "mono_synth": (
        "make -C synths/mono_synth TRACE=1 && "
        "./synths/mono_synth/obj_dir/MonoSynth --dump-vcd synths/mono_synth/out.vcd "
        "--dump-frames 1024 --dump-note 60"
    ),
    "mini_fx": (
        "make -C synths/mini_fx TRACE=1 && "
        "./synths/mini_fx/obj_dir/MiniFX --dump-vcd synths/mini_fx/out.vcd "
        "--dump-frames 1024"
    ),
    "noise_box": (
        "make -C synths/noise_box TRACE=1 && "
        "./synths/noise_box/obj_dir/NoiseBox --dump-vcd synths/noise_box/out.vcd "
        "--dump-frames 1024 --dump-note 60"
    ),
}


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

    raise KeyError(module_id)


def resolve_waves(module_id: str | None, waves: Path | None) -> Path:
    if waves is not None:
        path = waves if waves.is_absolute() else ROOT / waves
        if not path.is_file():
            raise SystemExit(f"Missing waveform file: {path}")
        return path

    if not module_id:
        raise SystemExit("Provide --id or --waves")

    if module_id in SYNTH_DIRS:
        synth_dir = SYNTH_DIRS[module_id]
        for name in ("out.vcd", "out.fst"):
            candidate = synth_dir / name
            if candidate.is_file():
                return candidate
        hint = DUMP_HINT.get(module_id, f"create {synth_dir}/out.vcd")
        raise SystemExit(f"Missing {synth_dir}/out.vcd (or out.fst). Run:\n  {hint}")

    try:
        module = find_module(module_id)
    except KeyError as exc:
        known = ", ".join([*sorted(SYNTH_DIRS), "<modules.yaml ids>"])
        raise SystemExit(
            f"Unknown id: {module_id}. Known synths / modules: {known}. "
            "Or pass --waves PATH."
        ) from exc

    vcd = ROOT / module["test_dir"] / "out.vcd"
    if not vcd.is_file():
        raise SystemExit(f"Missing {vcd}. Run: make sim ID={module_id}")
    return vcd


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        epilog="Everything after -- is passed to wavepeek. Example:\n"
        "  make peek ID=adsr -- info\n"
        "  make peek ID=mono_synth -- info\n"
        "  make peek WAVES=synths/mini_fx/out.vcd -- scope --tree\n"
        "  make peek ID=adsr -- value --at 1ms --signals testbench.gate",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--id",
        help="Module id from modules.yaml, or synth id "
        "(mono_synth, mini_fx, noise_box)",
    )
    parser.add_argument(
        "--waves",
        type=Path,
        help="Explicit VCD/FST path (skips id resolution)",
    )
    args, wavepeek_args = parser.parse_known_args()

    if wavepeek_args and wavepeek_args[0] == "--":
        wavepeek_args = wavepeek_args[1:]

    if not wavepeek_args:
        parser.error("missing wavepeek subcommand (e.g. info, scope, value)")

    if not args.id and not args.waves:
        parser.error("provide --id and/or --waves")

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

    waves_path = resolve_waves(args.id, args.waves)

    cmd = [wavepeek, *wavepeek_args]
    if "--waves" not in wavepeek_args:
        cmd.extend(["--waves", str(waves_path)])

    env = os.environ.copy()
    return subprocess.run(cmd, cwd=ROOT, env=env).returncode


if __name__ == "__main__":
    sys.exit(main())
