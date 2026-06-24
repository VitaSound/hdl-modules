#!/usr/bin/env python3
"""Run mono_voice VCF matrix self-check (20 Fc x 4 modes x 5 Q)."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEST_DIR = ROOT / "mono_voice/test"
TB = TEST_DIR / "vcf_matrix_tb.v"
BINARY = TEST_DIR / "vcf_matrix_tb"

SOURCES = [
    "mono_voice/mono_voice.v",
    "dds/note2dds.v",
    "dds/note_pitch2dds.v",
    "dds/dds.v",
    "dds_transform/dds2saw.v",
    "dds_transform/dds2revsaw.v",
    "dds_transform/dds2tria.v",
    "dds_transform/dds2square.v",
    "dds_transform/dds2pwm.v",
    "dds_transform/dds2sin.v",
    "adsr/adsr.v",
    "svf/svf.v",
    "vca/svca16.v",
    "synths/mono_synth/svf_cc_to_q.v",
]


def main() -> int:
    if not TB.is_file():
        print(f"Missing {TB}", file=sys.stderr)
        return 1

    srcs = [str(ROOT / s) for s in SOURCES]
    for s in srcs:
        if not Path(s).is_file():
            print(f"Missing source {s}", file=sys.stderr)
            return 1

    print("[vcf-matrix] compiling")
    subprocess.run(
        ["iverilog", "-o", str(BINARY), str(TB), *srcs],
        cwd=TEST_DIR,
        check=True,
    )
    print("[vcf-matrix] simulating (400 cases)")
    subprocess.run(["vvp", BINARY.name], cwd=TEST_DIR, check=True)
    print("[vcf-matrix] OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
