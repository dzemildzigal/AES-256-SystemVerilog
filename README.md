# AES-256 GCM Hardware Accelerator

A fully pipelined AES-256-GCM encryption core implemented in SystemVerilog, running on the **Zynq-7020 FPGA** (PYNQ-Z2 board). Plaintext enters over DMA, ciphertext and authentication tag come back, all at hardware speed.

---

## What This Does

AES-256-GCM is the gold-standard authenticated encryption mode used in TLS, SSH, and storage encryption. It does two things simultaneously:

1. **Encrypts** your data using AES in counter mode (CTR).
2. **Authenticates** it using GHASH — a polynomial MAC that catches any tampering.

This project moves that whole computation into the FPGA programmable logic (PL), leaving the CPU free for other work. The host sends plaintext over DMA and gets back ciphertext + a 16-byte authentication tag.

---

## How Fast Is It?

### Latest Results (2026-04-23, PYNQ-Z2, 100 MHz)

| Metric | Value |
|--------|-------|
| **Pure datapath throughput** | **761 MiB/s** |
| Theoretical ceiling (core, 128-bit/cycle) | 1526 MiB/s |
| Theoretical ceiling (memory feed via HP0) | 763 MiB/s |
| **Utilization vs memory ceiling** | **99.76%** |
| Stream cycles per 128-bit block | 2.005 |
| Effective end-to-end throughput | 7.56 MiB/s |
| DMA transfer throughput | 63.72 MiB/s |

> The FPGA core is essentially saturating the memory bus. The true bottleneck is the Zynq HP0 memory port, which is physically 64-bit (8 bytes/cycle), while an AES block is 128-bit (16 bytes). At 100 MHz that gives a hard ceiling of ~763 MiB/s — and we hit 99.76% of it.

### Where Does Time Go?

In a typical 4096-block session, wall time breaks down like this:

| Stage | Time | Share |
|-------|------|-------|
| Host software orchestration | 4.85 ms | 58.7% |
| PL session setup (key expansion, J0 computation) | 3.33 ms | 40.3% |
| **Pure stream datapath** | **0.08 ms** | **1.0%** |

The FPGA does its job in under 0.1 ms. Everything else is Python and session setup overhead.

### FPGA Resource Usage

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUTs | 26,657 | 53,200 | 50.1% |
| Flip-Flops | 12,597 | 106,400 | 11.8% |
| BRAMs | 17 | 140 | 12.1% |
| DSPs | 0 | 220 | 0% |
| Total on-chip power | 2.115 W | — | PS dominates (72%) |

### Timing

| Metric | Value | Meaning |
|--------|-------|---------|
| WNS | +0.134 ns | Setup timing: passes with margin |
| WHS | +0.014 ns | Hold timing: passes (tight but clean) |
| WPWS | +3.750 ns | Pulse width: passes |

---

## Architecture Overview

```
CPU (Python)
    │
    │  AXI4-Lite (control registers)
    ▼
┌───────────────────────────────────────┐
│         AXI_AES_GCM_Stream            │  ← AXI wrapper + CT output FIFO
│                                       │
│   ┌─────────────────────────────┐     │
│   │         GcmMode             │     │  ← Session scheduler
│   │                             │     │
│   │  KeyExpansion  EncryptPipe  │     │  ← AES-256 key sched + 15-stage encrypt
│   │                             │     │
│   │       GHashEngine           │     │  ← GHASH accumulator
│   │          │                  │     │
│   │       GFMult128             │     │  ← GF(2^128) multiplier, 1-cycle latency
│   └─────────────────────────────┘     │
└───────────────────────────────────────┘
    │                       │
    │  AXI4-Stream (PT in)  │  AXI4-Stream (CT out)
    ▼                       ▼
   DMA                     DMA
    │                       │
    └───────── DDR ─────────┘
                 │
            Zynq HP0 port
           (64-bit, 100 MHz)
```

**Key design choices:**

- **Single shared AES pipeline** handles key hash (H), session IV (J0), and all payload blocks in priority order. No duplication.
- **GFMult128** is fully combinational (128 iterations in one clock cycle), results registered. 1-cycle latency, 1 op/cycle throughput.
- **GHashEngine** uses the 1-cycle multiplier with result forwarding: as soon as one block's GHASH result is available it is piped directly into the next block's XOR input, avoiding a stall cycle. Designed for 1-block/cycle throughput.
- **FIFO-buffered CT output** in the AXI wrapper absorbs backpressure from the DMA receive channel.

---

## Why Is Throughput ~2 Cycles/Block Instead of 1?

The short answer: **the memory bus, not the FPGA logic, is the bottleneck.**

The GHASH core is designed to process one 128-bit block per clock cycle. But blocks arrive from DDR through the Zynq HP0 memory port, which is:

- **64 bits wide** (8 bytes per cycle)
- Clocked at 100 MHz (same as core)

That means feeding one 128-bit AES block takes **at minimum 2 memory cycles**. The FPGA compute pipeline is ready before the next block arrives.

At 99.76% utilization of the HP0 ceiling, there is essentially nothing left to gain on this platform without a hardware change.

### Can We Get to 1 Cycle/Block?

| Option | Difficulty | Gain |
|--------|-----------|------|
| Overclock HP0 (e.g. 200 MHz feed, 100 MHz core) | Medium | Possible 2x feed rate |
| Use two HP ports in parallel and merge streams | High | True 128-bit feed |
| Preload from BRAM (core benchmark only, not DDR) | Low | Proves 1 cycle/block core behavior |
| Switch to Zynq UltraScale+ (wider memory ports) | Platform change | Solves it cleanly |

On this specific board (Zynq-7020, HP0 only), the memory wall is the fundamental limit.

---

## Project File Map

```

Ring-integration implementation blueprint for OS-VideoSDR:

- `pynq/ring_integration_blueprint.md`
AES_VERILOG.srcs/sources_1/new/
├── GcmMode.sv              ← Top-level session scheduler
├── GHashEngine.sv          ← GHASH accumulation engine
├── GFMult128.sv            ← GF(2^128) multiplier (1-cycle latency)
├── KeyExpansion.sv         ← AES-256 key schedule (4 words/cycle)
├── EncryptPipelined.sv     ← 15-stage AES-256 encrypt pipeline
├── AXI_AES_GCM_Stream.sv  ← AXI4-Lite + AXI4-Stream wrapper + CT FIFO

pynq/
├── build_bd_gcm_dma.tcl   ← Vivado block design automation script
├── test_aes_gcm_dma.py    ← Board validation + throughput benchmark
```

---

## Building the Bitstream

Open Vivado, open the project, then run in the Tcl console:

```tcl
open_project AES_VERILOG.xpr
source pynq/build_bd_gcm_dma.tcl

launch_runs synth_1 -jobs 16
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 16
wait_on_run impl_1
```

Output files:
- `AES_VERILOG.runs/impl_1/aes_gcm_dma_wrapper.bit`
- `AES_VERILOG.gen/sources_1/bd/aes_gcm_dma/hw_handoff/aes_gcm_dma.hwh`

Copy both files to your PYNQ board with **matching base names**:
```
aes_gcm_dma_wrapper.bit
aes_gcm_dma_wrapper.hwh
```

---

## Running on PYNQ

```bash
python3 test_aes_gcm_dma.py
```

Expected output at the end:
```
ALL TESTS PASSED - native byte order correct; AES-256 GCM DMA path is operational on FPGA
```

---

## Understanding the Benchmark Output

The test script prints several throughput numbers. Here is what each one means:

| Line | What it measures | Useful for |
|------|-----------------|------------|
| `Effective host+DMA throughput` | End-to-end speed seen from software, including all Python overhead | Real application baseline |
| `Effective end-to-end throughput` | Same but using full host session timer | Conservative real-world estimate |
| `PL-cycle throughput (session window)` | Throughput during PL session cycles, including AES key setup | PL efficiency excluding Python |
| `PL-cycle throughput (true stream window)` | Throughput during pure stream cycles only | **Best measure of core speed** |
| `Stream cycles/block` | Average clock cycles per 128-bit block in stream window | Core efficiency metric |
| `Utilization vs 128-bit core ceiling` | How close to the theoretical 1-block/cycle maximum | Core pipeline headroom |
| `Utilization vs PS HP-port ceiling` | How close to the memory bus maximum | **Memory saturation indicator** |
| `Theoretical core throughput` | Perfect core: 16 bytes × 100 MHz | Upper bound if memory were free |
| `Theoretical PS HP-port throughput` | HP0 bus max: 8 bytes × 100 MHz | **Practical upper bound on this board** |

---

## Key Decisions and Design History

### GHASH: from 3-multiplier to 1-multiplier

**Before:** GHashEngine used 3 GFMult128 instances — one to precompute H², plus two parallel lanes for 2-block batching using the Horner trick. This used ~21,000 LUTs for multipliers alone.

**After:** GFMult128 was redesigned as a 1-cycle-latency combinational multiplier (all 128 GF iterations in one clock, result registered). GHashEngine was simplified to one multiplier instance with forwarding: the output of each multiply is piped directly into the next block's input so no stall cycle is needed. The H² precompute FSM and batch scheduling were removed entirely.

**Result:** LUT usage dropped from 40,876 to 26,657 (−35%), while throughput design goal (1 block/cycle) was preserved. The core is now simpler and smaller.

### Why the stream throughput is ~2 cycles/block, not 1

The GHASH core itself is designed for 1 cycle/block. The measured 2.005 cycles/block comes from the Zynq-7000 HP0 memory port being 64-bit wide. One 128-bit AES block requires two 64-bit transfers. The core is idle waiting for the second half to arrive. At 99.76% HP0 saturation, the design is at the physical limit of this platform.

### AES pipeline: single shared instance

A single 15-stage pipelined AES core handles three different jobs in priority order:

1. Computing H = AES(0) on new key (once per key load).
2. Computing E_K(J0) for the tag mask (once per session).
3. Encrypting payload blocks (continuous stream).

A 2-bit tag travels with each block through the 15-stage delay line so the output is routed correctly.

### Critical timing path

The synthesis critical path lives in `KeyExpansion`, not GHASH. Computing 4 key words per cycle cascades through S-box lookups and XOR chains, reaching 9.5 ns data delay (8 logic levels). WNS is +0.134 ns — timing closes but with limited margin. If Fmax needs to increase, pipelining KeyExpansion to 2 words/cycle would be the first step.

---

## Ready-to-Push Checklist

1. Run `write_bitstream` in Vivado successfully.
2. Run `python3 test_aes_gcm_dma.py` on board and confirm `ALL TESTS PASSED`.
3. Check that changed files are intentional.
4. Commit and push.

```bash
git add README.md \
        AES_VERILOG.srcs/sources_1/new/GFMult128.sv \
        AES_VERILOG.srcs/sources_1/new/GHashEngine.sv \
        AES_VERILOG.srcs/sources_1/new/AXI_AES_GCM_Stream.sv \
        pynq/test_aes_gcm_dma.py \
        pynq/build_bd_gcm_dma.tcl
git commit -m "Redesign GHASH to 1-cycle multiplier, document throughput ceiling analysis"
git push origin main
```
