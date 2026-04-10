# AES-256-SystemVerilog

AES-256 GCM hardware accelerator in SystemVerilog for Zynq-7020 (PYNQ-Z2), with:

- AXI4-Lite control plane
- AXI4-Stream data plane for bulk plaintext/ciphertext
- AXI DMA integration for high-throughput transfers
- Python validation script on PYNQ

This README is the "continue from here" guide for build, test, and deployment.

## Current Status

- Functional correctness: PASS (hardware output matches software AESGCM reference).
- Timing: CLOSED at 100 MHz (no setup/hold violations in latest run).
- DMA transfer limit issue: fixed by widening DMA length width.
- Stream byte-order mismatch: fixed in RTL, native output now verified.

## Latest Measured Results (2026-04-10)

### Python Validation Output Summary

Functional test (4 blocks):

- PASS
- DMA elapsed: 0.001116 s
- Host session elapsed: 0.009680 s
- Session cycles: 424822
- Stream cycles: 33

Streaming stress test (4096 blocks, 65536 bytes):

- PASS
- DMA elapsed: 0.001021 s
- Host session elapsed: 0.008641 s
- Session cycles: 358911
- Stream cycles: 8215
- Effective host+DMA throughput: 61.23 MiB/s
- Effective end-to-end throughput (full host session): 7.23 MiB/s
- PL-cycle throughput (session window): 17.41 MiB/s
- PL-cycle throughput (true stream window): 760.80 MiB/s
- Session cycles/block: 87.625
- Stream cycles/block: 2.006

Overhead split (reported by test script):

- Host orchestration outside PL session: 5.052 ms (58.47%)
- PL session overhead outside stream window: 3.507 ms (40.58%)
- Pure stream datapath window: 0.082 ms (0.95%)
- Stream share inside PL session window: 2.29%

### Easy Interpretation

- Correctness is good: both functional and stress tests pass with native byte order.
- Hardware datapath is fast: true stream-window throughput is 760.80 MiB/s.
- Theoretical ceiling is 1525.88 MiB/s at 100 MHz, so measured stream datapath is about 49.9% of theoretical.
- Most wall-time is not pure stream compute. The largest contributor is host-side orchestration, followed by non-stream work inside the PL session window.
- End-to-end application throughput is therefore much lower than pure datapath throughput, which is expected in this architecture.

### Timing/Power/Utilization Snapshot

Latest implementation metrics reported:

- WNS: +0.234 ns
- TNS: 0.000 ns
- WHS: +0.034 ns
- THS: 0.000 ns
- TPWS: 0.000 ns
- Total on-chip power: 2.304 W
- Utilization: 41291 LUTs, 14596 FFs, 17 BRAMs, 0 URAMs, 0 DSPs

## What Was Changed Recently

### 1) Stream datapath wrapper improvements

File:

- `AES_VERILOG.srcs/sources_1/new/AXI_AES_GCM_Stream.sv`

Highlights:

- Native byte-lane stream mapping is used for PT/CT data path.
- Added `STREAM_CYCLES` register at `0x9C` to measure true stream-window cycles
	(first accepted PT beat to `tag_valid`).

### 2) GHASH multiplier timing fix

File:

- `AES_VERILOG.srcs/sources_1/new/GFMult128.sv`

Highlights:

- GF multiply operation was split into two balanced 64-iteration halves.
- Intermediate state is registered between halves.
- Goal: reduce critical combinational depth per cycle and improve timing margin.

### 3) DMA benchmark script improvements

File:

- `pynq/test_aes_gcm_dma.py`

Highlights:

- Reads `STREAM_CYCLES` (`0x9C`) in addition to session cycles (`0x98`).
- Reports both:
	- session-window throughput (includes setup/session overhead)
	- true stream-window throughput (data-path-focused metric)

### 4) Block design automation updates

File:

- `pynq/build_bd_gcm_dma.tcl`

Highlights:

- Creates/updates `aes_gcm_dma` BD with PS7 + AXI DMA + stream wrapper.
- Uses DMA settings suitable for larger transfers:
	- `c_sg_length_width = 26`
	- larger burst sizes.

## Project Structure (Important Files)

- `pynq/build_bd_gcm_dma.tcl` - Vivado BD automation for DMA design.
- `pynq/test_aes_gcm_dma.py` - PYNQ runtime validation and throughput test.
- `AES_VERILOG.srcs/sources_1/new/AXI_AES_GCM_Stream.sv` - AXI-Lite + AXI-Stream wrapper.
- `AES_VERILOG.srcs/sources_1/new/GcmMode.sv` - AES-GCM session control.
- `AES_VERILOG.srcs/sources_1/new/GHashEngine.sv` - GHASH engine.
- `AES_VERILOG.srcs/sources_1/new/GFMult128.sv` - GF(2^128) multiplier.

## Build in Vivado (Recommended)

Open Vivado Tcl Console in project folder and run:

```tcl
open_project AES_VERILOG.xpr
source pynq/build_bd_gcm_dma.tcl

set srun [lindex [get_runs -filter {IS_SYNTHESIS==1}] 0]
set irun [lindex [get_runs -filter {IS_IMPLEMENTATION==1}] 0]

launch_runs $srun -jobs 4
wait_on_run $srun

launch_runs $irun -to_step write_bitstream -jobs 4
wait_on_run $irun
```

Note:

- Always open the project first (`open_project AES_VERILOG.xpr`) before sourcing
	the BD Tcl script.

## Generated Artifact Locations

After successful implementation:

- Bitstream:
	- `AES_VERILOG.runs/impl_1/aes_gcm_dma_wrapper.bit`
- Hardware handoff:
	- `AES_VERILOG.gen/sources_1/bd/aes_gcm_dma/hw_handoff/aes_gcm_dma.hwh`

For PYNQ, copy both files to the same directory and keep matching base names.

Example deployment naming:

- `aes_gcm_dma_wrapper.bit`
- `aes_gcm_dma_wrapper.hwh`

## Run on PYNQ

On board (inside notebook folder where files are copied):

```bash
python3 test_aes_gcm_dma.py
```

Expected high-level result:

- Functional test PASS
- Streaming stress DMA PASS
- Final line confirms native byte-order correctness

## Understanding Throughput Lines

The script prints multiple MiB/s values. They are all useful, but different:

- `Effective host+DMA throughput`:
	- End-to-end practical speed from software perspective.
	- Includes software + DMA orchestration overhead.

- `PL-cycle throughput (session window)`:
	- Based on session cycle counter (`0x98`).
	- Includes setup/session overhead, so typically lower.

- `PL-cycle throughput (true stream window)`:
	- Based on stream cycle counter (`0x9C`).
	- Better indicator of pure stream datapath efficiency.

- `Theoretical core throughput @100MHz`:
	- Ideal upper bound, not expected end-to-end runtime value.

## Timing and Resource Notes

Recent results indicate:

- Timing closed at 100 MHz.
- Resource usage is high in LUT/slice domain (expected for this architecture),
	with moderate FF/BRAM and no DSP usage.

If timing regresses in future edits, first inspect GHASH-related paths and stream wrapper changes.

## Ready-to-Push Checklist

Before pushing to `main`:

1. Re-run build to `write_bitstream` successfully.
2. Re-run `python3 test_aes_gcm_dma.py` on PYNQ and confirm PASS.
3. Verify changed files are intentional:
	 - RTL: `AXI_AES_GCM_Stream.sv`, `GFMult128.sv`
	 - Test: `pynq/test_aes_gcm_dma.py`
	 - Build script: `pynq/build_bd_gcm_dma.tcl`
	 - Project/run metadata: `AES_VERILOG.xpr` (if changed)
4. Commit and push.

Suggested git commands:

```bash
git status
git add README.md AES_VERILOG.srcs/sources_1/new/AXI_AES_GCM_Stream.sv AES_VERILOG.srcs/sources_1/new/GFMult128.sv pynq/build_bd_gcm_dma.tcl pynq/test_aes_gcm_dma.py AES_VERILOG.xpr
git commit -m "Finalize AES-GCM DMA flow: timing closure, stream metrics, and deployment docs"
git push origin main
```

If your branch is not `main`, push your branch and open a PR instead.
