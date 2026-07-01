#!/usr/bin/env python3
"""Smoke test: MiniFX engine AudioPush + AudioPull loop."""

from __future__ import annotations

import argparse
import socket
import struct
import sys
import time

HDLM = 0x48444C4D
HDLA = 0x48444C41
VERSION = 5
PT_HELLO = 1
PT_ACK = 2
PT_PULL = 8
PT_PUSH = 9


def be32(v: int) -> bytes:
    return struct.pack(">I", v)


def be16(v: int) -> bytes:
    return struct.pack(">H", v)


def be64(v: int) -> bytes:
    return struct.pack(">Q", v)


def ctrl_hdr(ptype: int, seq: int, payload_len: int) -> bytes:
    return be32(HDLM) + bytes([VERSION, ptype]) + be16(payload_len) + be32(seq)


def hello(seq: int, sr: int, audio_port: int) -> bytes:
    payload = (
        be32(sr)
        + be16(512)
        + be32(0x56535431)
        + be16(audio_port)
        + bytes([1, 0])
        + be16(256)
        + be16(8)
        + be16(4)
        + be16(8)
    )
    return ctrl_hdr(PT_HELLO, seq, len(payload)) + payload


def pull(seq: int, frames: int) -> bytes:
    payload = be32(1) + be32(frames) + be32(0) + be32(0)
    return ctrl_hdr(PT_PULL, seq, len(payload)) + payload


def audio_push(seq: int, frames: int, samples: list[int]) -> bytes:
    hdr = (
        be32(HDLA)
        + bytes([VERSION, 0])
        + be32(seq)
        + be64(int(time.time() * 1e6))
        + be16(frames)
        + bytes([2, 0])
    )
    body = b"".join(struct.pack("<h", s) for s in samples)
    payload = hdr + body
    return ctrl_hdr(PT_PUSH, seq, len(payload)) + payload


def decode_ack(data: bytes) -> dict | None:
    if len(data) < 12 or struct.unpack(">I", data[:4])[0] != HDLM:
        return None
    if data[5] != PT_ACK:
        return None
    plen = struct.unpack(">H", data[6:8])[0]
    payload = data[12 : 12 + plen]
    if len(payload) < 16:
        return None
    caps = struct.unpack(">H", payload[12:14])[0]
    return {"caps": caps}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--control-port", type=int, default=5004)
    parser.add_argument("--audio-port", type=int, default=5005)
    parser.add_argument("--frames", type=int, default=256)
    args = parser.parse_args()

    ctrl = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    ctrl.bind(("0.0.0.0", 0))
    ctrl.settimeout(2.0)
    audio = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    audio.bind(("0.0.0.0", args.audio_port))
    audio.settimeout(2.0)

    seq = 1
    ctrl.sendto(hello(seq, 44100, args.audio_port), (args.host, args.control_port))
    seq += 1

    ack_data, _ = ctrl.recvfrom(2048)
    ack = decode_ack(ack_data)
    if not ack or (ack["caps"] & 1) == 0:
        print("No kCapAudioPush in Ack — is MiniFX running?", file=sys.stderr)
        return 1

    # Push sine-like block
    samples = []
    for i in range(args.frames):
        v = int(16000 * ((i % 32) / 32.0 - 0.5))
        samples.extend([v, v])
    ctrl.sendto(audio_push(seq, args.frames, samples), (args.host, args.control_port))
    seq += 1

    ctrl.sendto(pull(seq, args.frames), (args.host, args.control_port))
    seq += 1

    pcm, _ = audio.recvfrom(8192)
    if len(pcm) < 22 or struct.unpack(">I", pcm[:4])[0] != HDLA:
        print("No HDLA response", file=sys.stderr)
        return 1

    frames = struct.unpack(">H", pcm[18:20])[0]
    print(f"mini_fx e2e OK: received {frames} frames, caps=0x{ack['caps']:04x}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
