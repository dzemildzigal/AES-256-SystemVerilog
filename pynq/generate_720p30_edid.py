#!/usr/bin/env python3
"""Generate the dvi2rgb 128-line 720p30 EDID memory file.

The Digilent dvi2rgb IP loads EDID with $readmemb: one 8-bit binary value per
line. The checked-in .hex file is the fetched 128-byte source. This script
only converts and validates it; it does not edit the PYNQ vendor checkout.
"""

from __future__ import annotations

import argparse
from pathlib import Path


WIDTH = 1280
HEIGHT = 720
EXPECTED_BYTES = 128


def read_hex_source(path: Path) -> bytes:
    values: list[int] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.split("#", 1)[0]
        for token in line.split():
            if len(token) != 2:
                raise ValueError(f"invalid EDID byte {token!r} in {path}")
            try:
                values.append(int(token, 16))
            except ValueError as exc:
                raise ValueError(f"invalid EDID byte {token!r} in {path}") from exc
    if len(values) != EXPECTED_BYTES:
        raise ValueError(f"EDID must contain {EXPECTED_BYTES} bytes, got {len(values)}")
    data = bytes(values)
    if data[:8] != bytes.fromhex("00 ff ff ff ff ff ff 00"):
        raise ValueError("EDID header is invalid")
    if sum(data) & 0xFF:
        raise ValueError(f"EDID checksum is invalid: 0x{sum(data) & 0xFF:02x}")
    return data


def decode_preferred_timing(data: bytes) -> tuple[int, int, int, int, int, float]:
    dtd = data[54:72]
    pixel_clock_hz = int.from_bytes(dtd[0:2], "little") * 10_000
    hactive = dtd[2] | ((dtd[4] & 0xF0) << 4)
    hblank = dtd[3] | ((dtd[4] & 0x0F) << 8)
    vactive = dtd[5] | ((dtd[7] & 0xF0) << 4)
    vblank = dtd[6] | ((dtd[7] & 0x0F) << 8)
    refresh_hz = pixel_clock_hz / ((hactive + hblank) * (vactive + vblank))
    return pixel_clock_hz, hactive, hblank, vactive, vblank, refresh_hz


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    here = Path(__file__).resolve().parent
    parser.add_argument("--source", type=Path, default=here / "720p30_edid.hex")
    parser.add_argument("--output", type=Path, default=here / "720p30_edid.data")
    args = parser.parse_args()

    data = read_hex_source(args.source)
    timing = decode_preferred_timing(data)
    pixel_clock_hz, hactive, hblank, vactive, vblank, refresh_hz = timing
    if (hactive, vactive) != (WIDTH, HEIGHT):
        raise ValueError(f"preferred timing is {hactive}x{vactive}, not {WIDTH}x{HEIGHT}")
    if not 29.0 <= refresh_hz <= 31.0:
        raise ValueError(f"preferred timing is {refresh_hz:.6f} Hz, not 30 Hz")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        "".join(f"{value:08b}\n" for value in data),
        encoding="utf-8",
        newline="\n",
    )
    print(
        f"generated {args.output}: {len(data)} bytes, checksum=0x{sum(data) & 0xFF:02x}, "
        f"{hactive}x{vactive}@{refresh_hz:.6f} Hz, "
        f"pixel_clock={pixel_clock_hz / 1_000_000:.5f} MHz, "
        f"Htotal={hactive + hblank}, Vtotal={vactive + vblank}"
    )


if __name__ == "__main__":
    main()
