#!/usr/bin/env python3
"""Request runtime parameter schema from an hdl_net v5 engine."""

from __future__ import annotations

import argparse
import socket
import struct
import sys

HDLM = 0x48444C4D
VER = 5
PT_PARAM_SCHEMA_REQUEST = 10
PT_PARAM_SCHEMA_DATA = 11


def be32(v: int) -> bytes:
    return struct.pack(">I", v)


def be16(v: int) -> bytes:
    return struct.pack(">H", v)


def encode_request(seq: int) -> bytes:
    return be32(HDLM) + struct.pack(">BB", VER, PT_PARAM_SCHEMA_REQUEST) + be16(0) + be32(seq)


def parse_schema(data: bytes) -> tuple[int, str] | None:
    if len(data) < 20:
        return None
    magic, ver, ptype, plen, _seq = struct.unpack(">IBBHI", data[:12])
    if magic != HDLM or ver != VER or ptype != PT_PARAM_SCHEMA_DATA:
        return None
    if len(data) < 12 + plen or plen < 8:
        return None
    schema_hash, schema_len = struct.unpack(">II", data[12:20])
    if schema_len == 0 or 20 + schema_len > len(data):
        return None
    return schema_hash, data[20 : 20 + schema_len].decode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine-host", default="127.0.0.1")
    parser.add_argument("--control-port", type=int, default=5004)
    args = parser.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", 0))
    sock.settimeout(2.0)
    sock.sendto(encode_request(1), (args.engine_host, args.control_port))

    try:
        data, _addr = sock.recvfrom(65535)
    except socket.timeout:
        print("No schema response from engine", file=sys.stderr)
        return 1

    parsed = parse_schema(data)
    if parsed is None:
        print("Invalid schema response", file=sys.stderr)
        return 1

    schema_hash, text = parsed
    required = [
        "id: mono_synth",
        "id: pwm_duty",
        "id: vca_lfo_rate",
        "id: vcf_lfo_shape",
        "midi_values: [0, 16, 32, 48, 64, 80]",
    ]
    missing = [needle for needle in required if needle not in text]
    if missing:
        print("Schema is missing expected entries:", ", ".join(missing), file=sys.stderr)
        return 1

    print(f"schema OK: {len(text)} bytes hash=0x{schema_hash:08x}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
