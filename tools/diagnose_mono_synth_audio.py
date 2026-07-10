#!/usr/bin/env python3
"""Capture mono_synth via UDP (square wave) and plot waveform + ACHH."""

from __future__ import annotations

import argparse
import math
import socket
import struct
import subprocess
import sys
import time
import wave
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "hdl-modules-tester" / "scripts"))

from udp_smoke_test import (  # noqa: E402
    MIN_RESERVE,
    PACKET_FRAMES,
    TARGET_RESERVE,
    WARMUP_PACKETS,
    encode_hello,
    encode_midi,
    encode_pull,
    parse_audio,
    parse_control,
)


def send_cc(ctrl, host, port, seq: list[int], cc: int, val: int) -> None:
    msg = bytes([0xB0, cc & 0x7F, val & 0x7F])
    ctrl.sendto(encode_midi(seq[0], msg), (host, port))
    seq[0] += 1


def capture(
    *,
    host: str,
    ctrl_port: int,
    audio_port: int,
    sample_rate: int,
    duration: float,
    note: int,
    velocity: int,
    wave_cc: int,
    cutoff_cc: int,
    resonance_cc: int,
    mode_cc: int,
    attack_cc: int,
    sustain_cc: int,
) -> list[int]:
    ctrl = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    ctrl.bind(("0.0.0.0", 0))
    ctrl.settimeout(1.0)

    audio = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    audio.bind(("0.0.0.0", audio_port))
    audio.settimeout(0.05)

    ctrl.sendto(encode_hello(1, audio_port, sample_rate), (host, ctrl_port))

    deadline = time.time() + 3.0
    while time.time() < deadline:
        try:
            data, _ = ctrl.recvfrom(2048)
        except socket.timeout:
            continue
        parsed = parse_control(data)
        if parsed and parsed[0] == 2:
            break
    else:
        raise RuntimeError("No ACK from engine")

    seq = [2]
    for cc, val in (
        (16, attack_cc),
        (17, 0),
        (18, sustain_cc),
        (19, 64),
        (48, wave_cc),
        (74, cutoff_cc),
        (71, resonance_cc),
        (22, mode_cc),
    ):
        send_cc(ctrl, host, ctrl_port, seq, cc, val)
        time.sleep(0.01)

    note_on = bytes([0x90, note & 0x7F, velocity & 0x7F])
    ctrl.sendto(encode_midi(seq[0], note_on), (host, ctrl_port))
    seq[0] += 1

    pcm: list[int] = []
    request_id = 0
    target_fill = TARGET_RESERVE * PACKET_FRAMES
    warmup = WARMUP_PACKETS * PACKET_FRAMES
    end = time.time() + duration

    while time.time() < end:
        fill = len(pcm)
        if fill < warmup or fill < MIN_RESERVE * PACKET_FRAMES:
            need = min(target_fill, max(PACKET_FRAMES, target_fill - fill))
            request_id += 1
            seq[0] += 1
            pull = encode_pull(seq[0], request_id, need, fill, target_fill)
            ctrl.sendto(pull, (host, ctrl_port))

        try:
            data, _ = audio.recvfrom(4096)
        except socket.timeout:
            continue
        parsed = parse_audio(data)
        if parsed:
            _seq, _ts, _frames, ch, samples = parsed
            pcm.extend(samples if ch == 1 else samples[0::2])

    note_off = bytes([0x90, note & 0x7F, 0])
    ctrl.sendto(encode_midi(seq[0], note_off), (host, ctrl_port))
    return pcm


def write_wav(path: Path, samples: list[int], sample_rate: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(struct.pack(f"{len(samples)}h", *samples))


def analyze(samples: np.ndarray, sample_rate: int, label: str) -> dict:
    x = samples.astype(np.float64)
    x = x - np.mean(x)
    peak = float(np.max(np.abs(x)))
    rms = float(np.sqrt(np.mean(x * x)))

    diffs = np.abs(np.diff(x))
    big_jumps = int(np.sum(diffs > 0.35 * peak))
    flat_runs = int(np.sum(diffs == 0))

    n = len(x)
    win = min(n, 1 << int(math.floor(math.log2(n))))
    seg = x[:win]
    spec = np.abs(np.fft.rfft(seg * np.hanning(win)))
    freqs = np.fft.rfftfreq(win, 1.0 / sample_rate)
    spec_db = 20 * np.log10(spec / (np.max(spec) + 1e-12) + 1e-12)

    # C4 = 261.63 Hz for note 60
    f0 = 261.63
    idx0 = int(np.argmin(np.abs(freqs - f0)))
    idx3 = int(np.argmin(np.abs(freqs - 3 * f0)))
    harmonic_ratio = float(spec[idx3] / (spec[idx0] + 1e-12))

    # spectral flatness (noise ~1, tone <<1)
    log_spec = np.log(spec[1 : len(spec) // 2] + 1e-12)
    flatness = float(np.exp(np.mean(log_spec)) / (np.mean(spec[1 : len(spec) // 2]) + 1e-12))

    return {
        "label": label,
        "peak": peak,
        "rms": rms,
        "big_jumps": big_jumps,
        "flat_runs": flat_runs,
        "flatness": flatness,
        "harmonic_ratio": harmonic_ratio,
        "freqs": freqs,
        "spec_db": spec_db,
    }


def plot_report(
    out_png: Path,
    waveforms: list[tuple[str, np.ndarray, int]],
    spectra: list[dict],
    zoom_ms: float,
) -> None:
    nrows = 2
    ncols = len(waveforms)
    fig, axes = plt.subplots(nrows, ncols, figsize=(5 * ncols, 7), squeeze=False)

    for col, (label, samples, sr) in enumerate(waveforms):
        ax = axes[0, col]
        n_zoom = int(sr * zoom_ms / 1000.0)
        skip = min(len(samples) // 4, sr // 2)
        seg = samples[skip : skip + n_zoom]
        t_ms = (np.arange(len(seg)) / sr) * 1000.0
        ax.plot(t_ms, seg, lw=0.8)
        ax.set_title(f"Waveform — {label}")
        ax.set_xlabel("ms")
        ax.set_ylabel("PCM")
        ax.grid(True, alpha=0.3)

    for col, spec in enumerate(spectra):
        ax = axes[1, col]
        f = spec["freqs"]
        mask = f <= 8000
        ax.plot(f[mask], spec["spec_db"][mask], lw=0.9)
        ax.set_ylim(-80, 5)
        ax.set_title(f"ACHH — {spec['label']}")
        ax.set_xlabel("Hz")
        ax.set_ylabel("dB rel.")
        ax.grid(True, alpha=0.3)

    fig.tight_layout()
    out_png.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_png, dpi=140)
    plt.close(fig)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine-host", default="127.0.0.1")
    parser.add_argument("--control-port", type=int, default=5004)
    parser.add_argument("--audio-port", type=int, default=5005)
    parser.add_argument("--sample-rate", type=int, default=44100)
    parser.add_argument("--duration", type=float, default=2.5)
    parser.add_argument("--note", type=int, default=60)
    parser.add_argument("--out-dir", type=Path, default=Path("/tmp/mono_synth_diag"))
    parser.add_argument("--start-engine", action="store_true")
    parser.add_argument("--wave-cc", type=int, default=1, help="CC48 waveform (1=square, 3=sine)")
    args = parser.parse_args()

    engine_proc = None
    if args.start_engine:
        subprocess.run(["fuser", "-k", f"{args.control_port}/udp"], check=False)
        time.sleep(0.3)
        engine_proc = subprocess.Popen(
            [
                str(ROOT / "synths/mono_synth/obj_dir/MonoSynth"),
                "--sample-rate",
                str(args.sample_rate),
            ],
            cwd=ROOT,
        )
        time.sleep(1.5)

    cases = [
        ("square_filter_open", 127),
        ("square_filter_closed", 0),
    ]

    waveforms: list[tuple[str, np.ndarray, int]] = []
    spectra: list[dict] = []

    try:
        for name, cutoff in cases:
            print(f"Capturing {name} (CC74={cutoff})...")
            pcm = capture(
                host=args.engine_host,
                ctrl_port=args.control_port,
                audio_port=args.audio_port,
                sample_rate=args.sample_rate,
                duration=args.duration,
                note=args.note,
                velocity=80,
                wave_cc=args.wave_cc,
                cutoff_cc=cutoff,
                resonance_cc=0,
                mode_cc=0,
                attack_cc=127,
                sustain_cc=127,
            )
            wav_path = args.out_dir / f"{name}.wav"
            write_wav(wav_path, pcm, args.sample_rate)
            arr = np.array(pcm, dtype=np.int16)
            stats = analyze(arr, args.sample_rate, name)
            waveforms.append((name, arr, args.sample_rate))
            spectra.append(stats)
            print(
                f"  {name}: n={len(pcm)} peak={stats['peak']:.0f} rms={stats['rms']:.0f} "
                f"big_jumps={stats['big_jumps']} flat_runs={stats['flat_runs']} "
                f"flatness={stats['flatness']:.3f} h3/h1={stats['harmonic_ratio']:.2f}"
            )

        png = args.out_dir / "report.png"
        plot_report(png, waveforms, spectra, zoom_ms=15.0)
        print(f"Wrote {png}")
    finally:
        if engine_proc is not None:
            engine_proc.terminate()
            engine_proc.wait(timeout=3)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
