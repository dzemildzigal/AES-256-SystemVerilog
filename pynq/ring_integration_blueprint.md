# Ring Integration Blueprint (AES-256-SystemVerilog)

This file explains, in implementation order, what to change in this repository so the current AES-GCM PL core can be used in the OS-VideoSDR ring flow.

If the immediate goal is minimum-complexity bring-up at 10-15 fps, start with the two-buffer contract first:

- `pynq/ping_pong_frame_contract.md`

Matching PS C loop template for that phase:

- `OS-VideoSDR/pynq/ps_shim/src/ping_pong_udp_tx_example.c`

## 1) What the current PL build is today

The current deployed build path is the DMA stream encrypt path:

- AXI wrapper: AXI_AES_GCM_Stream_wrapper.v
- Core wrapper: AXI_AES_GCM_Stream.sv
- Datapath: GcmMode.sv + EncryptPipelined.sv + GHASH
- BD script: pynq/build_bd_gcm_dma.tcl

Important behavior of current build:

- Input stream is plaintext only (S_AXIS_PT_*).
- Output stream is ciphertext only (M_AXIS_CT_*).
- Tag is exposed through AXI-Lite status/register polling, not stream output.
- No descriptor ring interface exists in this RTL.
- No PL interrupt is enabled in the current BD script.

## 2) Why this cannot be used as-is for ring integration

OS-VideoSDR ring runtime expects persistent shared-memory slot ownership and metadata flow. Current AES PL build expects PS software to launch DMA sessions and poll control bits.

Mismatch summary:

1. Control model mismatch:
- Current: command/poll over AXI-Lite.
- Needed: descriptor ownership (EMPTY/FULL) + producer/consumer indices.

2. Data movement mismatch:
- Current: PS-configured DMA transfer windows per session.
- Needed: always-on PL consumer/producer over ring apertures.

3. Eventing mismatch:
- Current: no fabric interrupt path in BD script.
- Needed: ring doorbell/completion IRQs to reduce polling overhead.

4. Direction mismatch:
- Current deployed wrapper is encrypt stream direction only.
- Needed: bidirectional flow (TX and RX directions) at system level.

## 3) Reuse vs rewrite (important)

Do NOT rewrite AES/GHASH math blocks.

Reuse directly:

- GcmMode.sv
- GHashEngine.sv
- GFMult128.sv
- KeyExpansion.sv
- EncryptPipelined.sv

Add new shell logic around them:

- ring descriptor controller
- payload mover and stream adapters
- IRQ + status/control registers for ring events

## 4) Exact file-level changes

## Step A: keep existing benchmark path intact

No destructive edits. Keep these files unchanged for regression reference:

- AXI_AES_GCM_Stream.sv
- AXI_AES_GCM_Stream_wrapper.v
- pynq/build_bd_gcm_dma.tcl

## Step B: add a new top for ring mode

Create new RTL files:

1. AXI_AES_GCM_Ring.sv
- New top-level module for ring operation.
- Includes one AXI-Lite control bank and ring event/IRQ registers.
- Includes ring descriptor FSMs for TX and RX directions.
- Instantiates crypto datapath modules (initially TX path first if needed).

2. AXI_AES_GCM_Ring_wrapper.v
- Plain Verilog wrapper for module-reference use in Vivado BD.

3. RingDescEngine.sv
- Reads slot headers and indices from ring map.
- Executes ownership transitions EMPTY->FULL and FULL->EMPTY.
- Handles slot_count wrap and payload_len bounds.

4. RingIrqCtrl.sv
- IRQ enable/status/clear registers.
- Doorbell and completion event aggregation.

## Step C: optional but recommended datapath extension for decrypt/verify

If full bidirectional crypto is required in PL in first cut, extend GcmMode.sv with mode control rather than creating a second unrelated datapath.

Required edits in GcmMode.sv:

1. Add operation mode input:
- op_decrypt_i (0 encrypt, 1 decrypt)

2. Add GHASH data select path:
- encrypt mode: GHASH over ciphertext output (current behavior)
- decrypt mode: GHASH over accepted ciphertext input blocks (not plaintext output)

3. Add tag-compare outputs:
- expected_tag_i[127:0]
- expected_tag_valid_i
- auth_ok_o
- auth_fail_o

4. Keep CTR keystream generation shared.
- GCM decrypt still uses AES encrypt(counter) keystream XOR.
- Do not route through DecryptPipelined for GCM data path.

## Step D: create a dedicated BD script for ring mode

Create new script:

- pynq/build_bd_gcm_ring.tcl

Changes relative to build_bd_gcm_dma.tcl:

1. Use AXI_AES_GCM_Ring_wrapper as AES module.
2. Enable fabric interrupt in PS7 config.
3. Connect ring IRQ to PS IRQ_F2P.
4. Expose map0/map1/map2 address ranges for ctrl/tx/rx ring apertures.
5. Keep existing DMA benchmark build script untouched for A/B comparison.

## Step E: add bring-up test script for ring overlay

Create:

- pynq/test_aes_gcm_ring.py

This script should:

1. Load ring overlay bit/hwh.
2. Write key/session settings.
3. Prime test ring descriptors in DDR region.
4. Trigger doorbell.
5. Wait on IRQ/status.
6. Validate descriptor ownership transitions and crypto output/tag behavior.

## 5) Practical first milestone (to de-confuse implementation)

Milestone 1 (minimal risk):

- Keep GcmMode.sv unchanged.
- Implement and validate two-buffer ping-pong handoff first (see ping_pong_frame_contract.md).
- Then implement TX direction ring path in AXI_AES_GCM_Ring.sv.

Milestone 2:

- Add RX direction and tag-verify flow.
- Add full bidirectional validation in ring test script.

## 6) Why existing DecryptPipelined is not the direct answer for GCM RX

DecryptPipelined.sv is AES block decryption rounds. GCM decrypt data path uses CTR keystream XOR (AES encrypt of counter) plus GHASH tag verification over ciphertext.

So for GCM:

- plaintext/ciphertext transform can still use encryption keystream path,
- correctness for RX depends on tag verify integration,
- main work is control/descriptor/ring orchestration, not AES inverse-round replacement.
