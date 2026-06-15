open_project "HDMI_AES_TX/HDMI_AES_TX.xpr"
set ::env(PYNQ_Z2_BASE_DIR) "c:/Users/dzemi/Desktop/PROJECTS/PYNQ/boards/Pynq-Z2/base"
source "pynq/build_bd_hdmi_aes_tx.tcl"
reset_run synth_1
reset_run impl_1
launch_runs synth_1 -jobs 16
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 16
wait_on_run impl_1
open_run impl_1
report_timing_summary -max_paths 20 -file impl_1_timing_final_bitgen.rpt
set outdir "pynq/output"
file mkdir $outdir
set bit_src [get_property BITSTREAM.FILE [current_design]]
set hwh_src [file normalize "HDMI_AES_TX/HDMI_AES_TX.gen/sources_1/bd/hdmi_aes_tx/hw_handoff/hdmi_aes_tx.hwh"]
set bit_dst [file normalize "$outdir/hdmi_aes_tx.bit"]
set hwh_dst [file normalize "$outdir/hdmi_aes_tx.hwh"]
file copy -force $bit_src $bit_dst
file copy -force $hwh_src $hwh_dst
puts "ARTIFACT_BIT_SRC=$bit_src"
puts "ARTIFACT_HWH_SRC=$hwh_src"
puts "ARTIFACT_BIT_DST=$bit_dst"
puts "ARTIFACT_HWH_DST=$hwh_dst"
close_project
exit
