"""
Ping-pong DDR ciphertext -> PS decrypt -> HDMI out integration test.

Flow:
  plaintext source (synthetic or HDMI capture)
    -> DMA MM2S
    -> AXI_AES_GCM_Stream encrypt
    -> AXI_PingPong_Ctrl writer to DDR ciphertext buffer
    -> PS AES-GCM decrypt
    -> optional HDMI out render

Usage examples:
  python3 -u test_ping_pong_ps_decrypt_hdmi_out.py
  python3 -u test_ping_pong_ps_decrypt_hdmi_out.py --input-source hdmi --render-hdmi
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
import time

import numpy as np
from pynq import Overlay, allocate

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM  # type: ignore
except Exception as exc:
    raise RuntimeError("cryptography package is required for PS decrypt test") from exc

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

KEY = bytes.fromhex(
    "603deb1015ca71be2b73aef0857d7781"
    "1f352c073b6108d72d9810a30914dff4"
)
NONCE = bytes.fromhex("f0f1f2f3f4f5f6f7f8f9fafb")
AAD = bytes.fromhex(
    "feedfacedeadbeeffeedfacedeadbeef"
    "abaddad2000000000000000000000001"
)


def log(msg: str) -> None:
    print(msg, flush=True)


def wait_until(cond, timeout_s: float, what: str) -> None:
    t0 = time.perf_counter()
    while not cond():
        if (time.perf_counter() - t0) > timeout_s:
            raise TimeoutError(f"Timeout waiting for {what}")


def wait_dma_send_done(dma, timeout_s: float) -> None:
    wait_until(lambda: dma.sendchannel.idle, timeout_s, "dma mm2s done")


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


def pixel_bytes(pixel_format: str) -> int:
    pf = pixel_format.upper()
    if "RGB" in pf:
        return 3
    if "YUV" in pf:
        return 2
    return 1


def synthetic_payload(frame_bytes: int) -> bytes:
    # Deterministic but non-constant frame content.
    return bytes((i & 0xFF) for i in range(frame_bytes))


def import_runtime_modules() -> None:
    runtime_dir = Path(__file__).resolve().parents[2] / "OS-VideoSDR" / "pynq" / "runtime"
    if str(runtime_dir) not in sys.path:
        sys.path.insert(0, str(runtime_dir))


def capture_payload_from_hdmi(width: int, height: int, fps: int, pixel_format: str, hdmi_bitstream: str) -> bytes:
    import_runtime_modules()
    from hdmi_capture import HdmiCapture, HdmiCaptureConfig

    capture = HdmiCapture(
        HdmiCaptureConfig(
            width=width,
            height=height,
            fps=fps,
            pixel_format=pixel_format,
            bitstream_path=hdmi_bitstream or None,
        )
    )
    try:
        frame = next(capture.frames())
        return frame
    finally:
        capture.close()


def render_payload_to_hdmi(payload: bytes, width: int, height: int, fps: int, pixel_format: str, hdmi_bitstream: str) -> None:
    import_runtime_modules()
    from hdmi_output import HdmiOutput, HdmiOutputConfig

    sink = HdmiOutput(
        HdmiOutputConfig(
            width=width,
            height=height,
            fps=fps,
            pixel_format=pixel_format,
            bitstream_path=hdmi_bitstream or None,
        )
    )
    try:
        sink.render_frame(payload)
    finally:
        sink.close()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Ping-pong PS decrypt -> HDMI out test")
    parser.add_argument("--bitstream", default="aes_gcm_ping_pong_wrapper.bit")
    parser.add_argument("--pp-ip", default="aes_pingpong_0")
    parser.add_argument("--aes-ip", default="aes_gcm_0")
    parser.add_argument("--dma-ip", default="axi_dma_0")
    parser.add_argument("--input-source", choices=["synthetic", "hdmi"], default="synthetic")
    parser.add_argument("--frame-bytes", type=int, default=120000)
    parser.add_argument("--width", type=int, default=1920)
    parser.add_argument("--height", type=int, default=1080)
    parser.add_argument("--fps", type=int, default=10)
    parser.add_argument("--pixel-format", default="RGB888")
    parser.add_argument("--render-hdmi", action="store_true")
    parser.add_argument("--hdmi-bitstream", default="")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    log(f"Loading overlay: {args.bitstream}")
    ol = Overlay(args.bitstream)
    pp = getattr(ol, args.pp_ip)
    aes = getattr(ol, args.aes_ip)
    dma = getattr(ol, args.dma_ip)

    pp_version = pp.read(PP_REG_VERSION)
    log(f"PP VERSION = 0x{pp_version:08x}")
    if pp_version != PP_VERSION_EXPECTED:
        raise RuntimeError(f"Unexpected ping-pong VERSION value: 0x{pp_version:08x}")

    if args.input_source == "hdmi":
        log("Capturing one frame from HDMI input...")
        plaintext = capture_payload_from_hdmi(
            width=args.width,
            height=args.height,
            fps=args.fps,
            pixel_format=args.pixel_format,
            hdmi_bitstream=args.hdmi_bitstream,
        )
    else:
        frame_bytes = args.frame_bytes
        if frame_bytes <= 0:
            frame_bytes = args.width * args.height * pixel_bytes(args.pixel_format)
        plaintext = synthetic_payload(frame_bytes)

    frame_bytes = len(plaintext)
    if frame_bytes <= 0:
        raise RuntimeError("Source frame is empty")

    log(f"Frame bytes = {frame_bytes}")

    alloc_bytes = max(frame_bytes, 120000)
    words = (alloc_bytes + 7) // 8
    log("Allocating ping-pong DDR buffers...")
    buf0 = allocate(shape=(words,), dtype=np.uint64)
    buf1 = allocate(shape=(words,), dtype=np.uint64)

    tx_alloc_bytes = max(frame_bytes, 4096)
    tx = allocate(shape=(tx_alloc_bytes,), dtype=np.uint8)

    try:
        buf0_addr = int(buf0.device_address)
        buf1_addr = int(buf1.device_address)
        buf0_lo, buf0_hi = split_u64(buf0_addr)
        buf1_lo, buf1_hi = split_u64(buf1_addr)

        log(f"BUF0 addr = 0x{buf0_addr:016x}")
        log(f"BUF1 addr = 0x{buf1_addr:016x}")

        # Configure ping-pong writer for AES stream source.
        pp.write(PP_REG_IRQ_ENABLE, 0)
        pp.write(PP_REG_WRITER_ENABLE, 0)
        pp.write(PP_REG_CONTROL, PP_CTRL_SOFT_RESET)
        pp.write(PP_REG_WRITER_CMD, 0x3)
        pp.write(PP_REG_FRAME_BYTES_CFG, frame_bytes)
        pp.write(PP_REG_BUF0_ADDR_LO, buf0_lo)
        pp.write(PP_REG_BUF0_ADDR_HI, buf0_hi)
        pp.write(PP_REG_BUF1_ADDR_LO, buf1_lo)
        pp.write(PP_REG_BUF1_ADDR_HI, buf1_hi)
        pp.write(PP_REG_WRITER_SRC_SEL, 1)
        pp.write(PP_REG_WRITER_ENABLE, 1)
        pp.write(PP_REG_CONTROL, PP_CTRL_ENABLE)

        # Configure AES stream session.
        write_aes_key(aes, KEY)
        write_aes_nonce(aes, NONCE)
        write_aes_lengths(aes, len(AAD) * 8, frame_bytes * 8)
        aes.write(AES_CTRL, AES_CTRL_SET_STREAM)
        wait_until(lambda: (aes.read(AES_STATUS) & AES_STS_STREAM_MODE) != 0, 1.0, "stream_mode=1")

        aes.write(AES_CTRL, AES_CTRL_LOAD_KEY)
        wait_until(lambda: (aes.read(AES_STATUS) & AES_STS_KEYS_READY_MASK) == 0xF, 2.0, "keys_ready == 0xF")
        wait_until(lambda: (aes.read(AES_STATUS) & AES_STS_H_VALID) != 0, 2.0, "h_valid")

        wait_until(lambda: (aes.read(AES_STATUS) & AES_STS_SESSION_READY) != 0, 2.0, "session_ready")
        aes.write(AES_CTRL, AES_CTRL_START_SESSION)
        push_aad_blocks(aes, AAD)

        # Encrypt via DMA MM2S -> AES stream.
        tx[:] = 0
        tx[:frame_bytes] = np.frombuffer(plaintext, dtype=np.uint8)
        tx.flush()
        dma.sendchannel.transfer(tx, nbytes=frame_bytes)
        wait_dma_send_done(dma, 5.0)

        wait_until(lambda: (pp.read(PP_REG_READY_MASK) & (PP_READY_BUF0 | PP_READY_BUF1)) != 0, 5.0, "produced frame")
        ready = pp.read(PP_REG_READY_MASK)

        if ready & PP_READY_BUF0:
            produced_buf = buf0
            consume_mask = PP_READY_BUF0
            valid_bytes = pp.read(PP_REG_VALID_BYTES_BUF0)
            frame_id = pp.read(PP_REG_FRAME_ID_BUF0)
            produced_idx = 0
        else:
            produced_buf = buf1
            consume_mask = PP_READY_BUF1
            valid_bytes = pp.read(PP_REG_VALID_BYTES_BUF1)
            frame_id = pp.read(PP_REG_FRAME_ID_BUF1)
            produced_idx = 1

        log(f"Produced buffer={produced_idx} frame_id={frame_id} valid_bytes={valid_bytes}")
        if valid_bytes != frame_bytes:
            raise RuntimeError(f"VALID_BYTES mismatch: got {valid_bytes}, expected {frame_bytes}")

        produced_buf.sync_from_device()
        ciphertext = produced_buf.view(np.uint8)[:valid_bytes].tobytes()

        wait_until(lambda: (aes.read(AES_STATUS) & AES_STS_TAG_VALID) != 0, 3.0, "tag_valid")
        tag_hw = read_aes_block(aes, AES_TAG_BASE)

        # PS software decrypt from DDR ciphertext.
        decrypted = AESGCM(KEY).decrypt(NONCE, ciphertext + tag_hw, AAD)
        if decrypted != plaintext:
            raise RuntimeError("PS decrypt mismatch against source plaintext")

        log("PS decrypt verified plaintext match")

        if args.render_hdmi:
            log("Rendering decrypted frame to HDMI output...")
            render_payload_to_hdmi(
                payload=decrypted,
                width=args.width,
                height=args.height,
                fps=args.fps,
                pixel_format=args.pixel_format,
                hdmi_bitstream=args.hdmi_bitstream,
            )
            log("HDMI render submitted")

        # Consume and stop.
        pp.write(PP_REG_CONSUMED_MASK, consume_mask)
        wait_until(lambda: (pp.read(PP_REG_READY_MASK) & consume_mask) == 0, 1.5, "consumed clear")
        pp.write(PP_REG_CONTROL, 0)
        wait_until(lambda: (pp.read(PP_REG_WRITER_STATUS) & 0x1) == 0, 1.5, "writer busy clear")

        writer_status = pp.read(PP_REG_WRITER_STATUS)
        writer_errors = pp.read(PP_REG_WRITER_ERROR_COUNT)
        drops = pp.read(PP_REG_DROP_COUNT)
        write_index = pp.read(PP_REG_WRITE_INDEX)

        log(
            f"WRITER_STATUS=0x{writer_status:08x} WRITE_INDEX={write_index} "
            f"DROP_COUNT={drops} WRITER_ERROR_COUNT={writer_errors}"
        )

        if writer_status & 0x2:
            raise RuntimeError("Writer fault is set")
        if writer_errors != 0:
            raise RuntimeError(f"Writer error count non-zero: {writer_errors}")

        log("Ping-pong PS decrypt -> HDMI out test PASSED")
        return 0
    finally:
        tx.freebuffer()
        buf0.freebuffer()
        buf1.freebuffer()


if __name__ == "__main__":
    raise SystemExit(main())
