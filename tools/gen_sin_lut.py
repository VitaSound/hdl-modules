#!/usr/bin/env python3
"""Print quarter-wave sine LUT constants for dds2sin (synthesis-friendly hex)."""

from __future__ import annotations

import argparse
import math


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--width", type=int, default=32, help="WIDTH (default 32)")
    parser.add_argument("--lut-bits", type=int, default=3, help="LUT_BITS (default 3)")
    parser.add_argument("--verilog-case", action="store_true", help="Emit Verilog case items")
    args = parser.parse_args()

    w = args.width
    lb = args.lut_bits
    if lb + 2 > w:
        raise SystemExit(f"LUT_BITS + 2 must be <= WIDTH ({lb} + 2 > {w})")

    mid = (1 << (w - 1)) - 1
    entries = 1 << lb
    amp_width = w - 1

    print(f"// WIDTH={w} LUT_BITS={lb} MID={mid:#x} entries={entries}")
    for i in range(entries):
        phase = i * math.pi / 2 / (entries - 1)
        val = int(round(math.sin(phase) * mid))
        if args.verilog_case:
            key = f"{lb}'b{i:0{lb}b}"
            hex_w = max(1, (amp_width + 3) // 4)
            print(f"            {key}: table_sine = {amp_width}'h{val:0{hex_w}x};")
        else:
            print(f"{i:4d}  {val:12d}  {val:#x}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
