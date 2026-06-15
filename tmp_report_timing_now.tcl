open_project "HDMI_AES_TX/HDMI_AES_TX.xpr"
open_run impl_1
report_timing_summary -max_paths 20 -file impl_1_timing_after_reset_fix.rpt
report_timing -max_paths 10 -sort_by group -file impl_1_worst10_after_reset_fix.rpt
close_project
exit
