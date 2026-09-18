# AES-256-SystemVerilog

AES-256-GCM in SystemVerilog, plus the video front end and DDR ring writer that
turn an HDMI input on a PYNQ-Z2 into an encrypted packet stream.

This repository holds the **FPGA side** of
**[OS-VideoSDR](https://github.com/dzemildzigal/OS-VideoSDR)**, which holds the
PS sender, the protocol, the PC receiver and the tests. The block design built
here produces the `hdmi_aes_tx.bit` / `.hwh` pair that OS-VideoSDR loads on the
board.

```text
 HDMI in ──► packetizer ──► AES-256-GCM engine ──► nonce injector ──► DDR ring writer
             (segments)      (encrypt + tag)                        (slots + produce)
                                                                          │
                                    AXI-Lite control from the PS ◄────────┘
                                    the PS sender reads the ring over the ACP
```

## What is in here

| module | job |
|--------|-----|
| `HDMI_Axis_Packetizer.sv` | cuts video frames into 2,095 segments of 440 pixels, adds the 40-byte header, drops every second frame so 60 Hz becomes 30 fps |
| `AES_GCM_Session_Sequencer.sv` | owns sessions, key, nonce and packet policy; talks to the AES core over its own AXI master |
| `AXI_AES_GCM_Stream.sv` | streaming wrapper: encrypt a packet, append the 16-byte tag |
| `GcmMode.sv`, `GHashEngine.sv`, `GFMult128.sv` | GCM: GHASH over the ciphertext and the length block |
| `EncryptPipelined.sv` and the round modules | the AES-256 pipeline |
| `KeyExpansion.sv` | AES-256 key schedule |
| `NoncePrefixInject.sv` | prepends the 8-byte nonce prefix that the receiver needs in clear |
| `DDRRingWriter.sv` | packs each packet into a 1,408-byte slot, writes it into DDR through the PS ACP, publishes a produce counter, and drops cleanly when the ring is full |
| `VideoFrontEndProbe.sv`, `VideoStatusProbe.sv`, `VideoBeatCounter.sv` | counters used to see what the video path is doing |
| `AXI_PingPong_Ctrl.sv` | earlier DMA control path, kept for the non-streaming designs |

## The two register maps software touches

**Session sequencer** (key, nonce, policy — written by `tx_daemon.py`):

```text
0x0C stream_payload   key_id, payload_type, stream_id
0x1C payload_bytes    segment payload in bytes (1320 for the 1408-byte slot)
0x40 nonce current    high word of the running nonce counter
+ key words, nonce seed, enable/status
```

**Ring writer** (written by `tx_shim`, the PS sender):

```text
0x04 control          1 = enable, bit 1 = soft reset
0x08 status           enable, fault, busy
0x0C/0x10 ring base   physical address of the slot ring
0x14/0x18 ctrl base   physical address of the produce/consume block
0x1C ring log2        11 = 2,048 slots
0x20 slot stride      must equal SLOT_STRIDE (1,408)
0x24 produce          wrapped slot index of the next slot to write
0x28 consume shadow   the writer's copy of the PS-pushed consume index
0x2C drop count        packets dropped because the ring was full
0x30/0x34 complete    published slots, low and high word
0x3C fault code       0 none, 1 base, 2 TKEEP, 3 length, 4 BRESP, 5/6 control
0x48 PS consume       the PS pushes the first slot it no longer needs here
0x4C coherent         1 when the writer reaches DDR through the ACP
0x50 cache attributes b[3:0] AXCACHE, b[12:8] AXUSER
```

The PS never reads the ring's counters over AXI-Lite in a hot loop: it reads the
produce value from the control block in DDR and pushes the consume value to
`0x48`. Two spinning threads hammering the two-cycle AXI-Lite read path made
reads come back as zero, which stranded the sender at 0 packets/s.

## Build

```bash
# full clean build: block design, synthesis, implementation, bitstream
vivado -mode batch -source pynq/rebuild_hdmi_aes_tx.tcl -log build_logs/rebuild.log
```

It writes `pynq/output/hdmi_aes_tx.bit` and `.hwh`. Copy both into
`OS-VideoSDR/pynq/overlays/tx/`.

If implementation misses timing by a fraction of a nanosecond (it happens; the
GHASH GF-multiply path is the sensitive one), use:

```bash
vivado -mode batch -source pynq/impl_retry.tcl
```

Attempt 1 re-runs post-route physical optimisation on the routed checkpoint,
which is what fixed a −0.067 ns miss to +0.013 ns. Do not call `place_design`
directly on a checkpoint: two BUFGs need cyclically adjacent sites and only the
run system's clock placement satisfies that.

## Simulations

```bash
# packetizer: segment count, header fields, payload order
xvlog -sv -work s AES_VERILOG.srcs/sources_1/new/HDMI_Axis_Packetizer.sv tb_packetizer.sv
xelab -s snap -L s s.tb_packetizer && xsim snap -runall

# ring writer: slot geometry, padding, drop behaviour
xvlog -sv -work s AES_VERILOG.srcs/sources_1/new/DDRRingWriter.sv \
                AES_VERILOG.srcs/sources_1/new/DDRRingWriter_wrapper.v tb_ddr_ring_writer.sv
xelab -s snap -L s s.tb_ddr_ring_writer && xsim snap -runall

# full chain: packetizer → AES → nonce injector → ring  (needs every RTL file)
# see tb_b1_b2_chain.sv
```

All three pass with the current geometry. There is also `tb_fullchain.sv`,
`tb_ep_kat.sv` (AES-GCM known-answer test) and the wrapper tests.

## Geometry and constraints

```text
slot            1,408 bytes = 11 x 128-byte bursts
payload         1,320 bytes = 440 pixels
packet          8 nonce prefix + 40 header + 1,320 payload + 16 tag + 24 pad
segments/frame  2,095  ->  62,850 packets/s at 30 fps
clock           100 MHz design domain, timing usually within a few hundred
                picoseconds; the GHASH GF multiply is the critical path and
                pipelining it is the durable fix
coherency       the ring writer uses S_AXI_ACP with AWCACHE bit 1 set and a
                write-allocate policy (4'b1111) plus AWUSER[0] set, so its
                writes snoop the CPU caches and the PS reads slots without
                any cache maintenance
```

## Debugging notes worth keeping

```text
- A wrong --payload-bytes is silent and total: the ciphertext stays perfect
  while every tag fails, because the AES core derives its GHASH length from
  header+payload. tx_daemon.py now checks it against the handoff.
- Draining the ring at startup must align with the writer's produce value.
  Otherwise the PS consume index can end up one slot ahead of produce, and the
  writer treats the ring as permanently full (it drops whenever
  (produce + 1) == consume).
- The PS must not write into the control block for every batch. Dirtying that
  cache line makes the CPU read a stale produce value, which looks exactly like
  the Ethernet port stalling.
- Temperature is not the problem: 55-60 C through full-rate runs on an
  uncooled board.
```

## Documentation

```text
docs/STATUS_B1_2026-08-24.md    nonce prefix injector
docs/STATUS_B2_2026-08-24.md    DDR ring writer
pynq/README_hdmi_aes_tx.md      the block design, clocking and integration
pynq/impl_retry.tcl             implementation retry when timing just misses
```
