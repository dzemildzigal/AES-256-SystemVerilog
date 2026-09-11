# ──────────────────────────────────────────────────────────────
#  impl_retry.tcl
#
#  Get a timing-clean implementation without re-synthesising.
#
#  Why this exists: builds of this design miss timing by fractions of a
#  nanosecond on the GHASH GF-multiply path, with 80%+ of the delay in routing.
#  That is a placement/routing outcome, not a logic problem, so it is worth
#  retrying implementation instead of changing RTL.
#
#  Attempt 1 (proven on 2026-09-12: turned a -0.067 ns miss into +0.013 ns):
#  open the failing run's routed checkpoint and apply post-route physical
#  optimisation, which targets exactly the near-critical paths that miss by a
#  fraction of a nanosecond.
#
#  Fallback: re-implement through the run system with a timing-oriented
#  strategy. Placement must go through the run system: calling place_design
#  directly aborts with
#      ERROR: [Place 30-99] Placer failed with error: 'IO Clock Placer failed'
#  because two BUFGs require cyclically adjacent sites and only the run
#  system's clock placement satisfies that.
#
#  Vivado 2024.1 note: place_design has no -seed option, which is why the older
#  seed_sweep_impl.tcl could never work.
#
#  Run: vivado -mode batch -source pynq/impl_retry.tcl
# ──────────────────────────────────────────────────────────────
cd C:/Users/dzemi/Desktop/PROJECTS/AES-256-SystemVerilog

set project "HDMI_AES_TX/HDMI_AES_TX.xpr"
set routed  "HDMI_AES_TX/HDMI_AES_TX.runs/impl_1/hdmi_aes_tx_wrapper_routed.dcp"
set hwh_src "HDMI_AES_TX/HDMI_AES_TX.gen/sources_1/bd/hdmi_aes_tx/hw_handoff/hdmi_aes_tx.hwh"

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
    puts "===== ATTEMPT 2: re-implement through the run system ====="
    open_project $project
    set_property strategy Performance_ExtraTimingOpt [get_runs impl_1]
    reset_run impl_1
    launch_runs impl_1 -to_step write_bitstream -jobs 16
    wait_on_run impl_1
    open_run impl_1
    report_timing_summary -max_paths 20 -file impl_1_timing_retry2.rpt
    set wns [wns_now]
    puts "ATTEMPT 2 post-route WNS=$wns"
    if {$wns >= 0.0} {
        write_artifacts 2 $wns
    } else {
        puts "NO_ATTEMPT_MET_TIMING best_wns=$wns"
        error "no attempt met timing"
    }
}
puts "IMPL_RETRY_DONE wns=$wns"
