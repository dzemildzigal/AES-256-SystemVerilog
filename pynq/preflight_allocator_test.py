"""
PYNQ CMA allocator preflight for AES ping-pong stream tests.

Purpose:
- Detect allocator behavior that has caused board freezes during tiny CMA
  allocations after overlay load.
- Verify the padded-allocation path used by test_ping_pong_writer_aes_stream.py.

Usage:
  timeout -k 5 45s python3 -u preflight_allocator_test.py

Exit codes:
  0 = PREFLIGHT PASS
  1 = hard failure (overlay load or required allocation failed)
  2 = PREFLIGHT WARNING (tiny allocation probe appears risky)
"""

from __future__ import annotations

import argparse
import multiprocessing as mp
import os
import sys
import time
from typing import Optional, Tuple

import numpy as np
from pynq import Overlay, allocate


def log(msg: str) -> None:
    print(msg, flush=True)


def read_cma_meminfo() -> Tuple[Optional[str], Optional[str]]:
    cma_total = None
    cma_free = None
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("CmaTotal:"):
                    cma_total = line.split(":", 1)[1].strip()
                elif line.startswith("CmaFree:"):
                    cma_free = line.split(":", 1)[1].strip()
    except Exception:
        pass
    return cma_total, cma_free


def alloc_probe(byte_count: int, label: str) -> None:
    if byte_count <= 0:
        raise ValueError(f"{label}: byte_count must be > 0")

    t0 = time.perf_counter()
    buf = allocate(shape=(byte_count,), dtype=np.uint8)
    try:
        addr = int(buf.device_address)
        buf[0] = 0xA5
        buf[-1] = 0x5A
        buf.flush()
    finally:
        buf.freebuffer()

    dt_ms = (time.perf_counter() - t0) * 1000.0
    log(f"{label}: {byte_count} bytes OK (addr=0x{addr:016x}, {dt_ms:.2f} ms)")


def tiny_probe_worker(bitstream: str, tiny_bytes: int, iters: int) -> None:
    # Child process probe to isolate potential tiny-allocation stalls.
    Overlay(bitstream)
    for _ in range(iters):
        b = allocate(shape=(tiny_bytes,), dtype=np.uint8)
        b.freebuffer()


def get_mp_context() -> mp.context.BaseContext:
    # Prefer fork on Linux/PYNQ; fallback to spawn if unavailable.
    for name in ("fork", "spawn"):
        try:
            return mp.get_context(name)
        except ValueError:
            continue
    return mp.get_context()


def run_tiny_probe(bitstream: str, tiny_bytes: int, iters: int, timeout_s: float) -> bool:
    ctx = get_mp_context()
    proc = ctx.Process(target=tiny_probe_worker, args=(bitstream, tiny_bytes, iters))

    log(
        f"Tiny probe: {iters} x {tiny_bytes}-byte allocations "
        f"(timeout {timeout_s:.1f}s, isolated process)"
    )
    proc.start()
    proc.join(timeout=timeout_s)

    if proc.is_alive():
        # If the child stalls in kernel space, terminate may not immediately work.
        proc.terminate()
        proc.join(timeout=1.0)
        log("PREFLIGHT WARNING: tiny allocation probe did not finish before timeout")
        return False

    if proc.exitcode != 0:
        log(f"PREFLIGHT WARNING: tiny allocation probe exited with code {proc.exitcode}")
        return False

    log("Tiny probe: OK")
    return True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="PYNQ allocator preflight test")
    parser.add_argument("--bitstream", default="aes_gcm_ping_pong_wrapper.bit", help="Bitstream path")
    parser.add_argument("--safe-bytes", type=int, default=120000, help="Padded buffer size for BUF0/BUF1 checks")
    parser.add_argument("--tx-bytes", type=int, default=4096, help="TX staging buffer size check")
    parser.add_argument("--tiny-bytes", type=int, default=64, help="Tiny probe allocation size")
    parser.add_argument("--tiny-iters", type=int, default=64, help="Tiny probe iteration count")
    parser.add_argument("--tiny-timeout", type=float, default=8.0, help="Tiny probe timeout seconds")
    parser.add_argument("--skip-tiny-probe", action="store_true", help="Skip tiny allocation risk probe")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    log("=== PYNQ Allocator Preflight ===")
    log(f"PID={os.getpid()} Python={sys.version.split()[0]}")

    cma_total, cma_free = read_cma_meminfo()
    if cma_total is not None and cma_free is not None:
        log(f"CMA: total={cma_total} free={cma_free}")
    else:
        log("CMA: unavailable (/proc/meminfo parse failed)")

    log(f"Loading overlay: {args.bitstream}")
    Overlay(args.bitstream)

    log("Checking padded allocation path used by stream test...")
    alloc_probe(args.safe_bytes, "BUF0")
    alloc_probe(args.safe_bytes, "BUF1")
    alloc_probe(args.tx_bytes, "TX")

    if args.skip_tiny_probe:
        log("Tiny probe skipped by request")
        log("PREFLIGHT PASS")
        return 0

    tiny_ok = run_tiny_probe(args.bitstream, args.tiny_bytes, args.tiny_iters, args.tiny_timeout)
    if not tiny_ok:
        log("Recommendation: keep padded allocations and avoid tiny CMA buffers in stream tests")
        return 2

    log("PREFLIGHT PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        log("Interrupted")
        raise SystemExit(130)
