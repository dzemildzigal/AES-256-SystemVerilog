# ──────────────────────────────────────────────────────────────
#  rebuild_hdmi_aes_tx.tcl
#
#  One-shot script: create/open the HDMI_AES_TX project, build the
#  hdmi_aes_tx block design from scratch, build the bitstream, and
#  export the .bit/.hwh pair to pynq/output/.
#
#  Run from the Vivado Tcl console:
#    cd C:/Users/dzemi/Desktop/PROJECTS/AES-256-SystemVerilog
#    source pynq/rebuild_hdmi_aes_tx.tcl
#
#  Or from a shell, headless:
#    vivado -mode batch -source pynq/rebuild_hdmi_aes_tx.tcl
# ──────────────────────────────────────────────────────────────

cd C:/Users/dzemi/Desktop/PROJECTS/AES-256-SystemVerilog
set ::env(PYNQ_Z2_BASE_DIR) "C:/Users/dzemi/Desktop/PROJECTS/PYNQ/boards/Pynq-Z2/base"

# 1. Open/create the HDMI_AES_TX project, register local RTL sources.
source pynq/create_hdmi_aes_tx_project.tcl

# 2. Source the BD design - builds it from scratch every time this runs:
#    HDMI in -> packetizer -> sequencer -> AES -> DDR writer, wires clocks/
#    resets/IRQs, validates it, saves it, and sets the wrapper as top.
source pynq/build_bd_hdmi_aes_tx.tcl

# 3. Build the bitstream.
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 16
wait_on_run impl_1

open_run impl_1
report_timing_summary -max_paths 20 -file impl_1_timing_final_bitgen.rpt

# 4. Export artifacts.
set outdir "pynq/output"
file mkdir $outdir
# Use the known, deterministic run output path instead of
# [get_property BITSTREAM.FILE [current_design]] - that property comes back
# empty if current_design isn't pinned to the implemented run at this exact
# point in the session, even though write_bitstream already succeeded on disk.
set bit_src [file normalize "HDMI_AES_TX/HDMI_AES_TX.runs/impl_1/hdmi_aes_tx_wrapper.bit"]
set hwh_src [file normalize "HDMI_AES_TX/HDMI_AES_TX.gen/sources_1/bd/hdmi_aes_tx/hw_handoff/hdmi_aes_tx.hwh"]
if {![file exists $bit_src]} {
    error "Bitstream not found at $bit_src - check runme.log in HDMI_AES_TX/HDMI_AES_TX.runs/impl_1 for a write_bitstream failure."
}
set bit_dst [file normalize "$outdir/hdmi_aes_tx.bit"]
set hwh_dst [file normalize "$outdir/hdmi_aes_tx.hwh"]
file copy -force $bit_src $bit_dst
file copy -force $hwh_src $hwh_dst
puts "ARTIFACT_BIT_DST=$bit_dst"
puts "ARTIFACT_HWH_DST=$hwh_dst"

close_project
