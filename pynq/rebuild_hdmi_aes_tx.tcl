# ──────────────────────────────────────────────────────────────
#  rebuild_hdmi_aes_tx.tcl
#
#  One-shot script: create/open the HDMI_AES_TX project, build the
#  hdmi_aes_tx block design from scratch, build the bitstream via the RUN
#  system (it performs BD output generation + top resolution correctly),
#  and export the .bit/.hwh pair to pynq/output/.
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

# 2. Rebuild the BD from scratch (HDMI in -> packetizer -> sequencer -> AES ->
#    DDR writer, clocks/resets/IRQs, validate, save, wrapper).
source pynq/build_bd_hdmi_aes_tx.tcl

# 3. Build the bitstream through the run system. Reset BOTH runs so nothing
#    stale is reused, and disable incremental compilation: a stale incremental
#    checkpoint from an old wrong-top run (AES_GCM_Session_Sequencer_wrapper.dcp
#    in utils_1/imports/synth_1) makes the run die instantly at launch.
catch {reset_run synth_1}
catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]}
catch {set_property INCREMENTAL_CHECKPOINT {} [get_runs synth_1]}
catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]}
catch {set_property INCREMENTAL_CHECKPOINT {} [get_runs impl_1]}
catch {file delete -force "HDMI_AES_TX/HDMI_AES_TX.srcs/utils_1/imports/synth_1"}
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 16
wait_on_run impl_1

# Vivado 2024.1 sometimes crashes (EXCEPTION_ACCESS_VIOLATION) during the
# run's write_bitstream step even though routing completed fine. Fall back to
# in-memory bitgen from the routed checkpoint - works in both cases.
open_run impl_1
report_timing_summary -max_paths 20 -file impl_1_timing_final_bitgen.rpt
write_bitstream -force pynq/output/hdmi_aes_tx.bit

# 4. Export artifacts (bitstream already written by step 3's in-memory bitgen).
set outdir "pynq/output"
file mkdir $outdir
set hwh_src [file normalize "HDMI_AES_TX/HDMI_AES_TX.gen/sources_1/bd/hdmi_aes_tx/hw_handoff/hdmi_aes_tx.hwh"]
if {![file exists $hwh_src]} {
    error "HWH not found at $hwh_src"
}
set bit_dst [file normalize "$outdir/hdmi_aes_tx.bit"]
set hwh_dst [file normalize "$outdir/hdmi_aes_tx.hwh"]
file copy -force $hwh_src $hwh_dst
puts "ARTIFACT_BIT_DST=$bit_dst"
puts "ARTIFACT_HWH_DST=$hwh_dst"

close_project
