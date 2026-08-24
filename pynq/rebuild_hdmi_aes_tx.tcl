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
puts "======================================================"
puts "=== STEP 1: OPEN/CREATE PROJECT ==="
puts "======================================================"
source pynq/create_hdmi_aes_tx_project.tcl

# 2. Rebuild the BD from scratch (HDMI in -> packetizer -> sequencer -> AES ->
#    nonce injector -> padded DDR ring writer, clocks/resets/IRQs, validate,
#    save, wrapper).
puts "=== STEP 2: REBUILD BLOCK DESIGN ==="
source pynq/build_bd_hdmi_aes_tx.tcl
puts "=== block design ready ==="

# 3. Build the bitstream through the run system, WITH checkpoint reuse:
#    - if synth_1 already completed successfully, reuse that checkpoint and
#      only re-run impl_1
#    - otherwise reset and re-run from synthesis
#    - incremental compilation stays disabled (a stale incremental checkpoint
#      from an old wrong-top run killed the run instantly before)
puts "======================================================"
puts "=== STEP 3: SYNTHESIS + IMPLEMENTATION + BITGEN ==="
puts "======================================================"
catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]}
catch {set_property INCREMENTAL_CHECKPOINT {} [get_runs synth_1]}
catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1]}
catch {set_property INCREMENTAL_CHECKPOINT {} [get_runs impl_1]}
# Try harder by default: the GHASH 128-bit GF multiply path in the AES core sits
# ~9.8/10ns at 100MHz and flips with placement variance. Explore directives give
# systematically better QoR. (Proper fix = pipeline GHASH; see pynq/README notes.)
catch {set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]}
catch {set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]}
catch {file delete -force "HDMI_AES_TX/HDMI_AES_TX.srcs/utils_1/imports/synth_1"}

set synth_done 0
# The BD regen changes the generated IP instance suffixes every run, so a
# reused synth checkpoint can silently mismatch the fresh BD (stale module
# names -> IP clock XDCs never read -> broken timing + placement). Always
# run the full synthesis: correct over fast.
puts "=== running FULL synthesis (BD regen invalidates any checkpoint) ==="
catch {reset_run synth_1}
puts "=== launching impl_1 (synth + place + route + bitgen)... ==="
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 16
wait_on_run impl_1
puts "=== run finished ==="

# Vivado 2024.1 sometimes crashes (EXCEPTION_ACCESS_VIOLATION) during the
# run's write_bitstream step even though routing completed fine. Fall back to
# in-memory bitgen from the routed checkpoint - works in both cases.
puts "=== opening routed design ==="
open_run impl_1
puts "=== report_timing_summary ==="
report_timing_summary -max_paths 20 -file impl_1_timing_final_bitgen.rpt
puts "=== write_bitstream (in-memory, crash-safe) ==="
write_bitstream -force pynq/output/hdmi_aes_tx.bit

# 4. Export artifacts (bitstream already written by step 3's in-memory bitgen).
puts "=== STEP 4: EXPORT ARTIFACTS ==="
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
