"""
AES-256 GCM DMA test for PYNQ Z2 (AXI_AES_GCM_Stream + AXI DMA).

Usage:
  1) Build/load a bitstream containing aes_gcm_dma_wrapper with aes_gcm_0 and axi_dma_0
  2) Copy aes_gcm_dma_wrapper.bit + aes_gcm_dma_wrapper.hwh + this script to PYNQ
  3) Run: sudo python3 test_aes_gcm_dma.py
"""

from __future__ import annotations

import importlib
import os
import time
from typing import Callable, Tuple

from pynq import Overlay, allocate

# Optional software reference (recommended)
AESGCM = None
try:
    _aead_mod = importlib.import_module("cryptography.hazmat.primitives.ciphers.aead")
    AESGCM = getattr(_aead_mod, "AESGCM")
    HAVE_AESGCM = True
except Exception:
    HAVE_AESGCM = False


TRANSFORM_MATCH_NOTE = ""


# -----------------------------------------------------------------------------
# Register map
# -----------------------------------------------------------------------------
BITSTREAM = "aes_gcm_dma_wrapper.bit"
IP_NAME = "aes_gcm_0"
DMA_NAME = "axi_dma_0"

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
STREAM_CYCLES_REG = 0x9C

# CTRL bits
CTRL_PUSH_PT = 1 << 0
CTRL_LOAD_KEY = 1 << 1
CTRL_START_SESSION = 1 << 2
CTRL_PUSH_AAD = 1 << 3
CTRL_AAD_LAST = 1 << 4
CTRL_PT_LAST = 1 << 5
CTRL_ZEROIZE = 1 << 6
CTRL_SET_STREAM = 1 << 7
CTRL_CLEAR_STREAM = 1 << 8

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
STS_STREAM_MODE = 1 << 17
STS_CT_FIFO_OVERFLOW = 1 << 18

print(f"Loading overlay: {BITSTREAM}")
ol = Overlay(BITSTREAM)
aes = getattr(ol, IP_NAME)
dma = getattr(ol, DMA_NAME)


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
    if s & STS_STREAM_MODE:
        flags.append("stream_mode")
    if s & STS_CT_FIFO_OVERFLOW:
        flags.append("ct_fifo_overflow")
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


def _reverse_bytes_per_128b_block(data: bytes) -> bytes:
    if len(data) % 16 != 0:
        raise ValueError(f"Length must be a multiple of 16 bytes, got {len(data)}")
    return b"".join(data[i : i + 16][::-1] for i in range(0, len(data), 16))


def _reverse_words_per_128b_block(data: bytes) -> bytes:
    if len(data) % 16 != 0:
        raise ValueError(f"Length must be a multiple of 16 bytes, got {len(data)}")
    out = []
    for i in range(0, len(data), 16):
        b = data[i : i + 16]
        out.append(b[12:16] + b[8:12] + b[4:8] + b[0:4])
    return b"".join(out)


def _byteswap_each_32b_word(data: bytes) -> bytes:
    if len(data) % 4 != 0:
        raise ValueError(f"Length must be a multiple of 4 bytes, got {len(data)}")
    return b"".join(data[i : i + 4][::-1] for i in range(0, len(data), 4))


def _swap_64b_halves_per_128b_block(data: bytes) -> bytes:
    if len(data) % 16 != 0:
        raise ValueError(f"Length must be a multiple of 16 bytes, got {len(data)}")
    out = []
    for i in range(0, len(data), 16):
        b = data[i : i + 16]
        out.append(b[8:16] + b[0:8])
    return b"".join(out)


def _composed_xfm(f, g):
    return lambda d: g(f(d))


def _get_transform_map():
    return {
        "id": lambda d: d,
        "rev16": _reverse_bytes_per_128b_block,
        "rev_words16": _reverse_words_per_128b_block,
        "bswap32": _byteswap_each_32b_word,
        "swap64": _swap_64b_halves_per_128b_block,
        "rev_words16+bswap32": _composed_xfm(_reverse_words_per_128b_block, _byteswap_each_32b_word),
        "bswap32+rev_words16": _composed_xfm(_byteswap_each_32b_word, _reverse_words_per_128b_block),
    }


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


def _set_stream_mode(enable: bool) -> None:
    aes.write(CTRL, CTRL_SET_STREAM if enable else CTRL_CLEAR_STREAM)
    if enable:
        _wait_until(lambda: (_status() & STS_STREAM_MODE) != 0, 1.0, "stream_mode=1")
    else:
        _wait_until(lambda: (_status() & STS_STREAM_MODE) == 0, 1.0, "stream_mode=0")


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


def _stream_pt_collect_ct_dma(pt: bytes) -> Tuple[bytes, float]:
    if len(pt) % 16 != 0:
        raise ValueError("Plaintext length must be 16-byte aligned")

    tx = allocate(shape=(len(pt),), dtype="u1")
    rx = allocate(shape=(len(pt),), dtype="u1")
    try:
        tx[:] = bytearray(pt)
        tx.flush()

        t0 = time.perf_counter()
        dma.recvchannel.transfer(rx)
        dma.sendchannel.transfer(tx)
        dma.sendchannel.wait()
        dma.recvchannel.wait()
        t1 = time.perf_counter()

        rx.invalidate()
        return bytes(rx), (t1 - t0)
    finally:
        tx.freebuffer()
        rx.freebuffer()


def _dma_max_transfer_bytes() -> int:
    tx_max = int(getattr(dma.sendchannel, "_max_size", 0))
    rx_max = int(getattr(dma.recvchannel, "_max_size", 0))
    candidates = [v for v in (tx_max, rx_max) if v > 0]
    if not candidates:
        return 0
    return min(candidates)


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
        raise RuntimeError("pt_drop_sticky set: PT path rejected data")
    if s & STS_SESSION_DROP:
        raise RuntimeError("session_drop_sticky set: session start attempted when not ready")
    if s & STS_CT_FIFO_OVERFLOW:
        raise RuntimeError("ct_fifo_overflow set: CT stream path overflowed")


def _zeroize() -> None:
    aes.write(CTRL, CTRL_ZEROIZE)


def run_gcm_encrypt_session(
    name: str,
    key: bytes,
    nonce: bytes,
    aad: bytes,
    pt: bytes,
) -> Tuple[bytes, bytes, float, float, int, int]:
    if len(aad) % 16 != 0:
        raise ValueError("AAD length must be 16-byte aligned for this RTL")
    if len(pt) % 16 != 0:
        raise ValueError("PT length must be 16-byte aligned for this RTL")

    print(f"--- {name} ---")
    print(f"  key:   {key.hex()}")
    print(f"  nonce: {nonce.hex()}")
    print(f"  aad bytes: {len(aad)}")
    print(f"  pt  bytes: {len(pt)}")

    session_host_t0 = time.perf_counter()

    _write_key(key)
    _write_nonce(nonce)
    _write_lengths(len(aad) * 8, len(pt) * 8)
    _set_stream_mode(True)

    _load_key_and_wait()
    _start_session_and_wait_ready()

    aad_blocks = len(aad) // 16
    for i in range(aad_blocks):
        blk = aad[i * 16 : (i + 1) * 16]
        _push_aad_block(blk, is_last=(i == aad_blocks - 1))

    ct, elapsed = _stream_pt_collect_ct_dma(pt)
    tag = _wait_tag()
    session_cycles = _wait_session_cycles()
    stream_cycles = aes.read(STREAM_CYCLES_REG)
    _ = _read_ghash_if_valid()
    _assert_no_drops()
    session_host_elapsed = time.perf_counter() - session_host_t0

    print(f"  ct:  {ct.hex()[:96]}{'...' if len(ct) > 48 else ''}")
    print(f"  tag: {tag.hex()}")
    print(f"  dma elapsed: {elapsed:.6f} s")
    print(f"  host session elapsed: {session_host_elapsed:.6f} s")
    print(f"  session cycles (PL): {session_cycles}")
    print(f"  stream cycles  (PL): {stream_cycles}")

    return ct, tag, elapsed, session_host_elapsed, session_cycles, stream_cycles


def software_ref_check(key: bytes, nonce: bytes, aad: bytes, pt: bytes, ct_hw: bytes, tag_hw: bytes) -> None:
    global TRANSFORM_MATCH_NOTE
    TRANSFORM_MATCH_NOTE = ""

    if not HAVE_AESGCM:
        print("  [warn] cryptography AESGCM not available; skipping software reference check")
        return

    aesgcm = AESGCM(key)
    ct_tag = aesgcm.encrypt(nonce, pt, aad)  # ciphertext || tag
    ct_sw, tag_sw = ct_tag[:-16], ct_tag[-16:]

    if ct_sw == ct_hw and tag_sw == tag_hw:
        pt_back = aesgcm.decrypt(nonce, ct_hw + tag_hw, aad)
        assert pt_back == pt, "Software decrypt of HW output failed"
        return

    # Diagnostic-only hypothesis check: common 128-bit byte reversal case.
    ct_hw_rev = _reverse_bytes_per_128b_block(ct_hw)
    tag_hw_rev = _reverse_bytes_per_128b_block(tag_hw)
    if ct_sw == ct_hw_rev and tag_sw == tag_hw_rev:
        TRANSFORM_MATCH_NOTE = "out=rev16, tag=rev16"
        print("  [debug] Direct HW output mismatches SW, but 128-bit byte reversal matches.")
        print("  [debug] This confirms stream byte-order mismatch hypothesis.")

    if not TRANSFORM_MATCH_NOTE:
        # Broader diagnostic sweep for common AXI lane/order mismatches.
        xfm = _get_transform_map()
        found_diag = False
        for in_name, in_fn in xfm.items():
            ct_tag_i = aesgcm.encrypt(nonce, in_fn(pt), aad)
            ct_sw_i, tag_sw_i = ct_tag_i[:-16], ct_tag_i[-16:]

            for out_name, out_fn in xfm.items():
                if ct_sw_i == out_fn(ct_hw) and tag_sw_i == tag_hw:
                    TRANSFORM_MATCH_NOTE = f"in={in_name}, out={out_name}, tag=id"
                    found_diag = True
                    break

                if ct_sw_i == out_fn(ct_hw) and tag_sw_i == out_fn(tag_hw):
                    TRANSFORM_MATCH_NOTE = f"in={in_name}, out={out_name}, tag={out_name}"
                    found_diag = True
                    break

            if found_diag:
                break

        if TRANSFORM_MATCH_NOTE:
            print("  [debug] Direct HW output mismatches SW, but transform pair matches.")
            print(f"  [debug] Matched transform: {TRANSFORM_MATCH_NOTE}")

    detail = f" Diagnostic transform hint: {TRANSFORM_MATCH_NOTE}." if TRANSFORM_MATCH_NOTE else ""
    raise AssertionError(f"Native ciphertext/tag mismatch vs software AESGCM.{detail}")


def run() -> None:
    print("=" * 64)
    print("AES-256 GCM DMA Test")
    print("=" * 64)
    print("PL datapath mode: encrypt-path only (CTR encrypt + GHASH over ciphertext)")
    if HAVE_AESGCM:
        print("Software reference: cryptography AESGCM available")
    else:
        print("Software reference: unavailable (install python3-cryptography to enable)")
    print()

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

    ct_hw, tag_hw, _, host_elapsed1, cyc1, stream_cyc1 = run_gcm_encrypt_session("Functional 4-block", key, nonce, aad, pt)
    software_ref_check(key, nonce, aad, pt, ct_hw, tag_hw)
    print(f"  Functional host session elapsed: {host_elapsed1:.6f} s")
    print(f"  Functional session cycles: {cyc1}")
    print(f"  Functional stream cycles:  {stream_cyc1}")
    print("  Functional test: PASS\n")

    target_big_blocks = 4096  # 4096 * 16 = 65536 bytes
    dma_max_bytes = _dma_max_transfer_bytes()
    if dma_max_bytes > 0:
        max_blocks = dma_max_bytes // 16
        if max_blocks <= 0:
            raise RuntimeError(f"DMA max transfer size too small for one AES block: {dma_max_bytes} bytes")
        big_blocks = min(target_big_blocks, max_blocks)
        if big_blocks < target_big_blocks:
            print(
                f"  [note] Limiting stress test to {big_blocks} blocks ({big_blocks * 16} bytes) "
                f"due to DMA max transfer size {dma_max_bytes} bytes"
            )
    else:
        big_blocks = target_big_blocks

    key2 = os.urandom(32)
    nonce2 = os.urandom(12)
    aad2 = os.urandom(16)
    pt2 = os.urandom(big_blocks * 16)

    ct2, tag2, dma_elapsed, host_session_elapsed, cycles2, stream_cycles2 = run_gcm_encrypt_session(
        f"Streaming stress DMA ({big_blocks} blocks)", key2, nonce2, aad2, pt2
    )

    software_ref_check(key2, nonce2, aad2, pt2, ct2, tag2)

    bytes_total = len(pt2)
    host_mib_s = (bytes_total / dma_elapsed) / (1024 * 1024)
    host_full_mib_s = (bytes_total / host_session_elapsed) / (1024 * 1024)

    if cycles2 == 0:
        raise RuntimeError("Session cycle counter returned 0; invalid hardware timing result")

    core_clk_hz = 100_000_000.0
    session_elapsed = cycles2 / core_clk_hz
    core_mib_s_session = (bytes_total / session_elapsed) / (1024 * 1024)
    session_cycles_per_block = cycles2 / big_blocks

    core_mib_s_stream = None
    stream_cycles_per_block = None
    stream_elapsed = None
    if stream_cycles2 > 0:
        stream_elapsed = stream_cycles2 / core_clk_hz
        core_mib_s_stream = (bytes_total / stream_elapsed) / (1024 * 1024)
        stream_cycles_per_block = stream_cycles2 / big_blocks

    core_theoretical_mib_s = (16.0 * 100_000_000.0) / (1024.0 * 1024.0)

    print("  Streaming DMA test: PASS")
    print(f"  Effective host+DMA throughput: {host_mib_s:.2f} MiB/s")
    print(f"  Effective end-to-end throughput (full host session): {host_full_mib_s:.2f} MiB/s")
    print(f"  PL-cycle throughput (session window): {core_mib_s_session:.2f} MiB/s")
    print(f"  Session cycles/block (session start -> tag): {session_cycles_per_block:.3f}")
    if core_mib_s_stream is not None and stream_cycles_per_block is not None:
        print(f"  PL-cycle throughput (true stream window): {core_mib_s_stream:.2f} MiB/s")
        print(f"  Stream cycles/block (first PT beat -> tag): {stream_cycles_per_block:.3f}")

        if stream_elapsed is not None and host_session_elapsed >= session_elapsed:
            host_overhead_s = host_session_elapsed - session_elapsed
            session_overhead_s = max(session_elapsed - stream_elapsed, 0.0)
            pure_stream_s = min(stream_elapsed, session_elapsed)

            host_overhead_pct = (host_overhead_s / host_session_elapsed) * 100.0
            session_overhead_pct = (session_overhead_s / host_session_elapsed) * 100.0
            pure_stream_pct = (pure_stream_s / host_session_elapsed) * 100.0
            stream_share_session_pct = (pure_stream_s / session_elapsed) * 100.0 if session_elapsed > 0 else 0.0

            print("  Overhead split (of full host session wall time):")
            print(f"    Host orchestration outside PL session: {host_overhead_s * 1e3:.3f} ms ({host_overhead_pct:.2f}%)")
            print(f"    PL session overhead outside stream window: {session_overhead_s * 1e3:.3f} ms ({session_overhead_pct:.2f}%)")
            print(f"    Pure stream datapath window: {pure_stream_s * 1e3:.3f} ms ({pure_stream_pct:.2f}%)")
            print(f"  Stream share inside PL session window: {stream_share_session_pct:.2f}%")
        else:
            print("  [warn] Could not compute additive overhead split from current timing windows")
    else:
        print("  [warn] STREAM_CYCLES register returned 0; true stream-window metric unavailable")
    print(f"  Theoretical core throughput @100MHz: {core_theoretical_mib_s:.2f} MiB/s")
    print()

    print("--- Zeroize ---")
    _zeroize()
    s = _status()
    assert (s & STS_KEYS_READY_MASK) == 0, f"keys_ready not cleared after zeroize: {s:#x}"
    print("  keys_ready cleared: OK")

    print()
    print("=" * 64)
    print("ALL TESTS PASSED - native byte order correct; AES-256 GCM DMA path is operational on FPGA")
    print("=" * 64)


if __name__ == "__main__":
    run()
