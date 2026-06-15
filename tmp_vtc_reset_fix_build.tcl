open_project "HDMI_AES_TX/HDMI_AES_TX.xpr"
set ::env(PYNQ_Z2_BASE_DIR) "c:/Users/dzemi/Desktop/PROJECTS/PYNQ/boards/Pynq-Z2/base"
source "pynq/build_bd_hdmi_aes_tx.tcl"
reset_run synth_1
reset_run impl_1
launch_runs synth_1 -jobs 16
wait_on_run synth_1
launch_runs impl_1 -to_step route_design -jobs 16
wait_on_run impl_1
open_run impl_1
report_timing_summary -max_paths 20 -file impl_1_timing_after_vtc_reset_fix.rpt
close_project
exit
