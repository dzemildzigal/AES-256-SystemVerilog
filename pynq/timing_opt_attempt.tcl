# One background attempt: place with ExtraTimingOpt + route Explore.
# If WNS >= 0 -> write bitstream; else leave the current bit alone.
cd C:/Users/dzemi/Desktop/PROJECTS/AES-256-SystemVerilog
set dcp "HDMI_AES_TX/HDMI_AES_TX.runs/synth_1/hdmi_aes_tx_wrapper.dcp"
open_checkpoint $dcp
opt_design -directive Explore
place_design -directive ExtraTimingOpt
set pw [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "BG post-place WNS=$pw"
if {$pw >= 0.0} {
    route_design -directive Explore
    report_timing_summary -max_paths 20 -file impl_1_timing_extratimingopt.rpt
    set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
    puts "BG post-route WNS=$wns"
    if {$wns >= 0.0} {
        write_bitstream -force [file normalize "pynq/output/hdmi_aes_tx_100m.bit"]
        puts "BG 100MHZ BIT WRITTEN"
    }
}
close_design
