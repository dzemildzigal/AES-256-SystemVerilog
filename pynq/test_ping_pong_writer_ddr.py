"""
Ping-pong deterministic DDR writer smoke/integrity check for PYNQ Z2.

This test validates the new PL AXI master write path by:
1) allocating two PS-owned DDR buffers,
2) programming their physical addresses into ping-pong writer registers,
3) enabling deterministic writer mode,
4) checking READY/FRAME_ID/VALID_BYTES,
5) verifying first data word pattern in the produced buffer.

Usage:
  sudo python3 test_ping_pong_writer_ddr.py
"""

from __future__ import annotations

import time

import numpy as np
from pynq import Overlay, allocate

BITSTREAM = "aes_gcm_ping_pong_wrapper.bit"
IP_NAME = "aes_pingpong_0"

REG_VERSION = 0x0000
REG_CONTROL = 0x0004
REG_STATUS = 0x0008
REG_FRAME_BYTES_CFG = 0x0010
REG_WRITE_INDEX = 0x0014
REG_READY_MASK = 0x0018
REG_CONSUMED_MASK = 0x001C
REG_FRAME_ID_BUF0 = 0x0020
REG_FRAME_ID_BUF1 = 0x0024
REG_VALID_BYTES_BUF0 = 0x0028
REG_VALID_BYTES_BUF1 = 0x002C
REG_DROP_COUNT = 0x0030
REG_IRQ_ENABLE = 0x0034
REG_IRQ_STATUS = 0x0038

REG_WRITER_ENABLE = 0x0040
REG_BUF0_ADDR_LO = 0x0044
REG_BUF0_ADDR_HI = 0x0048
REG_BUF1_ADDR_LO = 0x004C
REG_BUF1_ADDR_HI = 0x0050
REG_WRITER_STATUS = 0x0054
REG_WRITER_ERROR_COUNT = 0x0058
REG_WRITER_CMD = 0x005C
REG_WRITER_SRC_SEL = 0x0060

CTRL_ENABLE = 1 << 0
CTRL_SOFT_RESET = 1 << 1

READY_BUF0 = 1 << 0
READY_BUF1 = 1 << 1

VERSION_EXPECTED = 0x00010000
TARGET_FRAMES = 64


def wait_until(cond, timeout_s: float, what: str) -> None:
    t0 = time.perf_counter()
    while not cond():
        if (time.perf_counter() - t0) > timeout_s:
            raise TimeoutError(f"Timeout waiting for {what}")


def split_u64(v: int) -> tuple[int, int]:
    return v & 0xFFFFFFFF, (v >> 32) & 0xFFFFFFFF


def u32_delta(end: int, start: int) -> int:
    return (end - start) & 0xFFFFFFFF


print(f"Loading overlay: {BITSTREAM}")
ol = Overlay(BITSTREAM)
ip = getattr(ol, IP_NAME)

version = ip.read(REG_VERSION)
print(f"VERSION = 0x{version:08x}")
if version != VERSION_EXPECTED:
    raise RuntimeError(f"Unexpected VERSION value: 0x{version:08x}")

frame_bytes = 120000
word_bytes = 8
words = (frame_bytes + word_bytes - 1) // word_bytes

buf0 = allocate(shape=(words,), dtype=np.uint64)
buf1 = allocate(shape=(words,), dtype=np.uint64)

buf0_addr = int(buf0.device_address)
buf1_addr = int(buf1.device_address)

buf0_lo, buf0_hi = split_u64(buf0_addr)
buf1_lo, buf1_hi = split_u64(buf1_addr)

print(f"BUF0 addr = 0x{buf0_addr:016x}")
print(f"BUF1 addr = 0x{buf1_addr:016x}")

# Program writer mode and reset runtime state.
ip.write(REG_FRAME_BYTES_CFG, frame_bytes)
ip.write(REG_WRITER_ENABLE, 0)
ip.write(REG_CONTROL, CTRL_SOFT_RESET)
ip.write(REG_IRQ_ENABLE, 0)
ip.write(REG_WRITER_CMD, 0x3)  # clear fault + error_count

ip.write(REG_BUF0_ADDR_LO, buf0_lo)
ip.write(REG_BUF0_ADDR_HI, buf0_hi)
ip.write(REG_BUF1_ADDR_LO, buf1_lo)
ip.write(REG_BUF1_ADDR_HI, buf1_hi)

ip.write(REG_WRITER_SRC_SEL, 0)
ip.write(REG_WRITER_ENABLE, 1)
ip.write(REG_CONTROL, CTRL_ENABLE)

wait_until(lambda: (ip.read(REG_READY_MASK) & (READY_BUF0 | READY_BUF1)) != 0, 2.5, "READY_MASK non-zero")
ready = ip.read(REG_READY_MASK)
print(f"READY_MASK = 0x{ready:08x}")

drops_start = ip.read(REG_DROP_COUNT)
print(f"DROP_COUNT start = {drops_start}")

buf_hits = [0, 0]
last_frame_id = None

for i in range(TARGET_FRAMES):
    wait_until(lambda: (ip.read(REG_READY_MASK) & (READY_BUF0 | READY_BUF1)) != 0, 2.5, "produced frame")
    ready = ip.read(REG_READY_MASK)

    if ready & READY_BUF0:
        produced_buf = buf0
        consume_mask = READY_BUF0
        frame_id = ip.read(REG_FRAME_ID_BUF0)
        valid = ip.read(REG_VALID_BYTES_BUF0)
        selected = 0
    else:
        produced_buf = buf1
        consume_mask = READY_BUF1
        frame_id = ip.read(REG_FRAME_ID_BUF1)
        valid = ip.read(REG_VALID_BYTES_BUF1)
        selected = 1

    if valid != frame_bytes:
        raise RuntimeError(f"VALID_BYTES mismatch on iter {i}: got {valid}, expected {frame_bytes}")

    produced_buf.sync_from_device()
    word0 = int(produced_buf[0])
    expected_word0 = ((frame_id & 0xFFFFFFFF) << 32) | 0
    if word0 != expected_word0:
        raise RuntimeError(
            f"Deterministic pattern mismatch on iter {i}: "
            f"word0=0x{word0:016x} expected=0x{expected_word0:016x}"
        )

    if i == 0:
        print(f"Produced buffer={selected} frame_id={frame_id} valid_bytes={valid}")
        print(f"word0=0x{word0:016x} expected=0x{expected_word0:016x}")
    elif (i + 1) % 16 == 0:
        print(f"Progress: consumed {i + 1}/{TARGET_FRAMES} frames (latest buffer={selected}, frame_id={frame_id})")

    ip.write(REG_CONSUMED_MASK, consume_mask)
    wait_until(lambda: (ip.read(REG_READY_MASK) & consume_mask) == 0, 1.5, "consumed ready bit clear")

    buf_hits[selected] += 1
    last_frame_id = frame_id

drops_end_active = ip.read(REG_DROP_COUNT)
drop_delta = u32_delta(drops_end_active, drops_start)

# Freeze producer before final status capture so counters represent this window.
ip.write(REG_CONTROL, 0)
wait_until(lambda: (ip.read(REG_WRITER_STATUS) & 0x1) == 0, 1.5, "writer busy clear")

status = ip.read(REG_STATUS)
writer_status = ip.read(REG_WRITER_STATUS)
writer_errors = ip.read(REG_WRITER_ERROR_COUNT)
drops = ip.read(REG_DROP_COUNT)
write_index = ip.read(REG_WRITE_INDEX)

print(
    f"STATUS=0x{status:08x} WRITER_STATUS=0x{writer_status:08x} "
    f"WRITE_INDEX={write_index} DROP_COUNT={drops} WRITER_ERROR_COUNT={writer_errors}"
)
print(
    f"Consumed frames={TARGET_FRAMES} buf0_hits={buf_hits[0]} buf1_hits={buf_hits[1]} "
    f"last_frame_id={last_frame_id} DROP_DELTA={drop_delta}"
)

if writer_status & 0x2:
    raise RuntimeError("Writer fault is set")
if writer_errors != 0:
    raise RuntimeError(f"Writer error count is non-zero: {writer_errors}")

print("Ping-pong deterministic DDR writer test PASSED")
