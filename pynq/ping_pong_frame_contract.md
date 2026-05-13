# Ping-Pong Frame Contract (Phase 1, 10-15 FPS)

This is the concrete first implementation contract for PL producer -> DDR -> PS C sender.

Goal for this phase:

- keep control simple,
- avoid full descriptor-ring complexity,
- support sustained 10 fps and 15 fps operation,
- preserve a clean upgrade path to chunked/ring queue later.

## Implementation Status (2026-05-13)

Implemented now:

- `AES_VERILOG.srcs/sources_1/new/AXI_PingPong_Ctrl.sv`
   - map0 AXI-Lite register bank
   - ping-pong ownership control state
   - synthetic producer cadence for control-plane smoke testing (default mode)
   - deterministic AXI4 master DDR writer mode (first writer slice)
   - AXI-Stream writer source mode (`WRITER_SRC_SEL=1`) for AES CT stream ingestion
- `AES_VERILOG.srcs/sources_1/new/AXI_PingPong_Ctrl_wrapper.v`
- `pynq/build_bd_gcm_ping_pong.tcl`
   - integrated stream path: DMA MM2S -> `AXI_AES_GCM_Stream_wrapper` -> `AXI_PingPong_Ctrl_wrapper`
   - shared GP0 AXI-Lite control for ping-pong, AES stream core, and DMA
   - shared HP0 memory path for DMA MM2S reads and ping-pong AXI master writes
- `pynq/test_ping_pong_ctrl.py`
- `pynq/test_ping_pong_writer_ddr.py`
- `pynq/test_ping_pong_writer_aes_stream.py`
- `OS-VideoSDR/pynq/ps_shim/src/ping_pong_udp_tx_example.c` (PS consumer template)

Next implementation slices:

- expose and validate map1 data aperture for PS-visible payload reads,
- run paced 10/15 fps soak with DROP_COUNT delta tracking,
- keep the same map0 register contract for software continuity.

## Why This Replaces 8k x 4k For Now

The earlier 8192 x 4096 geometry was a stress-test queue profile. It is not required for this first bring-up.

Phase 1 uses exactly two full-frame buffers in DDR.

## Frame Size and DDR Budget

For 1080p RGB888 raw frame payload:

- frame_bytes = 1920 x 1080 x 3 = 6220800 bytes

Ping-pong data space:

- buffer0 size = frame_bytes
- buffer1 size = frame_bytes
- total payload space = 12441600 bytes (~11.87 MiB)

Practical allocation recommendation:

- reserve 16 MiB for each buffer (alignment/headroom)
- total reserved data aperture = 32 MiB

## Ownership Model

Single producer (PL) and single consumer (PS C).

- PL writes only to buffer selected by write_index.
- PS reads only from buffer selected by read_index.
- PL marks buffer ready when complete.
- PS marks buffer consumed when UDP send done.

Indices alternate between 0 and 1.

## AXI-Lite Register Map (map0)

Use 32-bit registers, little-endian, offsets from control base.

| Offset | Name | Access | Description |
|---|---|---|---|
| 0x0000 | VERSION | RO | IP version |
| 0x0004 | CONTROL | RW | bit0 enable, bit1 soft_reset |
| 0x0008 | STATUS | RO | bit0 running, bit1 fault |
| 0x0010 | FRAME_BYTES_CFG | RW | expected frame bytes |
| 0x0014 | WRITE_INDEX | RO | PL next write buffer index (0/1) |
| 0x0018 | READY_MASK | RO | bit0 buffer0 ready, bit1 buffer1 ready |
| 0x001C | CONSUMED_MASK | RW1C | PS sets bit for consumed buffer |
| 0x0020 | FRAME_ID_BUF0 | RO | frame id currently in buffer0 |
| 0x0024 | FRAME_ID_BUF1 | RO | frame id currently in buffer1 |
| 0x0028 | VALID_BYTES_BUF0 | RO | produced bytes in buffer0 |
| 0x002C | VALID_BYTES_BUF1 | RO | produced bytes in buffer1 |
| 0x0030 | DROP_COUNT | RO | frames dropped due no free buffer |
| 0x0034 | IRQ_ENABLE | RW | bit0 frame ready IRQ enable |
| 0x0038 | IRQ_STATUS | RW1C | bit0 frame ready IRQ pending |
| 0x0040 | WRITER_ENABLE | RW | bit0 deterministic DDR writer mode enable |
| 0x0044 | BUF0_ADDR_LO | RW | DDR base address low word for buffer0 |
| 0x0048 | BUF0_ADDR_HI | RW | DDR base address high word for buffer0 |
| 0x004C | BUF1_ADDR_LO | RW | DDR base address low word for buffer1 |
| 0x0050 | BUF1_ADDR_HI | RW | DDR base address high word for buffer1 |
| 0x0054 | WRITER_STATUS | RO | bit0 busy, bit1 fault, bit2 writer_enable |
| 0x0058 | WRITER_ERROR_COUNT | RO | deterministic writer AXI error counter |
| 0x005C | WRITER_CMD | RW1C | bit0 clear_fault, bit1 clear_error_count |
| 0x0060 | WRITER_SRC_SEL | RW | bit0 source select: 0=deterministic pattern, 1=AXI-Stream input |

Notes:

- RW1C means write 1 to clear.
- writer mode is off by default (`WRITER_ENABLE=0`) so existing control-plane smoke tests remain valid.
- source select defaults to deterministic pattern (`WRITER_SRC_SEL=0`).
- If interrupts are not wired in first bitstream, PS can poll READY_MASK.

## DDR Data Aperture

Expose one data aperture (map1) containing both frame buffers.

Layout:

- base + 0x00000000: buffer0 (frame_bytes max)
- base + buffer_stride: buffer1 (frame_bytes max)

Recommended buffer_stride:

- 0x01000000 (16 MiB)

Then:

- buf0_addr = map1_base + 0x00000000
- buf1_addr = map1_base + 0x01000000

## PL State Machine (Producer)

1. Wait until CONTROL.enable = 1.
2. Choose target buffer by WRITE_INDEX.
3. Capture and encrypt one frame into target buffer.
4. Write VALID_BYTES_BUFx and FRAME_ID_BUFx.
5. Set READY_MASK bit for that buffer.
6. Optionally assert IRQ_STATUS bit0.
7. Wait for matching CONSUMED_MASK bit from PS.
8. Clear READY bit for consumed buffer.
9. Toggle WRITE_INDEX and continue.

If next buffer is still ready (not consumed), increment DROP_COUNT and apply project policy:

- drop oldest or
- drop newest,

but keep policy deterministic.

## PS C Loop (Consumer)

1. mmap map0 control regs and map1 data aperture.
2. Configure FRAME_BYTES_CFG and set CONTROL.enable.
3. Loop:
   - read READY_MASK
   - if neither bit set, continue (or poll IRQ fd)
   - if buffer0 ready: send buffer0[0:VALID_BYTES_BUF0] via UDP
   - if buffer1 ready: send buffer1[0:VALID_BYTES_BUF1] via UDP
   - write CONSUMED_MASK bit for buffer sent
   - clear IRQ_STATUS if used
4. Keep UDP socket in C (SO_SNDBUF sized appropriately).

Reference C skeleton is in:

- OS-VideoSDR/pynq/ps_shim/src/ping_pong_udp_tx_example.c

## Throughput Reality Check at 10/15 FPS

Raw 1080p RGB payload rates:

- 10 fps: 62208000 bytes/s (~497.7 Mb/s payload)
- 15 fps: 93312000 bytes/s (~746.5 Mb/s payload)

These fit under 1 GbE payload envelope much better than 30 fps raw.

## Upgrade Path to Ring/Chunk Queue

Move beyond ping-pong only if measured evidence shows frequent stalls or drops.

Trigger conditions for upgrade:

- DROP_COUNT keeps increasing,
- PS send jitter causes repeated missed handoffs,
- latency target requires sub-frame transmit overlap.

Then migrate from 2 buffers to N chunk slots.
