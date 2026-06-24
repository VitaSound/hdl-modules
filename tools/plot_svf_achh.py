#!/usr/bin/env python3
"""Render SVF frequency response (ACHH) from simulation VCD via FFT."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parent.parent

FS_HZ = 1_000_000
FC_HZ = 5_000.0
NOISE_SAMPLES = 65_536
TARGET_NAMES = ("lp", "hp", "bp")


def sign_extend(value: int, width: int) -> int:
    limit = 1 << (width - 1)
    if value >= limit:
        value -= 1 << width
    return value


def parse_vcd_signals(
    vcd_path: Path,
    names: tuple[str, ...] = TARGET_NAMES,
) -> dict[str, list[int]]:
    scopes: list[str] = []
    meta: dict[str, dict[str, object]] = {}
    targets: dict[str, str] = {}

    with vcd_path.open(encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            line = raw.strip()
            if line.startswith("$scope"):
                scopes.append(line.split()[2])
            elif line.startswith("$upscope"):
                if scopes:
                    scopes.pop()
            elif line.startswith("$var"):
                parts = line.split()
                width = int(parts[2])
                sid = parts[3]
                name = parts[4]
                path = ".".join(scopes)
                meta[sid] = {"name": name, "width": width, "path": path}
                if path == "testbench" and name in names:
                    targets[name] = sid
            elif line.startswith("$enddefinitions"):
                break
        else:
            raise RuntimeError(f"{vcd_path}: missing $enddefinitions")

        if len(targets) != len(names):
            missing = set(names) - set(targets)
            raise RuntimeError(f"{vcd_path}: missing testbench signals: {missing}")

        current = {name: 0 for name in names}
        series: dict[str, list[int]] = {name: [] for name in names}
        sid_to_name = {sid: name for name, sid in targets.items()}
        pending = False
        current_ts: int | None = None

        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("$"):
                continue
            if line[0] == "#":
                if pending and current_ts is not None:
                    for name in names:
                        series[name].append(current[name])
                    pending = False
                current_ts = int(line[1:])
                continue

            updated = False
            if line[0] == "b":
                parts = line.split()
                sid = parts[1]
                if sid in sid_to_name:
                    bits = parts[0][1:]
                    if "x" not in bits and "X" not in bits and "z" not in bits and "Z" not in bits:
                        width = int(meta[sid]["width"])  # type: ignore[arg-type]
                        name = sid_to_name[sid]
                        current[name] = sign_extend(int(bits, 2), width)
                        updated = True
            elif line[0] == "s":
                parts = line.split(maxsplit=1)
                sid = parts[1]
                if sid in sid_to_name:
                    width = int(meta[sid]["width"])  # type: ignore[arg-type]
                    name = sid_to_name[sid]
                    current[name] = sign_extend(int(parts[0][1:]), width)
                    updated = True
            elif len(line) >= 2 and line[0] in "01xXzZ":
                sid = line[1:]
                if sid in sid_to_name:
                    ch = line[0]
                    if ch not in "xXzZ":
                        name = sid_to_name[sid]
                        current[name] = 1 if ch == "1" else 0
                        updated = True

            if updated:
                pending = True

        if pending:
            for name in names:
                series[name].append(current[name])

    return series


def magnitude_db(samples: np.ndarray, fs_hz: float) -> tuple[np.ndarray, np.ndarray]:
    n = len(samples)
    window = np.hanning(n)
    spectrum = np.fft.rfft(samples.astype(np.float64) * window)
    freqs = np.fft.rfftfreq(n, d=1.0 / fs_hz)
    mag = np.abs(spectrum)
    peak = float(mag.max())
    if peak <= 0:
        raise RuntimeError("FFT magnitude is zero")
    db = 20.0 * np.log10(mag / peak + 1e-12)
    return freqs, db


def band_mean_power(freqs: np.ndarray, db: np.ndarray, f_lo: float, f_hi: float) -> float:
    mask = (freqs >= f_lo) & (freqs <= f_hi)
    if not np.any(mask):
        return 0.0
    return float(np.mean(10.0 ** (db[mask] / 10.0)))


def run_sanity_checks(
    freqs: np.ndarray,
    lp_db: np.ndarray,
    hp_db: np.ndarray,
    bp_db: np.ndarray,
    fc_hz: float = FC_HZ,
) -> list[str]:
    errors: list[str] = []

    lp_low = band_mean_power(freqs, lp_db, 200.0, 2_000.0)
    lp_high = band_mean_power(freqs, lp_db, 20_000.0, 200_000.0)
    if lp_low < lp_high * 4.0:
        errors.append(
            f"LP: low-band power {lp_low:.4g} should exceed high-band {lp_high:.4g} by 6+ dB"
        )

    hp_low = band_mean_power(freqs, hp_db, 200.0, 2_000.0)
    hp_high = band_mean_power(freqs, hp_db, 20_000.0, 200_000.0)
    if hp_high < hp_low * 4.0:
        errors.append(
            f"HP: high-band power {hp_high:.4g} should exceed low-band {hp_low:.4g} by 6+ dB"
        )

    bp_lo = fc_hz / 4.0
    bp_hi = fc_hz * 4.0
    bp_near = band_mean_power(freqs, bp_db, bp_lo, bp_hi)
    bp_far_lo = band_mean_power(freqs, bp_db, 200.0, 500.0)
    bp_far_hi = band_mean_power(freqs, bp_db, 50_000.0, 200_000.0)
    bp_ref = max(bp_far_lo, bp_far_hi, 1e-12)
    if bp_near < bp_ref * 2.0:
        errors.append(
            f"BP: pass-band power {bp_near:.4g} should dominate skirts ({bp_ref:.4g})"
        )

    return errors


def plot_achh(
    vcd_path: Path,
    image_path: Path,
    *,
    fs_hz: float = FS_HZ,
    fc_hz: float = FC_HZ,
    noise_samples: int = NOISE_SAMPLES,
) -> None:
    series = parse_vcd_signals(vcd_path)
    lp = np.array(series["lp"][-noise_samples:], dtype=np.float64)
    hp = np.array(series["hp"][-noise_samples:], dtype=np.float64)
    bp = np.array(series["bp"][-noise_samples:], dtype=np.float64)

    if len(lp) < noise_samples:
        raise RuntimeError(
            f"{vcd_path}: only {len(lp)} LP samples, need {noise_samples}"
        )

    freqs, lp_db = magnitude_db(lp, fs_hz)
    _, hp_db = magnitude_db(hp, fs_hz)
    _, bp_db = magnitude_db(bp, fs_hz)

    errors = run_sanity_checks(freqs, lp_db, hp_db, bp_db, fc_hz)
    if errors:
        for msg in errors:
            print(f"[achh] FAIL {msg}", file=sys.stderr)
        raise RuntimeError("SVF ACHH sanity checks failed")

    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(freqs, lp_db, label="LP", linewidth=1.2)
    ax.plot(freqs, hp_db, label="HP", linewidth=1.2)
    ax.plot(freqs, bp_db, label="BP", linewidth=1.2)
    ax.axvline(fc_hz, color="gray", linestyle="--", linewidth=0.8, label=f"Fc={fc_hz/1000:.0f} kHz")
    ax.set_xscale("log")
    ax.set_xlim(100, fs_hz / 2)
    ax.set_ylim(-60, 3)
    ax.set_xlabel("Frequency (Hz)")
    ax.set_ylabel("Magnitude (dB, norm. peak)")
    ax.set_title("SVF ACHH (white noise, FFT)")
    ax.grid(True, which="both", alpha=0.3)
    ax.legend(loc="upper right")

    image_path.parent.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(image_path, dpi=120)
    plt.close(fig)
    print(f"[achh] saved {image_path}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vcd", type=Path, required=True, help="Path to out.vcd")
    parser.add_argument("--image", type=Path, required=True, help="Output PNG path")
    parser.add_argument("--fs", type=float, default=FS_HZ, help="Sample rate (Hz)")
    parser.add_argument("--fc", type=float, default=FC_HZ, help="Cutoff for marker (Hz)")
    parser.add_argument(
        "--samples",
        type=int,
        default=NOISE_SAMPLES,
        help="Number of trailing samples for FFT",
    )
    args = parser.parse_args()

    try:
        plot_achh(
            args.vcd.resolve(),
            args.image.resolve(),
            fs_hz=args.fs,
            fc_hz=args.fc,
            noise_samples=args.samples,
        )
    except (RuntimeError, OSError) as exc:
        print(f"[achh] FAILED: {exc}", file=sys.stderr)
        return 1

    print("[achh] sanity checks OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
