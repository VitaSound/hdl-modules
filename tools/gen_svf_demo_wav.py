#!/usr/bin/env python3
"""Generate a demo WAV showcasing SVF modes, cutoffs, and Q values."""

from __future__ import annotations

import argparse
import math
import struct
import wave
from dataclasses import dataclass
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = ROOT / "svf" / "test" / "demo.wav"
FS_HZ = 48_000
Q17 = 131_072
MASK36 = (1 << 36) - 1
MASK18 = (1 << 18) - 1
IN_SHIFT = 14


def s36(value: int) -> int:
    value &= MASK36
    if value >= (1 << 35):
        value -= 1 << 36
    return value


def s18(value: int) -> int:
    value &= MASK18
    if value >= (1 << 17):
        value -= 1 << 18
    return value


@dataclass(frozen=True)
class Segment:
    mode: str
    fc_hz: float
    q: float
    duration_s: float
    label: str


SEGMENTS: tuple[Segment, ...] = (
    Segment("lp", 400, 0.7, 3.0, "LP 400 Hz Q=0.7"),
    Segment("lp", 4000, 2.0, 3.0, "LP 4 kHz Q=2"),
    Segment("hp", 3000, 1.0, 3.0, "HP 3 kHz Q=1"),
    Segment("hp", 400, 2.0, 3.0, "HP 400 Hz Q=2"),
    Segment("bp", 1000, 6.0, 4.0, "BP 1 kHz Q=6"),
    Segment("notch", 1000, 2.0, 4.0, "notch 1 kHz Q=2"),
)

GAP_S = 0.15
WARMUP_SAMPLES = 512


def f_coeff(fc_hz: float, fs_hz: float) -> int:
    fv = 2.0 * math.sin(math.pi * fc_hz / fs_hz)
    return int(round(fv * Q17))


def q_coeff(q: float) -> int:
    return int(round((1.0 / q) * Q17))


def sat16(value: int) -> int:
    if value > 32_767:
        return 32_767
    if value < -32_768:
        return -32_768
    return value


def svf_tick(
    z1: int,
    z2: int,
    in16: int,
    f: int,
    q: int,
) -> tuple[int, int, int, int, int, int]:
    """One SVF sample; fixed-point matches svf/svf.v (16-bit ports, IN_SHIFT=14)."""
    if in16 >= (1 << 15):
        in16 -= 1 << 16

    bp_scaled = z1 >> 17
    multq = s36(bp_scaled * q)
    in36 = s36(int(in16) << IN_SHIFT)
    hp_full = s36(in36 - multq - z2)
    hp_int = s18(hp_full >> 17)

    f_hp = s36(f * hp_int)
    z1_next = s36(f_hp + z1)
    f_bp = s36(f * bp_scaled)
    z2_next = s36(f_bp + z2)

    if -1 < z1_next < 1:
        z1_next = 0
    if -1 < z2_next < 1:
        z2_next = 0

    hp = sat16(hp_full >> IN_SHIFT)
    lp = sat16(z2_next >> IN_SHIFT)
    bp = sat16(z1_next >> IN_SHIFT)
    notch_sum = (hp_full >> IN_SHIFT) + (z2_next >> IN_SHIFT)
    notch = sat16(notch_sum)
    return z1_next, z2_next, hp, bp, lp, notch


def pick_output(mode: str, hp: int, bp: int, lp: int, notch: int) -> int:
    if mode == "hp":
        return hp
    if mode == "bp":
        return bp
    if mode == "notch":
        return notch
    return lp


def render_segment(
    seg: Segment,
    fs_hz: int,
    rng: np.random.Generator,
) -> np.ndarray:
    n = int(seg.duration_s * fs_hz)
    f = f_coeff(seg.fc_hz, fs_hz)
    q = q_coeff(seg.q)

    z1 = 0
    z2 = 0
    out = np.zeros(n, dtype=np.int64)

    for i in range(n + WARMUP_SAMPLES):
        # White noise, 16-bit signed (same headroom as RTL testbench).
        in16 = int(rng.integers(-32768, 32768))
        z1, z2, hp, bp, lp, notch = svf_tick(z1, z2, in16, f, q)
        if i >= WARMUP_SAMPLES:
            out[i - WARMUP_SAMPLES] = pick_output(seg.mode, hp, bp, lp, notch)

    return out


def to_int16_pcm(samples: np.ndarray) -> bytes:
    peak = int(np.max(np.abs(samples)))
    if peak == 0:
        peak = 1
    scale = 29_000.0 / peak
    pcm = np.clip(np.round(samples.astype(np.float64) * scale), -32768, 32767).astype(np.int16)
    return struct.pack(f"{len(pcm)}h", *pcm)


def build_demo(fs_hz: int, segments: tuple[Segment, ...], seed: int) -> tuple[np.ndarray, list[str]]:
    rng = np.random.default_rng(seed)
    gap = np.zeros(int(GAP_S * fs_hz), dtype=np.int64)
    chunks: list[np.ndarray] = []
    labels: list[str] = []

    for seg in segments:
        labels.append(f"{seg.label} ({seg.duration_s:.1f}s)")
        chunks.append(render_segment(seg, fs_hz, rng))
        chunks.append(gap)

    if chunks:
        chunks.pop()  # no trailing gap

    return np.concatenate(chunks), labels


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=DEFAULT_OUT,
        help=f"Output WAV path (default: {DEFAULT_OUT.relative_to(ROOT)})",
    )
    parser.add_argument("--fs", type=int, default=FS_HZ, help="Sample rate Hz")
    parser.add_argument("--seed", type=int, default=42, help="RNG seed for noise")
    args = parser.parse_args()

    samples, labels = build_demo(args.fs, SEGMENTS, args.seed)
    duration_s = len(samples) / args.fs

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(args.output), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(args.fs)
        wf.writeframes(to_int16_pcm(samples))

    print(f"[svf-demo] wrote {args.output} ({duration_s:.1f}s, {args.fs} Hz mono)")
    print("[svf-demo] segments:")
    t = 0.0
    for label, seg in zip(labels, SEGMENTS, strict=True):
        print(f"  {t:5.1f}s  {label}")
        t += seg.duration_s + GAP_S

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
