# In-memory seed sweep on the synth checkpoint. The run object in
# Vivado 2024.1 exposes no SEED property, so drive place_design/route_design
# directly with -seed and stop at the first timing-clean result.
cd C:/Users/dzemi/Desktop/PROJECTS/AES-256-SystemVerilog
set dcp "HDMI_AES_TX/HDMI_AES_TX.runs/synth_1/hdmi_aes_tx_wrapper.dcp"
set outdir "pynq/output"

foreach seed {2 3 5 7 11 13} {
    puts "===== SEED $seed ====="
    open_checkpoint $dcp
    opt_design
    place_design -directive Explore -seed $seed
    set place_wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
    puts "SEED $seed post-place WNS=$place_wns"
    if {$place_wns < -1.0} {
        puts "SEED $seed place too negative, next"
        close_design
        continue
    }
    route_design -directive Explore
    report_timing_summary -max_paths 20 -file "impl_1_timing_seed${seed}.rpt"
    set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
    puts "SEED $seed post-route WNS=$wns"
    if {$wns >= 0.0} {
        puts "=== SEED $seed MET TIMING -> bitstream ==="
        write_bitstream -force [file normalize "$outdir/hdmi_aes_tx.bit"]
        set hwh_src [file normalize "HDMI_AES_TX/HDMI_AES_TX.gen/sources_1/bd/hdmi_aes_tx/hw_handoff/hdmi_aes_tx.hwh"]
        file copy -force $hwh_src [file normalize "$outdir/hdmi_aes_tx.hwh"]
        puts "ARTIFACTS WRITTEN"
        close_design
        break
    }
    close_design
}
if {![info exists wns] || $wns < 0.0} {
    error "no seed met timing"
}
