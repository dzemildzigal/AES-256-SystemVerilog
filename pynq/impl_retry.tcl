# ──────────────────────────────────────────────────────────────
#  impl_retry.tcl
#
#  Get a timing-clean implementation without re-synthesising.
#
#  Why this exists: the 1408-byte-slot build missed timing by 0.067 ns on the
#  GHASH GF-multiply path with 82% of the delay in routing, which is a
#  placement/routing result, not a logic problem. The older
#  seed_sweep_impl.tcl could not help: Vivado 2024.1 place_design has no -seed
#  option and aborted with "Unknown option '-seed'". This script walks
#  directives instead.
#
#  Attempt 1 is cheap: open the routed checkpoint of the failing run and apply
#  post-route physical optimisation, which targets exactly the near-critical
#  paths that miss by a fraction of a nanosecond. Attempts 2..4 re-place and
#  re-route from the synthesis checkpoint with other directives.
#
#  The first attempt that reaches WNS >= 0 writes the bitstream and copies the
#  handoff into pynq/output/.
#
#  Run: vivado -mode batch -source pynq/impl_retry.tcl
# ──────────────────────────────────────────────────────────────
cd C:/Users/dzemi/Desktop/PROJECTS/AES-256-SystemVerilog

set routed  "HDMI_AES_TX/HDMI_AES_TX.runs/impl_1/hdmi_aes_tx_wrapper_routed.dcp"
set synth   "HDMI_AES_TX/HDMI_AES_TX.runs/synth_1/hdmi_aes_tx_wrapper.dcp"
set hwh_src "HDMI_AES_TX/HDMI_AES_TX.gen/sources_1/bd/hdmi_aes_tx/hw_handoff/hdmi_aes_tx.hwh"
set bit_dst "pynq/output/hdmi_aes_tx.bit"
set hwh_dst "pynq/output/hdmi_aes_tx.hwh"

proc wns_now {} {
    return [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
}

proc write_artifacts {attempt wns} {
    write_bitstream -force [file normalize "pynq/output/hdmi_aes_tx.bit"]
    file copy -force [file normalize "HDMI_AES_TX/HDMI_AES_TX.gen/sources_1/bd/hdmi_aes_tx/hw_handoff/hdmi_aes_tx.hwh"] \
                     [file normalize "pynq/output/hdmi_aes_tx.hwh"]
    puts "ARTIFACTS WRITTEN attempt=$attempt wns=$wns"
}

# ── attempt 1: post-route physical optimisation on the routed checkpoint ──
puts "===== ATTEMPT 1: post-route phys_opt + reroute ====="
open_checkpoint $routed
phys_opt_design -directive AggressiveExplore
route_design -directive AggressiveExplore
report_timing_summary -max_paths 20 -file impl_1_timing_retry1.rpt
set wns [wns_now]
puts "ATTEMPT 1 post-route WNS=$wns"

if {$wns >= 0.0} {
    write_artifacts 1 $wns
    close_design
} else {
    close_design

    # ── attempts 2..4: fresh place + route with other directives ──
    set attempts {
        {Explore AggressiveExplore AggressiveExplore}
        {ExtraTimingOpt Explore AggressiveExplore}
        {AltSpreadLogic_high NoTimingRelaxation Explore}
    }
    set idx 1
    set best $wns
    foreach a $attempts {
        incr idx
        set pdir [lindex $a 0]
        set fdir [lindex $a 1]
        set rdir [lindex $a 2]
        puts "===== ATTEMPT $idx: place=$pdir phys=$fdir route=$rdir ====="
        open_checkpoint $synth
        opt_design
        place_design -directive $pdir
        phys_opt_design -directive $fdir
        route_design -directive $rdir
        phys_opt_design -directive $fdir
        report_timing_summary -max_paths 20 -file "impl_1_timing_retry${idx}.rpt"
        set wns [wns_now]
        puts "ATTEMPT $idx post-route WNS=$wns"
        if {$wns > $best} {
            set best $wns
        }
        if {$wns >= 0.0} {
            write_artifacts $idx $wns
            close_design
            break
        }
        close_design
    }

    if {$best < 0.0} {
        puts "NO_ATTEMPT_MET_TIMING best_wns=$best"
        error "no attempt met timing"
    }
}
puts "IMPL_RETRY_DONE wns=$wns"
