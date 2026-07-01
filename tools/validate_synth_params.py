#!/usr/bin/env python3
"""Validate synth *.params.yaml against docs/MONO_SYNTH_MIDI.md CC table."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:  # pragma: no cover
    raise SystemExit("PyYAML required: pip install pyyaml") from exc

ROOT = Path(__file__).resolve().parents[1]

MONO_SYNTH_EXPECTED_CC = {
    16,
    17,
    18,
    19,
    24,
    25,
    26,
    27,
    28,
    48,
    22,
    74,
    106,
    71,
    51,
    52,
    53,
    54,
    55,
    56,
    57,
    58,
    59,
    60,
    49,
    50,
}

MINI_FX_EXPECTED_CC = {74, 106, 71}

VALID_TYPES = {"cc7", "cc14_log", "choice"}


def load_yaml(path: Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        data = yaml.safe_load(fh)
    if not isinstance(data, dict):
        raise ValueError(f"{path}: root must be a mapping")
    return data


def collect_cc(params: list) -> set[int]:
    cc: set[int] = set()
    for param in params:
        ptype = param.get("type")
        if ptype == "cc7" or ptype == "choice":
            cc.add(int(param["cc"]))
        elif ptype == "cc14_log":
            cc.add(int(param["cc_lsb"]))
            cc.add(int(param["cc_msb"]))
        else:
            raise ValueError(f"unknown param type {ptype!r} for {param.get('id')}")
    return cc


def validate_file(path: Path, expected_cc: set[int]) -> list[str]:
    errors: list[str] = []
    try:
        data = load_yaml(path)
    except (OSError, yaml.YAMLError, ValueError) as exc:
        return [str(exc)]

    if data.get("schema_version") != 1:
        errors.append(f"{path}: schema_version must be 1")

    params = data.get("params")
    if not isinstance(params, list) or not params:
        errors.append(f"{path}: params must be a non-empty list")
        return errors

    seen_ids: set[str] = set()
    for param in params:
        if not isinstance(param, dict):
            errors.append(f"{path}: each param must be a mapping")
            continue
        pid = param.get("id")
        if not pid or pid in seen_ids:
            errors.append(f"{path}: duplicate or missing param id")
        seen_ids.add(pid)
        ptype = param.get("type")
        if ptype not in VALID_TYPES:
            errors.append(f"{path}: param {pid}: invalid type {ptype!r}")
        if "name" not in param:
            errors.append(f"{path}: param {pid}: missing name")
        if ptype in {"cc7", "choice"} and "cc" not in param:
            errors.append(f"{path}: param {pid}: missing cc")
        if ptype == "cc14_log" and ("cc_lsb" not in param or "cc_msb" not in param):
            errors.append(f"{path}: param {pid}: cc14_log needs cc_lsb and cc_msb")
        if ptype == "choice" and not param.get("choices"):
            errors.append(f"{path}: param {pid}: choice needs choices")
        if ptype == "choice" and "midi_values" in param:
            choices = param.get("choices", [])
            midi_values = param.get("midi_values", [])
            if not isinstance(midi_values, list) or len(midi_values) != len(choices):
                errors.append(f"{path}: param {pid}: midi_values length must match choices")
            for value in midi_values:
                if not isinstance(value, int) or value < 0 or value > 127:
                    errors.append(f"{path}: param {pid}: midi_values must be CC bytes 0..127")

    try:
        found = collect_cc(params)
    except ValueError as exc:
        errors.append(str(exc))
        return errors

    missing = expected_cc - found
    extra = found - expected_cc
    if missing:
        errors.append(f"{path}: missing CC numbers: {sorted(missing)}")
    if extra:
        errors.append(f"{path}: unexpected CC numbers: {sorted(extra)}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--mono",
        type=Path,
        default=ROOT / "synths/mono_synth/mono_synth.params.yaml",
    )
    parser.add_argument(
        "--mini-fx",
        type=Path,
        default=ROOT / "synths/mini_fx/mini_fx.params.yaml",
    )
    args = parser.parse_args()

    all_errors: list[str] = []
    all_errors.extend(validate_file(args.mono, MONO_SYNTH_EXPECTED_CC))
    all_errors.extend(validate_file(args.mini_fx, MINI_FX_EXPECTED_CC))

    if all_errors:
        for err in all_errors:
            print(err, file=sys.stderr)
        return 1

    print("validate_synth_params: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
