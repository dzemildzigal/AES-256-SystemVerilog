"""
AES-256 GCM test for PYNQ Z2 (AXI_AES_GCM).

Important architecture note:
- The PL core currently implements the GCM encryption path only
  (CTR keystream + GHASH over ciphertext).
- There is no separate decrypt datapath in PL.

You can still verify decrypt on PS by using a software AES-GCM library.

Usage:
  1) Build/load a bitstream containing AXI_AES_GCM_wrapper as aes_gcm_0
  2) Copy aes_gcm_wrapper.bit + aes_gcm_wrapper.hwh + this script to PYNQ
  3) Run: sudo python3 test_aes_gcm.py
"""

from __future__ import annotations

import importlib
import os
import time
from typing import Callable, Tuple

from pynq import Overlay

# Optional software reference (recommended)
AESGCM = None
try:
    _aead_mod = importlib.import_module("cryptography.hazmat.primitives.ciphers.aead")
    AESGCM = getattr(_aead_mod, "AESGCM")
    HAVE_AESGCM = True
except Exception:
    HAVE_AESGCM = False


# -----------------------------------------------------------------------------
# Register map
# -----------------------------------------------------------------------------
BITSTREAM = "aes_gcm_wrapper.bit"
IP_NAME = "aes_gcm_0"

CTRL = 0x00
STATUS = 0x04

KEY_BASE = 0x08
NONCE_BASE = 0x28
AAD_LEN_HI = 0x34
AAD_LEN_LO = 0x38
PT_LEN_HI = 0x3C
PT_LEN_LO = 0x40
AAD_BASE = 0x44
PT_BASE = 0x54
CTR_VAL = 0x64
CT_BASE = 0x68
GHASH_BASE = 0x78
TAG_BASE = 0x88
CYCLES_REG = 0x98

# CTRL bits
CTRL_PUSH_PT = 1 << 0
CTRL_LOAD_KEY = 1 << 1
CTRL_START_SESSION = 1 << 2
CTRL_PUSH_AAD = 1 << 3
CTRL_AAD_LAST = 1 << 4
CTRL_PT_LAST = 1 << 5
CTRL_ZEROIZE = 1 << 6

# STATUS bits
STS_KEYS_READY_MASK = 0xF
STS_SESSION_READY = 1 << 4
STS_AAD_READY = 1 << 5
STS_PT_READY = 1 << 6
STS_BUSY = 1 << 7
STS_H_VALID = 1 << 8
STS_CT_VALID = 1 << 9
STS_CT_LAST = 1 << 10
STS_GHASH_VALID = 1 << 11
STS_TAG_VALID = 1 << 12
STS_AAD_DROP = 1 << 13
STS_PT_DROP = 1 << 14
STS_SESSION_DROP = 1 << 15
STS_SESSION_CYCLES_VALID = 1 << 16

print(f"Loading overlay: {BITSTREAM}")
ol = Overlay(BITSTREAM)
aes = getattr(ol, IP_NAME)


def _status() -> int:
    return aes.read(STATUS)


def _status_flags_text(s: int) -> str:
    flags = []
    if s & STS_SESSION_READY:
        flags.append("session_ready")
    if s & STS_AAD_READY:
        flags.append("aad_ready")
    if s & STS_PT_READY:
        flags.append("pt_ready")
    if s & STS_BUSY:
        flags.append("busy")
    if s & STS_H_VALID:
        flags.append("h_valid")
    if s & STS_CT_VALID:
        flags.append("ct_valid")
    if s & STS_CT_LAST:
        flags.append("ct_last")
    if s & STS_GHASH_VALID:
        flags.append("ghash_valid")
    if s & STS_TAG_VALID:
        flags.append("tag_valid")
    if s & STS_AAD_DROP:
        flags.append("aad_drop")
    if s & STS_PT_DROP:
        flags.append("pt_drop")
    if s & STS_SESSION_DROP:
        flags.append("session_drop")
    if s & STS_SESSION_CYCLES_VALID:
        flags.append("session_cycles_valid")
    return ",".join(flags) if flags else "none"


def _wait_until(cond: Callable[[], bool], timeout_s: float, what: str) -> None:
    t0 = time.perf_counter()
    while not cond():
        if (time.perf_counter() - t0) > timeout_s:
            raise TimeoutError(f"Timeout waiting for {what}")


def _write_block(base: int, block16: bytes) -> None:
    if len(block16) != 16:
        raise ValueError(f"Block must be 16 bytes, got {len(block16)}")
    for i in range(4):
        word = int.from_bytes(block16[i * 4 : (i + 1) * 4], byteorder="big")
        aes.write(base + i * 4, word)


def _read_block(base: int) -> bytes:
    out = bytearray()
    for i in range(4):
        word = aes.read(base + i * 4)
        out.extend(word.to_bytes(4, byteorder="big"))
    return bytes(out)


def _write_key(key: bytes) -> None:
    if len(key) != 32:
        raise ValueError(f"Key must be 32 bytes, got {len(key)}")
    for i in range(8):
        word = int.from_bytes(key[i * 4 : (i + 1) * 4], byteorder="big")
        aes.write(KEY_BASE + i * 4, word)


def _write_nonce(nonce12: bytes) -> None:
    if len(nonce12) != 12:
        raise ValueError(f"Nonce must be 12 bytes, got {len(nonce12)}")
    for i in range(3):
        word = int.from_bytes(nonce12[i * 4 : (i + 1) * 4], byteorder="big")
        aes.write(NONCE_BASE + i * 4, word)


def _write_lengths(aad_len_bits: int, pt_len_bits: int) -> None:
    aes.write(AAD_LEN_HI, (aad_len_bits >> 32) & 0xFFFFFFFF)
    aes.write(AAD_LEN_LO, aad_len_bits & 0xFFFFFFFF)
    aes.write(PT_LEN_HI, (pt_len_bits >> 32) & 0xFFFFFFFF)
    aes.write(PT_LEN_LO, pt_len_bits & 0xFFFFFFFF)


def _load_key_and_wait() -> None:
    aes.write(CTRL, CTRL_LOAD_KEY)
    _wait_until(lambda: (_status() & STS_KEYS_READY_MASK) == 0xF, 2.0, "keys_ready == 15")
    _wait_until(lambda: (_status() & STS_H_VALID) != 0, 2.0, "h_valid")


def _start_session_and_wait_ready() -> None:
    _wait_until(lambda: (_status() & STS_SESSION_READY) != 0, 2.0, "session_ready")
    _wait_until(lambda: (_status() & STS_H_VALID) != 0, 2.0, "h_valid before session start")
    aes.write(CTRL, CTRL_START_SESSION)
    s = _status()
    if s & STS_SESSION_DROP:
        raise RuntimeError("start_session was dropped (session_drop_sticky=1)")


def _push_aad_block(block: bytes, is_last: bool) -> None:
    _wait_until(lambda: (_status() & STS_AAD_READY) != 0, 2.0, "aad_ready")
    _write_block(AAD_BASE, block)
    ctrl = CTRL_PUSH_AAD | (CTRL_AAD_LAST if is_last else 0)
    aes.write(CTRL, ctrl)


def _stream_pt_collect_ct(pt: bytes) -> Tuple[bytes, float]:
    if len(pt) % 16 != 0:
        raise ValueError("Plaintext length must be 16-byte aligned")

    blocks = len(pt) // 16
    out = bytearray()

    t0 = time.perf_counter()

    # Safe AXI-lite polling mode for sticky ct_valid semantics:
    # submit one PT block, then wait/read one CT block.
    for idx in range(blocks):
        _wait_until(lambda: (_status() & STS_PT_READY) != 0, 5.0, f"pt_ready block {idx}")

        blk = pt[idx * 16 : (idx + 1) * 16]
        _write_block(PT_BASE, blk)
        is_last = idx == (blocks - 1)
        ctrl = CTRL_PUSH_PT | (CTRL_PT_LAST if is_last else 0)
        aes.write(CTRL, ctrl)

        try:
            _wait_until(lambda: (_status() & STS_CT_VALID) != 0, 5.0, f"ct_valid block {idx}")
        except TimeoutError as e:
            s = _status()
            raise TimeoutError(
                f"Timeout waiting for ct_valid block {idx} (STATUS=0x{s:08x}, flags={_status_flags_text(s)})"
            ) from e

        out.extend(_read_block(CT_BASE))

    t1 = time.perf_counter()
    return bytes(out), (t1 - t0)


def _wait_tag() -> bytes:
    try:
        _wait_until(lambda: (_status() & STS_TAG_VALID) != 0, 5.0, "tag_valid")
    except TimeoutError as e:
        s = _status()
        raise TimeoutError(
            f"Timeout waiting for tag_valid (STATUS=0x{s:08x}, flags={_status_flags_text(s)})"
        ) from e
    return _read_block(TAG_BASE)


def _wait_session_cycles() -> int:
    try:
        _wait_until(
            lambda: (_status() & STS_SESSION_CYCLES_VALID) != 0,
            5.0,
            "session_cycles_valid",
        )
    except TimeoutError as e:
        s = _status()
        raise TimeoutError(
            f"Timeout waiting for session_cycles_valid (STATUS=0x{s:08x}, flags={_status_flags_text(s)})"
        ) from e
    return aes.read(CYCLES_REG)


def _read_ghash_if_valid() -> bytes:
    s = _status()
    if s & STS_GHASH_VALID:
        return _read_block(GHASH_BASE)
    return b""


def _assert_no_drops() -> None:
    s = _status()
    if s & STS_AAD_DROP:
        raise RuntimeError("aad_drop_sticky set: AAD push attempted when aad_ready=0")
    if s & STS_PT_DROP:
        raise RuntimeError("pt_drop_sticky set: PT push attempted when pt_ready=0")
    if s & STS_SESSION_DROP:
        raise RuntimeError("session_drop_sticky set: session start attempted when not ready")


def _zeroize() -> None:
    aes.write(CTRL, CTRL_ZEROIZE)


def run_gcm_encrypt_session(
    name: str,
    key: bytes,
    nonce: bytes,
    aad: bytes,
    pt: bytes,
) -> Tuple[bytes, bytes, float, int]:
    if len(aad) % 16 != 0:
        raise ValueError("AAD length must be 16-byte aligned for this RTL")
    if len(pt) % 16 != 0:
        raise ValueError("PT length must be 16-byte aligned for this RTL")

    print(f"--- {name} ---")
    print(f"  key:   {key.hex()}")
    print(f"  nonce: {nonce.hex()}")
    print(f"  aad bytes: {len(aad)}")
    print(f"  pt  bytes: {len(pt)}")

    _write_key(key)
    _write_nonce(nonce)
    _write_lengths(len(aad) * 8, len(pt) * 8)

    _load_key_and_wait()
    _start_session_and_wait_ready()

    aad_blocks = len(aad) // 16
    for i in range(aad_blocks):
        blk = aad[i * 16 : (i + 1) * 16]
        _push_aad_block(blk, is_last=(i == aad_blocks - 1))

    ct, elapsed = _stream_pt_collect_ct(pt)
    tag = _wait_tag()
    session_cycles = _wait_session_cycles()
    _ = _read_ghash_if_valid()
    _assert_no_drops()

    print(f"  ct:  {ct.hex()[:96]}{'...' if len(ct) > 48 else ''}")
    print(f"  tag: {tag.hex()}")
    print(f"  stream elapsed: {elapsed:.6f} s")
    print(f"  session cycles (PL): {session_cycles}")

    return ct, tag, elapsed, session_cycles


def software_ref_check(key: bytes, nonce: bytes, aad: bytes, pt: bytes, ct_hw: bytes, tag_hw: bytes) -> None:
    if not HAVE_AESGCM:
        print("  [warn] cryptography AESGCM not available; skipping software reference check")
        return

    aesgcm = AESGCM(key)
    ct_tag = aesgcm.encrypt(nonce, pt, aad)  # ciphertext || tag
    ct_sw, tag_sw = ct_tag[:-16], ct_tag[-16:]

    assert ct_sw == ct_hw, f"Ciphertext mismatch vs software AESGCM\nSW={ct_sw.hex()}\nHW={ct_hw.hex()}"
    assert tag_sw == tag_hw, f"Tag mismatch vs software AESGCM\nSW={tag_sw.hex()}\nHW={tag_hw.hex()}"

    # Decrypt in software as a sanity check (PL is encrypt-path only for now).
    pt_back = aesgcm.decrypt(nonce, ct_hw + tag_hw, aad)
    assert pt_back == pt, "Software decrypt of HW output failed"


def run() -> None:
    print("=" * 64)
    print("AES-256 GCM PL Test")
    print("=" * 64)
    print("PL datapath mode: encrypt-path only (CTR encrypt + GHASH over ciphertext)")
    if HAVE_AESGCM:
        print("Software reference: cryptography AESGCM available")
    else:
        print("Software reference: unavailable (install python3-cryptography to enable)")
    print()

    # -----------------------------------------------------------------
    # Test 1: Functional correctness (aligned data)
    # -----------------------------------------------------------------
    key = bytes.fromhex(
        "603deb1015ca71be2b73aef0857d7781"
        "1f352c073b6108d72d9810a30914dff4"
    )
    nonce = bytes.fromhex("f0f1f2f3f4f5f6f7f8f9fafb")
    aad = bytes.fromhex(
        "feedfacedeadbeeffeedfacedeadbeef"
        "abaddad2000000000000000000000001"
    )
    pt = bytes.fromhex(
        "6bc1bee22e409f96e93d7e117393172a"
        "ae2d8a571e03ac9c9eb76fac45af8e51"
        "30c81c46a35ce411e5fbc1191a0a52ef"
        "f69f2445df4f9b17ad2b417be66c3710"
    )

    ct_hw, tag_hw, _, cyc1 = run_gcm_encrypt_session("Functional 4-block", key, nonce, aad, pt)
    software_ref_check(key, nonce, aad, pt, ct_hw, tag_hw)
    print(f"  Functional session cycles: {cyc1}")
    print("  Functional test: PASS\n")

    # -----------------------------------------------------------------
    # Test 2: Big streaming stress / throughput
    # -----------------------------------------------------------------
    big_blocks = 4096  # 4096 * 16 = 65536 bytes
    key2 = os.urandom(32)
    nonce2 = os.urandom(12)
    aad2 = os.urandom(16)  # one aligned AAD block
    pt2 = os.urandom(big_blocks * 16)

    ct2, tag2, elapsed, cycles2 = run_gcm_encrypt_session(
        f"Streaming stress ({big_blocks} blocks)", key2, nonce2, aad2, pt2
    )

    # Optional software verification for the large run.
    software_ref_check(key2, nonce2, aad2, pt2, ct2, tag2)

    bytes_total = len(pt2)
    mbps = (bytes_total / elapsed) / (1024 * 1024)

    if cycles2 == 0:
        raise RuntimeError("Session cycle counter returned 0; invalid hardware timing result")

    core_clk_hz = 100_000_000.0
    core_elapsed = cycles2 / core_clk_hz
    core_mib_s_measured = (bytes_total / core_elapsed) / (1024 * 1024)
    cycles_per_block = cycles2 / big_blocks

    # Theoretical core max at 100 MHz for 128-bit/cycle payload path:
    #   16 bytes/cycle * 100e6 cycles/s = 1.6e9 bytes/s = ~1525.9 MiB/s
    core_theoretical_mib_s = (16.0 * 100_000_000.0) / (1024.0 * 1024.0)

    print("  Streaming test: PASS")
    print(f"  Effective SW-driven throughput: {mbps:.2f} MiB/s")
    print(f"  PL-cycle measured throughput: {core_mib_s_measured:.2f} MiB/s")
    print(f"  PL cycles/block (session average): {cycles_per_block:.3f}")
    print(f"  Theoretical core throughput @100MHz: {core_theoretical_mib_s:.2f} MiB/s")
    print("  Note: measured throughput is AXI-Lite + Python limited, not PL datapath-limited.\n")

    # -----------------------------------------------------------------
    # Cleanup
    # -----------------------------------------------------------------
    print("--- Zeroize ---")
    _zeroize()
    s = _status()
    assert (s & STS_KEYS_READY_MASK) == 0, f"keys_ready not cleared after zeroize: {s:#x}"
    print("  keys_ready cleared: OK")

    print()
    print("=" * 64)
    print("ALL TESTS PASSED - AES-256 GCM core is operational on FPGA")
    print("=" * 64)


if __name__ == "__main__":
    run()
