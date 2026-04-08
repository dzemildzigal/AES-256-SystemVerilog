"""
AES-256 Encrypt→Decrypt Loopback Test for PYNQ Z2.

Uses the pipelined AXI_AES_Roundtrip overlay:
  TopRoundtrip → EncryptPipelined → DecryptPipelined

Register map (AXI_AES_Roundtrip):
  CTRL=0x00(W)   [0]=go, [1]=load_key
  STATUS=0x04(R) [3:0]=keys_ready, [4]=ct_valid, [5]=result_valid, [6]=match
  KEY0-KEY7=0x08-0x24(R/W)  256-bit key (8 x 32-bit words)
  PT0-PT3=0x28-0x34(R/W)    128-bit plaintext (4 x 32-bit words)
  CT0-CT3=0x38-0x44(R)      128-bit ciphertext
  RES0-RES3=0x48-0x54(R)    128-bit result (decrypted)

Usage:
    1. Build the bitstream in Vivado: source pynq/build_bd.tcl
    2. Copy aes_roundtrip_wrapper.bit + aes_roundtrip_wrapper.hwh to the PYNQ board
    3. Run: python3 test_aes.py
"""

from pynq import Overlay
import os

# ── Register map ─────────────────────────────────────────────
BITSTREAM   = "aes_roundtrip_wrapper.bit"
IP_NAME     = "aes_roundtrip_0"
CTRL        = 0x00
STATUS      = 0x04
KEY_BASE    = 0x08
PLAIN_BASE  = 0x28
CIPHER_BASE = 0x38
RESULT_BASE = 0x48

# ── Load overlay ─────────────────────────────────────────────
print(f"Loading overlay: {BITSTREAM}")
ol = Overlay(BITSTREAM)
aes = getattr(ol, IP_NAME)


def write_key(key_bytes: bytes):
    """Write 32-byte (256-bit) AES key to registers."""
    assert len(key_bytes) == 32, f"Key must be 32 bytes, got {len(key_bytes)}"
    for i in range(8):
        word = int.from_bytes(key_bytes[i*4:(i+1)*4], byteorder='big')
        aes.write(KEY_BASE + i * 4, word)


def load_key():
    """Trigger key expansion and wait for completion."""
    aes.write(CTRL, 0x02)  # bit1 = load_key
    timeout = 1000
    while (aes.read(STATUS) & 0x0F) != 15:  # keys_ready[3:0] == 15
        timeout -= 1
        if timeout == 0:
            raise TimeoutError("Key expansion did not complete")


def write_plaintext(pt_bytes: bytes):
    """Write 16-byte (128-bit) plaintext to registers."""
    assert len(pt_bytes) == 16, f"Plaintext must be 16 bytes, got {len(pt_bytes)}"
    for i in range(4):
        word = int.from_bytes(pt_bytes[i*4:(i+1)*4], byteorder='big')
        aes.write(PLAIN_BASE + i * 4, word)


def start_and_wait():
    """Start encrypt→decrypt loopback and wait for result."""
    aes.write(CTRL, 0x01)  # bit0 = start
    timeout = 1000
    while not (aes.read(STATUS) & 0x20):  # bit5 = result_valid
        timeout -= 1
        if timeout == 0:
            raise TimeoutError("Encrypt/decrypt did not complete")


def read_result() -> bytes:
    """Read 16-byte decrypt output (loopback result)."""
    result = b''
    for i in range(4):
        word = aes.read(RESULT_BASE + i * 4)
        result += word.to_bytes(4, byteorder='big')
    return result


def read_ciphertext() -> bytes:
    """Read 16-byte intermediate ciphertext (encrypt output)."""
    ct = b''
    for i in range(4):
        word = aes.read(CIPHER_BASE + i * 4)
        ct += word.to_bytes(4, byteorder='big')
    return ct


def run_test(name: str, key: bytes, plaintext: bytes,
             expected_ct: bytes = None):
    """Run one encrypt→decrypt loopback test."""
    print(f"--- {name} ---")
    print(f"  Key:       {key.hex()}")
    print(f"  Plaintext: {plaintext.hex()}")

    write_key(key)
    load_key()
    write_plaintext(plaintext)
    start_and_wait()

    ct = read_ciphertext()
    result = read_result()

    print(f"  Cipher:    {ct.hex()}")
    print(f"  Result:    {result.hex()}")

    # Loopback check: decrypt(encrypt(pt)) must equal pt
    assert result == plaintext, \
        f"LOOPBACK FAIL: expected {plaintext.hex()}, got {result.hex()}"

    # Check the hardware match flag
    match = (aes.read(STATUS) >> 6) & 1
    assert match == 1, "MATCH FLAG FAIL: hardware reports mismatch"
    print("  Match flag: OK")

    # Optional: verify ciphertext matches known value
    if expected_ct is not None:
        assert ct == expected_ct, \
            f"CIPHERTEXT MISMATCH: expected {expected_ct.hex()}, got {ct.hex()}"

    print("  PASS\n")


# ══════════════════════════════════════════════════════════════
#  Test vectors
# ══════════════════════════════════════════════════════════════
print("=" * 50)
print("AES-256 Encrypt -> Decrypt Loopback Test")
print("=" * 50 + "\n")

# Test 1: All-zero key, all-zero plaintext
run_test(
    "All zeros",
    key       = bytes(32),
    plaintext = bytes(16),
    expected_ct = bytes.fromhex("dc95c078a2408989ad48a21492842087"),
)

# Test 2: NIST key, all-zero plaintext
run_test(
    "NIST key, zero plaintext",
    key       = bytes.fromhex("000102030405060708090a0b0c0d0e0f"
                              "101112131415161718191a1b1c1d1e1f"),
    plaintext = bytes(16),
    expected_ct = bytes.fromhex("f29000b62a499fd0a9f39a6add2e7780"),
)

# Test 3: NIST key, NIST plaintext
run_test(
    "NIST key + plaintext",
    key       = bytes.fromhex("000102030405060708090a0b0c0d0e0f"
                              "101112131415161718191a1b1c1d1e1f"),
    plaintext = bytes.fromhex("00112233445566778899aabbccddeeff"),
    expected_ct = bytes.fromhex("8ea2b7ca516745bfeafc49904b496089"),
)

# Test 4: Random key + plaintext (loopback only, no known CT)
random_key = os.urandom(32)
random_pt  = os.urandom(16)
run_test(
    "Random data",
    key       = random_key,
    plaintext = random_pt,
)

print("=" * 50)
print("ALL TESTS PASSED — AES-256 is working on FPGA!")
print("=" * 50)
