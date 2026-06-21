#!/usr/bin/env python3
"""Send HELLO + pull loop + NOTE_ON; receive PCM from pull-mode engine."""

from __future__ import annotations

import argparse
import socket
import struct
import sys
import time
import wave
from pathlib import Path

HDLM = 0x48444C4D
HDLA = 0x48444C41
VER = 2

PT_HELLO = 1
PT_ACK = 2
PT_NOTE_ON = 5
PT_NOTE_OFF = 6
PT_AUDIO_PULL = 8
PT_CONTROL_CHANGE = 9

SESSION_MODE_PULL = 1
PACKET_FRAMES = 256
WARMUP_PACKETS = 16
MIN_RESERVE = 6
TARGET_RESERVE = 12


def be32(v: int) -> bytes:
    return struct.pack(">I", v)


def be16(v: int) -> bytes:
    return struct.pack(">H", v)


def be64(v: int) -> bytes:
    return struct.pack(">Q", v)


def parse_control(data: bytes):
    if len(data) < 12:
        return None
    magic, ver, ptype, plen, seq = struct.unpack(">IBBHI", data[:12])
    if magic != HDLM or ver != VER:
        return None
    if len(data) < 12 + plen:
        return None
    return ptype, seq, data[12 : 12 + plen]


def parse_audio(data: bytes):
    if len(data) < 22:
        return None
    magic, ver, _reserved, seq, ts, frames, ch, _pad = struct.unpack(">IBBIQHBB", data[:22])
    if magic != HDLA or ver != VER:
        return None
    sample_bytes = frames * ch * 2
    if len(data) < 22 + sample_bytes:
        return None
    samples = struct.unpack(f">{frames * ch}h", data[22 : 22 + sample_bytes])
    return seq, ts, frames, ch, samples


def encode_hello(seq: int, audio_port: int) -> bytes:
    payload = (
        be32(48000)
        + be16(256)
        + be32(0x50595448)
        + be16(audio_port)
        + struct.pack(">BB", SESSION_MODE_PULL, 0)
        + be16(PACKET_FRAMES)
        + be16(WARMUP_PACKETS)
        + be16(MIN_RESERVE)
        + be16(TARGET_RESERVE)
    )
    return be32(HDLM) + struct.pack(">BB", VER, PT_HELLO) + be16(len(payload)) + be32(seq) + payload


def encode_pull(seq: int, request_id: int, frame_count: int, host_fill: int, host_target: int) -> bytes:
    payload = be32(request_id) + be32(frame_count) + be32(host_fill) + be32(host_target)
    return be32(HDLM) + struct.pack(">BB", VER, PT_AUDIO_PULL) + be16(len(payload)) + be32(seq) + payload


def encode_control_change(seq: int, cc: int, value: int) -> bytes:
    payload = be64(int(time.time() * 1e6)) + struct.pack(">BB", cc, value) + bytes(6)
    return be32(HDLM) + struct.pack(">BB", VER, PT_CONTROL_CHANGE) + be16(len(payload)) + be32(seq) + payload


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine-host", default="127.0.0.1")
    parser.add_argument("--control-port", type=int, default=5004)
    parser.add_argument("--audio-port", type=int, default=5005)
    parser.add_argument("--duration", type=float, default=2.0)
    parser.add_argument("--note", type=int, default=60)
    parser.add_argument("--wav", type=Path, default=Path("udp_test_out.wav"))
    parser.add_argument("--cc-attack", type=int, default=None, help="Send MIDI CC 16 before note-on")
    args = parser.parse_args()

    ctrl = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    ctrl.bind(("0.0.0.0", 0))
    ctrl.settimeout(1.0)

    audio = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    audio.bind(("0.0.0.0", args.audio_port))
    audio.settimeout(0.05)

    ctrl.sendto(encode_hello(1, args.audio_port), (args.engine_host, args.control_port))

    ack = None
    deadline = time.time() + 3.0
    while time.time() < deadline:
        try:
            data, _ = ctrl.recvfrom(2048)
        except socket.timeout:
            continue
        parsed = parse_control(data)
        if parsed and parsed[0] == PT_ACK:
            ack = parsed
            break
    if ack is None:
        print("No ACK from engine", file=sys.stderr)
        return 1
    print("ACK received (protocol v2 pull)")

    if args.cc_attack is not None:
        ctrl.sendto(
            encode_control_change(2, 16, args.cc_attack),
            (args.engine_host, args.control_port),
        )

    note_payload = be64(int(time.time() * 1e6)) + struct.pack(">BB", args.note, 100)
    note_on = be32(HDLM) + struct.pack(">BB", VER, PT_NOTE_ON) + be16(len(note_payload)) + be32(3) + note_payload
    ctrl.sendto(note_on, (args.engine_host, args.control_port))

    pcm: list[int] = []
    request_id = 0
    seq = 4
    target_fill = TARGET_RESERVE * PACKET_FRAMES
    warmup = WARMUP_PACKETS * PACKET_FRAMES

    end = time.time() + args.duration
    while time.time() < end:
        fill = len(pcm)
        if fill < warmup or fill < MIN_RESERVE * PACKET_FRAMES:
            need = min(target_fill, max(PACKET_FRAMES, target_fill - fill))
            request_id += 1
            seq += 1
            pull = encode_pull(seq, request_id, need, fill, target_fill)
            ctrl.sendto(pull, (args.engine_host, args.control_port))

        try:
            data, _ = audio.recvfrom(4096)
        except socket.timeout:
            continue
        parsed = parse_audio(data)
        if parsed:
            _seq, _ts, _frames, ch, samples = parsed
            if ch == 1:
                pcm.extend(samples)
            else:
                pcm.extend(samples[0::2])

    note_off_payload = be64(int(time.time() * 1e6)) + struct.pack(">BB", args.note, 0)
    note_off = be32(HDLM) + struct.pack(">BB", VER, PT_NOTE_OFF) + be16(len(note_off_payload)) + be32(3) + note_off_payload
    ctrl.sendto(note_off, (args.engine_host, args.control_port))

    if not pcm:
        print("No audio packets received", file=sys.stderr)
        return 1

    with wave.open(str(args.wav), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(48000)
        wf.writeframes(struct.pack(f"{len(pcm)}h", *pcm))

    peak = max(abs(s) for s in pcm)
    print(f"Received {len(pcm)} samples, peak={peak}, wrote {args.wav}")
    return 0 if peak > 100 else 1


if __name__ == "__main__":
    raise SystemExit(main())
