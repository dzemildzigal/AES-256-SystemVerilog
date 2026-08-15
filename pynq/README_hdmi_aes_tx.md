# HDMI AES TX Project Scaffold

This document is the build contract for the dedicated PYNQ-Z2 HDMI -> AES -> Ethernet TX hardware effort.

**Status note (post-scaffold):** the block design now has the real HDMI chain wired in
(dvi2rgb -> color_swap -> v_vid_in_axi4s -> CDC FIFO -> `hdmi_packetizer_0` -> `aes_seq_0` ->
`aes_gcm_0` -> `frame_writer_0`, with IRQs routed to PS7). The "Scope Of This Scaffold" and
"What The BD Scaffold Creates" sections below describe the *original* placeholder state
(`pkt_pt_axis_in`) and are kept for history. Do not treat them as the current state; treat
the build script (`build_bd_hdmi_aes_tx.tcl`) as the source of truth, since it is
regenerated fresh every time it runs.

The goal of this project is not to mutate the validated `AES_VERILOG.xpr` DMA benchmark path in place. Instead, it bootstraps a separate Vivado project named `HDMI_AES_TX` and a separate block design named `hdmi_aes_tx` so HDMI/video work, packetization work, and timing-closure risk stay isolated from the known-good AES DMA baseline.

## Scope Of This Scaffold

This first scaffold implements the following pieces:

- a dedicated Vivado project bootstrap script
- a dedicated block design scaffold
- reuse of existing AES-GCM stream RTL and DDR writer RTL
- a packet-plaintext AXI-Stream insertion point named `pkt_pt_axis_in`

This first scaffold does **not** yet implement:

- the PYNQ-Z2 HDMI subsystem wiring inside the block design
- the PL video-to-packet packetizer
- the TX ring writer that will hand packet-ready datagrams to the PS sender

## Files Added For This Effort

- `pynq/create_hdmi_aes_tx_project.tcl`
- `pynq/build_bd_hdmi_aes_tx.tcl`

## External Dependency Contract

The HDMI subsystem for PYNQ-Z2 is not contained in this repository snapshot.

Before sourcing the BD scaffold, set:

- `PYNQ_Z2_BASE_DIR=<path-to-PYNQ>/boards/Pynq-Z2/base`

The build scripts expect the following files to exist in that directory:

- `build_base_ip.tcl`
- `base.tcl`

The Vivado catalog must also expose these HDMI-relevant IP blocks:

- `digilentinc.com:ip:dvi2rgb:1.7`
- `xilinx.com:ip:v_vid_in_axi4s:5.0`
- `xilinx.com:ip:v_tc:6.2`

## How To Rebuild (recommended: one-shot script)

`pynq/rebuild_hdmi_aes_tx.tcl` does the whole thing: open/create the project, source
(build) the BD from scratch, run synth+impl+bitgen, and export `hdmi_aes_tx.bit/.hwh` to
`pynq/output/`. This is the current recommended path, not the manual steps below.

**From the Vivado Tcl console** (interactive, first/most common way to run it):

```tcl
cd C:/Users/dzemi/Desktop/PROJECTS/AES-256-SystemVerilog
source pynq/rebuild_hdmi_aes_tx.tcl
```

**Headless, from a shell, no GUI** (same script, no Vivado window needed):

```bash
vivado -mode batch -source pynq/rebuild_hdmi_aes_tx.tcl
```

`PYNQ_Z2_BASE_DIR` is already set inside the script
(`C:/Users/dzemi/Desktop/PROJECTS/PYNQ/boards/Pynq-Z2/base` on this machine); edit that
line in the script if the PYNQ board-files checkout ever moves.

## How To Start In Vivado (manual, step-by-step - what the one-shot script runs)

From the `AES-256-SystemVerilog` repository root in Vivado Tcl console:

```tcl
source pynq/create_hdmi_aes_tx_project.tcl
set ::env(PYNQ_Z2_BASE_DIR) <path-to-PYNQ>/boards/Pynq-Z2/base
source pynq/build_bd_hdmi_aes_tx.tcl
```

This only builds the BD. It does not run synthesis/implementation/bitgen or export
artifacts - use the one-shot script above for that, or run `reset_run impl_1;
launch_runs impl_1 -to_step write_bitstream` manually afterward.

## What The BD Scaffold Creates

`build_bd_hdmi_aes_tx.tcl` currently creates:

- `ps7`
- `aes_gcm_0` from `AXI_AES_GCM_Stream_wrapper`
- `frame_writer_0` from `AXI_PingPong_Ctrl_wrapper`
- GP0 AXI-Lite control connectivity
- HP0 DDR write connectivity for the existing frame-writer path
- external AXI-Stream slave port `pkt_pt_axis_in`
- external port `frame_writer_irq`

Current stream scaffold:

- `pkt_pt_axis_in -> aes_gcm_0/S_AXIS_PT`
- `aes_gcm_0/M_AXIS_CT -> frame_writer_0/S_AXIS_SRC`

This is intentionally a **packet plaintext insertion point**, not a final HDMI data path.

## Planned Output Artifact Name

The intended OS-VideoSDR deployment artifact for the TX overlay is:

- `hdmi_aes_tx_wrapper.bit`
- `hdmi_aes_tx_wrapper.hwh`

Intended board deployment path:

- `/home/xilinx/jupyter_notebooks/OS-VideoSDR/pynq/overlays/tx/hdmi_aes_tx_wrapper.bit`
- `/home/xilinx/jupyter_notebooks/OS-VideoSDR/pynq/overlays/tx/hdmi_aes_tx_wrapper.hwh`

## Immediate Next Hardware Steps

1. Vendor/pin the official PYNQ-Z2 base overlay source used for HDMI IP and Tcl generation.
2. Create the HDMI subsystem import layer inside `build_bd_hdmi_aes_tx.tcl`.
3. Add the PL video-to-packetizer block that converts HDMI video into the existing OS-VideoSDR packet plaintext contract.
4. Replace or extend the current DDR writer scaffold with a packet-ready TX ring writer compatible with the PS shim sender path.
5. Preserve the current protocol contract so the unchanged PC RX stack remains the acceptance oracle.