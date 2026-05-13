"""
Ping-pong AES stream writer integration test for PYNQ Z2.

This test validates the stream-mode writer path:
  DMA MM2S -> AXI_AES_GCM_Stream -> AXI_PingPong_Ctrl -> DDR

It uses a known AES-256 GCM vector and checks that ciphertext bytes stored in
DDR by the ping-pong writer match expected output.

Usage:
  sudo python3 test_ping_pong_writer_aes_stream.py
"""

from __future__ import annotations

import time

import numpy as np
from pynq import Overlay, allocate

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM  # type: ignore

    HAVE_AESGCM = True
except Exception:
    HAVE_AESGCM = False

BITSTREAM = "aes_gcm_ping_pong_wrapper.bit"
PP_IP_NAME = "aes_pingpong_0"
AES_IP_NAME = "aes_gcm_0"
DMA_NAME = "axi_dma_0"

# Ping-pong registers
PP_REG_VERSION = 0x0000
PP_REG_CONTROL = 0x0004
PP_REG_STATUS = 0x0008
PP_REG_FRAME_BYTES_CFG = 0x0010
PP_REG_WRITE_INDEX = 0x0014
PP_REG_READY_MASK = 0x0018
PP_REG_CONSUMED_MASK = 0x001C
PP_REG_FRAME_ID_BUF0 = 0x0020
PP_REG_FRAME_ID_BUF1 = 0x0024
PP_REG_VALID_BYTES_BUF0 = 0x0028
PP_REG_VALID_BYTES_BUF1 = 0x002C
PP_REG_DROP_COUNT = 0x0030
PP_REG_IRQ_ENABLE = 0x0034
PP_REG_WRITER_ENABLE = 0x0040
PP_REG_BUF0_ADDR_LO = 0x0044
PP_REG_BUF0_ADDR_HI = 0x0048
PP_REG_BUF1_ADDR_LO = 0x004C
PP_REG_BUF1_ADDR_HI = 0x0050
PP_REG_WRITER_STATUS = 0x0054
PP_REG_WRITER_ERROR_COUNT = 0x0058
PP_REG_WRITER_CMD = 0x005C
PP_REG_WRITER_SRC_SEL = 0x0060

PP_CTRL_ENABLE = 1 << 0
PP_CTRL_SOFT_RESET = 1 << 1

PP_READY_BUF0 = 1 << 0
PP_READY_BUF1 = 1 << 1

PP_VERSION_EXPECTED = 0x00010000

# AES registers
AES_CTRL = 0x00
AES_STATUS = 0x04
AES_KEY_BASE = 0x08
AES_NONCE_BASE = 0x28
AES_AAD_LEN_HI = 0x34
AES_AAD_LEN_LO = 0x38
AES_PT_LEN_HI = 0x3C
AES_PT_LEN_LO = 0x40
AES_AAD_BASE = 0x44
AES_TAG_BASE = 0x88

AES_CTRL_LOAD_KEY = 1 << 1
AES_CTRL_START_SESSION = 1 << 2
AES_CTRL_PUSH_AAD = 1 << 3
AES_CTRL_AAD_LAST = 1 << 4
AES_CTRL_SET_STREAM = 1 << 7

AES_STS_KEYS_READY_MASK = 0xF
AES_STS_SESSION_READY = 1 << 4
AES_STS_AAD_READY = 1 << 5
AES_STS_H_VALID = 1 << 8
AES_STS_TAG_VALID = 1 << 12
AES_STS_STREAM_MODE = 1 << 17

# Known vector (NIST-style AES-256 GCM case used in existing DMA test)
KEY = bytes.fromhex(
    "603deb1015ca71be2b73aef0857d7781"
    "1f352c073b6108d72d9810a30914dff4"
)
NONCE = bytes.fromhex("f0f1f2f3f4f5f6f7f8f9fafb")
AAD = bytes.fromhex(
    "feedfacedeadbeeffeedfacedeadbeef"
    "abaddad2000000000000000000000001"
)
PT = bytes.fromhex(
    "6bc1bee22e409f96e93d7e117393172a"
    "ae2d8a571e03ac9c9eb76fac45af8e51"
    "30c81c46a35ce411e5fbc1191a0a52ef"
    "f69f2445df4f9b17ad2b417be66c3710"
)

EXPECTED_CT_FALLBACK = bytes.fromhex(
    "522dc1f099567d07f47f37a32a84427d"
    "643a8cdcbfe5c0c97598a2bd2555d1aa"
    "8cb08e48590dbb3da7b08b1056828838"
    "c5f61e6393ba7a0abcc9f662898015ad"
)
EXPECTED_TAG_FALLBACK = bytes.fromhex("b094dac5d93471bdec1a502270e3cc6c")


def wait_until(cond, timeout_s: float, what: str) -> None:
    t0 = time.perf_counter()
    while not cond():
        if (time.perf_counter() - t0) > timeout_s:
            raise TimeoutError(f"Timeout waiting for {what}")


def wait_dma_send_done(dma, timeout_s: float, what: str = "dma mm2s done") -> None:
    t0 = time.perf_counter()
    while True:
        if dma.sendchannel.idle:
            return
        if (time.perf_counter() - t0) > timeout_s:
            raise TimeoutError(f"Timeout waiting for {what}")
        time.sleep(0.001)


def log(msg: str) -> None:
    print(msg, flush=True)


def split_u64(v: int) -> tuple[int, int]:
    return v & 0xFFFFFFFF, (v >> 32) & 0xFFFFFFFF


def read_aes_block(ip, base: int) -> bytes:
    out = bytearray()
    for i in range(4):
        word = ip.read(base + i * 4)
        out.extend(int(word).to_bytes(4, byteorder="big"))
    return bytes(out)


def write_aes_key(ip, key: bytes) -> None:
    for i in range(8):
        ip.write(AES_KEY_BASE + i * 4, int.from_bytes(key[i * 4 : (i + 1) * 4], byteorder="big"))


def write_aes_nonce(ip, nonce12: bytes) -> None:
    for i in range(3):
        ip.write(AES_NONCE_BASE + i * 4, int.from_bytes(nonce12[i * 4 : (i + 1) * 4], byteorder="big"))


def write_aes_lengths(ip, aad_len_bits: int, pt_len_bits: int) -> None:
    ip.write(AES_AAD_LEN_HI, (aad_len_bits >> 32) & 0xFFFFFFFF)
    ip.write(AES_AAD_LEN_LO, aad_len_bits & 0xFFFFFFFF)
    ip.write(AES_PT_LEN_HI, (pt_len_bits >> 32) & 0xFFFFFFFF)
    ip.write(AES_PT_LEN_LO, pt_len_bits & 0xFFFFFFFF)


def push_aad_blocks(ip, aad: bytes) -> None:
    if len(aad) % 16 != 0:
        raise ValueError("AAD length must be 16-byte aligned")

    block_count = len(aad) // 16
    for i in range(block_count):
        wait_until(lambda: (ip.read(AES_STATUS) & AES_STS_AAD_READY) != 0, 2.0, "aad_ready")
        block = aad[i * 16 : (i + 1) * 16]
        for w in range(4):
            word = int.from_bytes(block[w * 4 : (w + 1) * 4], byteorder="big")
            ip.write(AES_AAD_BASE + w * 4, word)
        ctrl = AES_CTRL_PUSH_AAD | (AES_CTRL_AAD_LAST if i == (block_count - 1) else 0)
        ip.write(AES_CTRL, ctrl)


def get_expected_ct_tag() -> tuple[bytes, bytes]:
    if HAVE_AESGCM:
        out = AESGCM(KEY).encrypt(NONCE, PT, AAD)
        return out[:-16], out[-16:]
    return EXPECTED_CT_FALLBACK, EXPECTED_TAG_FALLBACK


log(f"Loading overlay: {BITSTREAM}")
ol = Overlay(BITSTREAM)
pp = getattr(ol, PP_IP_NAME)
aes = getattr(ol, AES_IP_NAME)
dma = getattr(ol, DMA_NAME)

pp_version = pp.read(PP_REG_VERSION)
log(f"PP VERSION = 0x{pp_version:08x}")
if pp_version != PP_VERSION_EXPECTED:
    raise RuntimeError(f"Unexpected ping-pong VERSION value: 0x{pp_version:08x}")

frame_bytes = len(PT)
word_bytes = 8

# Avoid tiny CMA allocations during bring-up; this board has shown occasional
# allocator lockups on very small buffers after PL reconfiguration.
alloc_bytes = max(frame_bytes, 120000)
words = (alloc_bytes + word_bytes - 1) // word_bytes

log("Allocating DDR buffers...")
log(f"frame_bytes={frame_bytes} alloc_bytes={alloc_bytes}")
log("Allocating BUF0...")
buf0 = allocate(shape=(words,), dtype=np.uint64)
log("Allocating BUF1...")
buf1 = allocate(shape=(words,), dtype=np.uint64)

buf0_addr = int(buf0.device_address)
buf1_addr = int(buf1.device_address)
buf0_lo, buf0_hi = split_u64(buf0_addr)
buf1_lo, buf1_hi = split_u64(buf1_addr)

log(f"BUF0 addr = 0x{buf0_addr:016x}")
log(f"BUF1 addr = 0x{buf1_addr:016x}")

# Configure ping-pong writer in stream source mode.
log("Configuring ping-pong writer (stream source mode)...")
pp.write(PP_REG_IRQ_ENABLE, 0)
pp.write(PP_REG_WRITER_ENABLE, 0)
pp.write(PP_REG_CONTROL, PP_CTRL_SOFT_RESET)
pp.write(PP_REG_WRITER_CMD, 0x3)  # clear fault + error_count
pp.write(PP_REG_FRAME_BYTES_CFG, frame_bytes)
pp.write(PP_REG_BUF0_ADDR_LO, buf0_lo)
pp.write(PP_REG_BUF0_ADDR_HI, buf0_hi)
pp.write(PP_REG_BUF1_ADDR_LO, buf1_lo)
pp.write(PP_REG_BUF1_ADDR_HI, buf1_hi)
pp.write(PP_REG_WRITER_SRC_SEL, 1)
pp.write(PP_REG_WRITER_ENABLE, 1)
pp.write(PP_REG_CONTROL, PP_CTRL_ENABLE)

drops_start = pp.read(PP_REG_DROP_COUNT)

# Configure AES stream session.
log("Configuring AES session...")
write_aes_key(aes, KEY)
write_aes_nonce(aes, NONCE)
write_aes_lengths(aes, len(AAD) * 8, len(PT) * 8)
aes.write(AES_CTRL, AES_CTRL_SET_STREAM)
wait_until(lambda: (aes.read(AES_STATUS) & AES_STS_STREAM_MODE) != 0, 1.0, "stream_mode=1")

aes.write(AES_CTRL, AES_CTRL_LOAD_KEY)
wait_until(lambda: (aes.read(AES_STATUS) & AES_STS_KEYS_READY_MASK) == 0xF, 2.0, "keys_ready == 0xF")
wait_until(lambda: (aes.read(AES_STATUS) & AES_STS_H_VALID) != 0, 2.0, "h_valid")

wait_until(lambda: (aes.read(AES_STATUS) & AES_STS_SESSION_READY) != 0, 2.0, "session_ready")
aes.write(AES_CTRL, AES_CTRL_START_SESSION)
push_aad_blocks(aes, AAD)

# Send plaintext through MM2S into AES stream input.
log("Starting DMA MM2S transfer...")
tx_alloc_bytes = max(frame_bytes, 4096)
tx = allocate(shape=(tx_alloc_bytes,), dtype=np.uint8)
try:
    tx[:] = 0
    tx[:frame_bytes] = np.frombuffer(PT, dtype=np.uint8)
    tx.flush()
    dma.sendchannel.transfer(tx, nbytes=frame_bytes)
    wait_dma_send_done(dma, 3.0)
finally:
    tx.freebuffer()

wait_until(lambda: (pp.read(PP_REG_READY_MASK) & (PP_READY_BUF0 | PP_READY_BUF1)) != 0, 3.0, "produced frame")
ready = pp.read(PP_REG_READY_MASK)

if ready & PP_READY_BUF0:
    produced_buf = buf0
    consume_mask = PP_READY_BUF0
    frame_id = pp.read(PP_REG_FRAME_ID_BUF0)
    valid_bytes = pp.read(PP_REG_VALID_BYTES_BUF0)
    produced_idx = 0
else:
    produced_buf = buf1
    consume_mask = PP_READY_BUF1
    frame_id = pp.read(PP_REG_FRAME_ID_BUF1)
    valid_bytes = pp.read(PP_REG_VALID_BYTES_BUF1)
    produced_idx = 1

log(f"Produced buffer={produced_idx} frame_id={frame_id} valid_bytes={valid_bytes}")
if valid_bytes != frame_bytes:
    raise RuntimeError(f"VALID_BYTES mismatch: got {valid_bytes}, expected {frame_bytes}")

produced_buf.sync_from_device()
frame_bytes_hw = produced_buf.view(np.uint8)[:valid_bytes].tobytes()

expected_ct, expected_tag = get_expected_ct_tag()
log(f"Expected source: {'cryptography AESGCM' if HAVE_AESGCM else 'built-in fallback vector'}")

if frame_bytes_hw != expected_ct:
    raise RuntimeError(
        "Ciphertext mismatch in DDR payload. "
        f"hw={frame_bytes_hw.hex()} expected={expected_ct.hex()}"
    )

wait_until(lambda: (aes.read(AES_STATUS) & AES_STS_TAG_VALID) != 0, 3.0, "tag_valid")
tag_hw = read_aes_block(aes, AES_TAG_BASE)
if tag_hw != expected_tag:
    raise RuntimeError(f"Tag mismatch: hw={tag_hw.hex()} expected={expected_tag.hex()}")

# Consume frame and freeze writer before final status.
pp.write(PP_REG_CONSUMED_MASK, consume_mask)
wait_until(lambda: (pp.read(PP_REG_READY_MASK) & consume_mask) == 0, 1.5, "consumed ready bit clear")

pp.write(PP_REG_CONTROL, 0)
wait_until(lambda: (pp.read(PP_REG_WRITER_STATUS) & 0x1) == 0, 1.5, "writer busy clear")

status = pp.read(PP_REG_STATUS)
writer_status = pp.read(PP_REG_WRITER_STATUS)
writer_errors = pp.read(PP_REG_WRITER_ERROR_COUNT)
drops_end = pp.read(PP_REG_DROP_COUNT)
write_index = pp.read(PP_REG_WRITE_INDEX)

log(
    f"STATUS=0x{status:08x} WRITER_STATUS=0x{writer_status:08x} "
    f"WRITE_INDEX={write_index} DROP_COUNT={drops_end} "
    f"WRITER_ERROR_COUNT={writer_errors}"
)
log(f"DROP_DELTA={(drops_end - drops_start) & 0xFFFFFFFF}")

if writer_status & 0x2:
    raise RuntimeError("Writer fault is set")
if writer_errors != 0:
    raise RuntimeError(f"Writer error count is non-zero: {writer_errors}")

log("Ping-pong AES stream DDR writer test PASSED")
