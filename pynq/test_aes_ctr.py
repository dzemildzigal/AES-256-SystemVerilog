"""
AES-256 CTR Mode Test for PYNQ Z2.

Uses AXI_AES_CTR overlay with EncryptPipelined-based CTR mode.
Same operation for encrypt and decrypt (XOR with keystream).

Register map (AXI_AES_CTR):
  CTRL=0x00(W)   [0]=go, [1]=load_key, [2]=load_ctr, [3]=zeroize
  STATUS=0x04(R) [3:0]=keys_ready, [4]=out_valid (sticky)
  KEY0-KEY7=0x08-0x24(R/W)    256-bit key
  NONCE0-NONCE2=0x28-0x30(R/W) 96-bit nonce
  CTR=0x34(R/W)                32-bit counter (auto-increments)
  DIN0-DIN3=0x38-0x44(R/W)    128-bit data input
  DOUT0-DOUT3=0x48-0x54(R)    128-bit data output

Usage:
    1. Build bitstream: source pynq/build_bd_ctr.tcl
    2. Copy aes_ctr_wrapper.bit + aes_ctr_wrapper.hwh to PYNQ
    3. Run: sudo python3 test_aes_ctr.py
"""

from pynq import Overlay
import os
import struct

# ── Register map ─────────────────────────────────────────────
BITSTREAM   = "aes_ctr_wrapper.bit"
IP_NAME     = "aes_ctr_0"
CTRL        = 0x00
STATUS      = 0x04
KEY_BASE    = 0x08
NONCE_BASE  = 0x28
CTR_REG     = 0x34
DIN_BASE    = 0x38
DOUT_BASE   = 0x48

# ── Load overlay ─────────────────────────────────────────────
print(f"Loading overlay: {BITSTREAM}")
ol = Overlay(BITSTREAM)
aes = getattr(ol, IP_NAME)


def write_key(key_bytes: bytes):
    assert len(key_bytes) == 32
    for i in range(8):
        word = int.from_bytes(key_bytes[i*4:(i+1)*4], byteorder='big')
        aes.write(KEY_BASE + i * 4, word)


def load_key():
    aes.write(CTRL, 0x02)  # bit1 = load_key
    timeout = 10000
    while (aes.read(STATUS) & 0x0F) != 15:
        timeout -= 1
        if timeout == 0:
            raise TimeoutError("Key expansion did not complete")


def write_nonce(nonce_bytes: bytes):
    assert len(nonce_bytes) == 12
    for i in range(3):
        word = int.from_bytes(nonce_bytes[i*4:(i+1)*4], byteorder='big')
        aes.write(NONCE_BASE + i * 4, word)


def load_counter(ctr_value: int):
    aes.write(CTR_REG, ctr_value & 0xFFFFFFFF)
    aes.write(CTRL, 0x04)  # bit2 = load_ctr


def write_data_in(data_bytes: bytes):
    assert len(data_bytes) == 16
    for i in range(4):
        word = int.from_bytes(data_bytes[i*4:(i+1)*4], byteorder='big')
        aes.write(DIN_BASE + i * 4, word)


def go_and_wait():
    aes.write(CTRL, 0x01)  # bit0 = go
    timeout = 10000
    while not (aes.read(STATUS) & 0x10):  # bit4 = out_valid sticky
        timeout -= 1
        if timeout == 0:
            raise TimeoutError("CTR operation did not complete")


def read_data_out() -> bytes:
    result = b''
    for i in range(4):
        word = aes.read(DOUT_BASE + i * 4)
        result += word.to_bytes(4, byteorder='big')
    return result


def read_counter() -> int:
    return aes.read(CTR_REG)


def zeroize():
    aes.write(CTRL, 0x08)  # bit3 = zeroize


def ctr_process_block(data_bytes: bytes) -> bytes:
    """Process one 16-byte block (encrypt or decrypt — same operation)."""
    write_data_in(data_bytes)
    go_and_wait()
    return read_data_out()


def run_test(name: str, key: bytes, nonce: bytes, counter: int,
             plaintext: bytes, expected_ct: bytes = None):
    """Run one CTR mode test: encrypt then decrypt and verify roundtrip."""
    print(f"--- {name} ---")
    print(f"  Key:     {key.hex()}")
    print(f"  Nonce:   {nonce.hex()}")
    print(f"  Counter: 0x{counter:08x}")

    # Setup
    write_key(key)
    load_key()
    write_nonce(nonce)

    # ── Encrypt ──────────────────────────────────────────
    load_counter(counter)
    ct_blocks = b''
    for i in range(0, len(plaintext), 16):
        block = plaintext[i:i+16]
        ct_block = ctr_process_block(block)
        ct_blocks += ct_block

    print(f"  PT:      {plaintext.hex()}")
    print(f"  CT:      {ct_blocks.hex()}")

    if expected_ct is not None:
        assert ct_blocks == expected_ct, \
            f"CT MISMATCH: expected {expected_ct.hex()}, got {ct_blocks.hex()}"

    # ── Decrypt (same operation, reload counter) ─────────
    load_counter(counter)
    pt_back = b''
    for i in range(0, len(ct_blocks), 16):
        block = ct_blocks[i:i+16]
        pt_block = ctr_process_block(block)
        pt_back += pt_block

    assert pt_back == plaintext, \
        f"ROUNDTRIP FAIL: expected {plaintext.hex()}, got {pt_back.hex()}"

    print(f"  Decrypt: {pt_back.hex()}")
    print("  PASS\n")


# ══════════════════════════════════════════════════════════════
#  Test vectors — NIST SP 800-38A, Section F.5.5 / F.5.6
# ══════════════════════════════════════════════════════════════
print("=" * 50)
print("AES-256 CTR Mode Test")
print("=" * 50 + "\n")

NIST_KEY   = bytes.fromhex("603deb1015ca71be2b73aef0857d7781"
                           "1f352c073b6108d72d9810a30914dff4")
NIST_NONCE = bytes.fromhex("f0f1f2f3f4f5f6f7f8f9fafb")
NIST_CTR   = 0xfcfdfeff

# NIST test: 4 blocks
nist_pt = bytes.fromhex(
    "6bc1bee22e409f96e93d7e117393172a"
    "ae2d8a571e03ac9c9eb76fac45af8e51"
    "30c81c46a35ce411e5fbc1191a0a52ef"
    "f69f2445df4f9b17ad2b417be66c3710"
)
nist_ct = bytes.fromhex(
    "601ec313775789a5b7a7f504bbf3d228"
    "f443e3ca4d62b59aca84e990cacaf5c5"
    "2b0930daa23de94ce87017ba2d84988d"
    "dfc9c58db67aada613c2dd08457941a6"
)

# Test 1: NIST single block
run_test(
    "NIST F.5.5 block 0",
    key       = NIST_KEY,
    nonce     = NIST_NONCE,
    counter   = NIST_CTR,
    plaintext = nist_pt[:16],
    expected_ct = nist_ct[:16],
)

# Test 2: NIST all 4 blocks
run_test(
    "NIST F.5.5 all 4 blocks",
    key       = NIST_KEY,
    nonce     = NIST_NONCE,
    counter   = NIST_CTR,
    plaintext = nist_pt,
    expected_ct = nist_ct,
)

# Test 3: Random key, random data — roundtrip only
run_test(
    "Random data roundtrip",
    key       = os.urandom(32),
    nonce     = os.urandom(12),
    counter   = 0x00000001,
    plaintext = os.urandom(64),  # 4 blocks
)

# Test 4: Zeroize
print("--- Zeroize ---")
zeroize()
status = aes.read(STATUS)
assert (status & 0x0F) == 0, f"keys_ready not cleared after zeroize: {status:#x}"
print("  keys_ready cleared: OK")
print("  PASS\n")

print("=" * 50)
print("ALL TESTS PASSED - AES-256 CTR mode is working on FPGA!")
print("=" * 50)
