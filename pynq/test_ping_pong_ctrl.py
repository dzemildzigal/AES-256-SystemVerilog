"""
Ping-pong AXI-Lite control-plane smoke test for PYNQ Z2.

Usage:
  1) Build/load bitstream from build_bd_gcm_ping_pong.tcl
  2) Copy aes_gcm_ping_pong_wrapper.bit/.hwh + this script to PYNQ
  3) Run: sudo python3 test_ping_pong_ctrl.py
"""

from __future__ import annotations

import time
from pynq import Overlay

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

CTRL_ENABLE = 1 << 0
CTRL_SOFT_RESET = 1 << 1

READY_BUF0 = 1 << 0
READY_BUF1 = 1 << 1

IRQ_FRAME_READY = 1 << 0

VERSION_EXPECTED = 0x00010000


def wait_until(cond, timeout_s: float, what: str) -> None:
    t0 = time.perf_counter()
    while not cond():
        if (time.perf_counter() - t0) > timeout_s:
            raise TimeoutError(f"Timeout waiting for {what}")


print(f"Loading overlay: {BITSTREAM}")
ol = Overlay(BITSTREAM)
ip = getattr(ol, IP_NAME)

version = ip.read(REG_VERSION)
print(f"VERSION = 0x{version:08x}")
if version != VERSION_EXPECTED:
    raise RuntimeError(f"Unexpected VERSION value: 0x{version:08x}")

# Configure frame bytes and reset runtime state.
ip.write(REG_FRAME_BYTES_CFG, 120000)
ip.write(REG_CONTROL, CTRL_SOFT_RESET)
ip.write(REG_IRQ_ENABLE, 0)

# Enable producer cadence.
ip.write(REG_CONTROL, CTRL_ENABLE)

wait_until(lambda: (ip.read(REG_READY_MASK) & (READY_BUF0 | READY_BUF1)) != 0, 2.0, "READY_MASK non-zero")
ready = ip.read(REG_READY_MASK)
print(f"READY_MASK = 0x{ready:08x}")

if ready & READY_BUF0:
    valid = ip.read(REG_VALID_BYTES_BUF0)
    frame_id = ip.read(REG_FRAME_ID_BUF0)
    consume_mask = READY_BUF0
else:
    valid = ip.read(REG_VALID_BYTES_BUF1)
    frame_id = ip.read(REG_FRAME_ID_BUF1)
    consume_mask = READY_BUF1

print(f"Observed frame: frame_id={frame_id} valid_bytes={valid}")
if valid != 120000:
    raise RuntimeError(f"VALID_BYTES mismatch: got {valid}, expected 120000")

# Consume buffer and ensure ready bit clears.
ip.write(REG_CONSUMED_MASK, consume_mask)
wait_until(lambda: (ip.read(REG_READY_MASK) & consume_mask) == 0, 1.0, "consumed ready bit clear")

# Enable IRQ status generation and check sticky bit behavior.
ip.write(REG_IRQ_ENABLE, IRQ_FRAME_READY)
wait_until(lambda: (ip.read(REG_IRQ_STATUS) & IRQ_FRAME_READY) != 0, 2.0, "IRQ_STATUS set")
print(f"IRQ_STATUS before clear = 0x{ip.read(REG_IRQ_STATUS):08x}")

ip.write(REG_IRQ_STATUS, IRQ_FRAME_READY)
wait_until(lambda: (ip.read(REG_IRQ_STATUS) & IRQ_FRAME_READY) == 0, 1.0, "IRQ_STATUS clear")
print(f"IRQ_STATUS after clear = 0x{ip.read(REG_IRQ_STATUS):08x}")

drops = ip.read(REG_DROP_COUNT)
status = ip.read(REG_STATUS)
write_index = ip.read(REG_WRITE_INDEX)
print(f"STATUS=0x{status:08x} WRITE_INDEX={write_index} DROP_COUNT={drops}")

print("Ping-pong control-plane smoke test PASSED")
