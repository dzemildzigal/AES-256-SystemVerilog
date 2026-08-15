open_project "HDMI_AES_TX/HDMI_AES_TX.xpr"
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
open_run impl_1
report_timing_summary -max_paths 20 -file impl_1_timing_final_bitgen.rpt
close_project
exit
