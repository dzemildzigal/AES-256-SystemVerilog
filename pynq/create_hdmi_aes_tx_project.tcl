# ──────────────────────────────────────────────────────────────
#  create_hdmi_aes_tx_project.tcl  –  Bootstrap dedicated Vivado
#  project for the PYNQ-Z2 HDMI -> AES -> Ethernet TX path.
#
#  Usage (from Vivado Tcl console):
#    cd <AES-256-SystemVerilog repo root>
#    source pynq/create_hdmi_aes_tx_project.tcl
#
#  Optional dependency hint:
#    set ::env(PYNQ_Z2_BASE_DIR) <path-to-PYNQ>/boards/Pynq-Z2/base
#
#  This script intentionally does not mutate AES_VERILOG.xpr.
#  It creates or opens a separate HDMI_AES_TX project and registers
#  the local AES + frame-writer RTL needed by the upcoming HDMI TX BD.
# ──────────────────────────────────────────────────────────────

set script_dir   [file dirname [file normalize [info script]]]
set repo_root    [file dirname $script_dir]
set project_name "HDMI_AES_TX"
set project_dir  [file join $repo_root $project_name]
set project_xpr  [file join $project_dir "${project_name}.xpr"]
set target_part  "xc7z020clg400-1"

proc detect_pynq_board_part {} {
    set board_parts [get_board_parts -quiet -filter {NAME =~ *pynq*}]
    if {[llength $board_parts] > 0} {
        return [lindex $board_parts 0]
    }
    return ""
}

proc resolve_pynq_base_dir {} {
    if {[info exists ::env(PYNQ_Z2_BASE_DIR)] && $::env(PYNQ_Z2_BASE_DIR) ne ""} {
        return [file normalize $::env(PYNQ_Z2_BASE_DIR)]
    }
    if {[info exists ::PYNQ_Z2_BASE_DIR] && $::PYNQ_Z2_BASE_DIR ne ""} {
        return [file normalize $::PYNQ_Z2_BASE_DIR]
    }
    return ""
}

proc add_hdmi_aes_tx_sources {repo_root} {
    set rtl_dir [file join $repo_root "AES_VERILOG.srcs" "sources_1" "new"]
    set rtl_sources [list \
        [file join $rtl_dir "AES_GCM_Session_Sequencer_wrapper.v"] \
        [file join $rtl_dir "AES_GCM_Session_Sequencer.sv"] \
        [file join $rtl_dir "HDMI_Axis_Packetizer_wrapper.v"] \
        [file join $rtl_dir "HDMI_Axis_Packetizer.sv"] \
        [file join $rtl_dir "AXI_AES_GCM_Stream_wrapper.v"] \
        [file join $rtl_dir "AXI_AES_GCM_Stream.sv"] \
        [file join $rtl_dir "AXI_PingPong_Ctrl_wrapper.v"] \
        [file join $rtl_dir "AXI_PingPong_Ctrl.sv"] \
        [file join $rtl_dir "GcmMode.sv"] \
        [file join $rtl_dir "GHashEngine.sv"] \
        [file join $rtl_dir "GFMult128.sv"] \
        [file join $rtl_dir "KeyExpansion.sv"] \
        [file join $rtl_dir "EncryptPipelined.sv"] \
        [file join $rtl_dir "EncryptionRound.sv"] \
        [file join $rtl_dir "EncryptionInitialRound.sv"] \
        [file join $rtl_dir "EncryptionFinalRound.sv"] \
        [file join $rtl_dir "SubBytes.sv"] \
        [file join $rtl_dir "ShiftRows.sv"] \
        [file join $rtl_dir "MixColumns.sv"] \
        [file join $rtl_dir "MixColumn.sv"] \
        [file join $rtl_dir "XTime.sv"] \
        [file join $rtl_dir "AddRoundKey.sv"] \
    ]

    foreach src $rtl_sources {
        if {[file exists $src]} {
            if {[llength [get_files -quiet $src]] == 0} {
                add_files -norecurse $src
            }
        } else {
            puts "WARNING: Missing local RTL dependency: $src"
        }
    }

    update_compile_order -fileset sources_1
}

set current_project_name ""
catch {
    set current_project_name [get_property NAME [current_project]]
}

if {$current_project_name ne "" && $current_project_name ne $project_name} {
    puts "INFO: Closing currently open project '$current_project_name' before bootstrapping $project_name"
    close_project
}

if {[file exists $project_xpr]} {
    puts "INFO: Opening existing project $project_xpr"
    open_project $project_xpr
} else {
    if {![file exists $project_dir]} {
        file mkdir $project_dir
    }

    puts "INFO: Creating dedicated project $project_name in $project_dir"
    create_project $project_name $project_dir -part $target_part
}

set_property source_mgmt_mode All [current_project]

set pynq_part [detect_pynq_board_part]
if {$pynq_part ne ""} {
    puts "INFO: Setting board_part to $pynq_part"
    set_property board_part $pynq_part [current_project]
} else {
    puts "WARNING: PYNQ-Z2 board files were not discovered in this Vivado installation."
}

add_hdmi_aes_tx_sources $repo_root

set pynq_base_dir [resolve_pynq_base_dir]
if {$pynq_base_dir eq ""} {
    puts "WARNING: PYNQ_Z2_BASE_DIR is not set. HDMI-capable BD generation will fail fast until it points to the official PYNQ boards/Pynq-Z2/base directory."
} else {
    puts "INFO: PYNQ_Z2_BASE_DIR resolved to $pynq_base_dir"
}

puts ""
puts "==========================================================="
puts "  Project bootstrapped: $project_name"
puts "  Project file: $project_xpr"
puts ""
puts "  Local RTL registered: AES stream wrapper + ping-pong writer"
puts "  External dependency pending: official PYNQ-Z2 HDMI base overlay Tcl"
puts ""
puts "  Next steps:"
puts "    1. Set env PYNQ_Z2_BASE_DIR to <PYNQ repo>/boards/Pynq-Z2/base"
puts "    2. Source pynq/build_bd_hdmi_aes_tx.tcl"
puts "    3. Build external HDMI/video dependency IP if required by Vivado catalog"
puts "==========================================================="