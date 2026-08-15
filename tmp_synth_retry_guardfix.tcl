open_project "HDMI_AES_TX/HDMI_AES_TX.xpr"
reset_run synth_1
set_property incremental_checkpoint "" [get_runs synth_1]
launch_runs synth_1 -jobs 1
wait_on_run synth_1
close_project
exit
