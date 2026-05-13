# ──────────────────────────────────────────────────────────────
#  build_bd_gcm_ping_pong.tcl  –  Create PYNQ Z2 block design
#                                for phase-1 ping-pong control + DDR writer path.
#
#  Usage (Vivado Tcl console):
#    open_project AES_VERILOG.xpr
#    source pynq/build_bd_gcm_ping_pong.tcl
#
#  This first implementation slice builds and validates map0 control logic.
#  This version keeps map0 control logic and adds deterministic DDR write path.
# ──────────────────────────────────────────────────────────────

set PP_MODULE  "AXI_PingPong_Ctrl_wrapper"
set PP_INST    "aes_pingpong_0"
set BD_NAME    "aes_gcm_ping_pong"

# ── 1. Create block design (re-runnable cleanup) ─────────────
set bd_src_dir  "AES_VERILOG.srcs/sources_1/bd/${BD_NAME}"
set bd_src_file "AES_VERILOG.srcs/sources_1/bd/${BD_NAME}/${BD_NAME}.bd"
set bd_gen_file "AES_VERILOG.gen/sources_1/bd/${BD_NAME}/${BD_NAME}.bd"
set bd_gen_dir  "AES_VERILOG.gen/sources_1/bd/${BD_NAME}"

set existing_bd [get_bd_designs -quiet $BD_NAME]
set existing_bd_files [get_files -quiet "*/${BD_NAME}.bd"]

if {[llength $existing_bd] > 0 || [llength $existing_bd_files] > 0 || [file exists $bd_src_file]} {
    puts "INFO: Existing block design '$BD_NAME' found; removing it."
}

set current_bd ""
catch {set current_bd [current_bd_design -quiet]}
if {$current_bd eq $BD_NAME} {
    catch {close_bd_design $current_bd}
}

foreach d $existing_bd {
    catch {close_bd_design $d}
}

if {[llength $existing_bd_files] > 0} {
    catch {remove_files $existing_bd_files}
}

if {[file exists $bd_src_file]} {
    catch {file delete -force $bd_src_file}
}
if {[file exists $bd_src_dir]} {
    catch {file delete -force $bd_src_dir}
}
if {[file exists $bd_gen_file]} {
    catch {file delete -force $bd_gen_file}
}
if {[file exists $bd_gen_dir]} {
    catch {file delete -force $bd_gen_dir}
}

if {[catch {create_bd_design $BD_NAME} create_err]} {
    puts "WARNING: create_bd_design failed once (${create_err}); retrying after cleanup."
    foreach d [get_bd_designs -quiet $BD_NAME] {
        catch {close_bd_design $d}
    }
    set retry_files [get_files -quiet "*/${BD_NAME}.bd"]
    if {[llength $retry_files] > 0} {
        catch {remove_files $retry_files}
    }
    catch {file delete -force $bd_src_dir}
    catch {file delete -force $bd_src_file}
    catch {file delete -force $bd_gen_file}
    catch {file delete -force $bd_gen_dir}
    create_bd_design $BD_NAME
}

# ── 2. Set board part ────────────────────────────────────────
set pynq_parts [get_board_parts -filter {NAME =~ *pynq*}]
if {[llength $pynq_parts] > 0} {
    set pynq_part [lindex $pynq_parts 0]
    puts "INFO: Setting board_part to $pynq_part"
    set_property board_part $pynq_part [current_project]
} else {
    puts "WARNING: PYNQ-Z2 board files not found."
}

# ── 3. Add Zynq PS ──────────────────────────────────────────
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7
set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {0} \
] [get_bd_cells ps7]

# ── 4. Add ping-pong module reference and sources ───────────
set_property source_mgmt_mode All [current_project]

set rtl_dir "AES_VERILOG.srcs/sources_1/new"
set pp_sources [list \
    "$rtl_dir/AXI_PingPong_Ctrl_wrapper.v" \
    "$rtl_dir/AXI_PingPong_Ctrl.sv" \
]

foreach f $pp_sources {
    if {[file exists $f]} {
        if {[llength [get_files -quiet $f]] == 0} {
            add_files -norecurse $f
        }
    } else {
        puts "WARNING: Missing source file: $f"
    }
}

update_compile_order -fileset sources_1

create_bd_cell -type module -reference $PP_MODULE $PP_INST

# ── 5. Run automation + connect AXI-Lite control ───────────
set pp_s_axi_path "/${PP_INST}/S_AXI"
if {[llength [get_bd_intf_pins -quiet $pp_s_axi_path]] == 0} {
    set pp_s_axi_path "/${PP_INST}/s_axi"
}
set pp_s_axi_pin [get_bd_intf_pins -quiet $pp_s_axi_path]
if {[llength $pp_s_axi_pin] == 0} {
    error "Unable to resolve AXI-Lite slave interface for $PP_INST"
}

apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable"} \
    [get_bd_cells ps7]

set ps_fclk0_pin       [get_bd_pins ps7/FCLK_CLK0]
set ps_fclk_resetn_pin [get_bd_pins ps7/FCLK_RESET0_N]

set axi4_cfg [list \
    Clk_master {/ps7/FCLK_CLK0 (100 MHz)} \
    Clk_slave  {Auto} \
    Clk_xbar   {Auto} \
    Master     {/ps7/M_AXI_GP0} \
    Slave      $pp_s_axi_path \
    ddr_seg    {Auto} \
    intc_ip    {New AXI Interconnect} \
    master_apm {0} \
]

if {[catch {
    apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config $axi4_cfg $pp_s_axi_pin
} axi_auto_err]} {
    puts "WARNING: AXI automation for $pp_s_axi_path failed: $axi_auto_err"
    puts "WARNING: Falling back to explicit GP0 control interconnect wiring."

    set ctrl_ic_name "gp0_ctrl_ic"
    if {[llength [get_bd_cells -quiet $ctrl_ic_name]] == 0} {
        create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 $ctrl_ic_name
        set_property -dict [list \
            CONFIG.NUM_MI {1} \
            CONFIG.NUM_SI {1} \
        ] [get_bd_cells $ctrl_ic_name]
    }

    connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins ${ctrl_ic_name}/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins ${ctrl_ic_name}/M00_AXI] $pp_s_axi_pin

    foreach p [list \
        [get_bd_pins ${ctrl_ic_name}/ACLK] \
        [get_bd_pins ${ctrl_ic_name}/S00_ACLK] \
        [get_bd_pins ${ctrl_ic_name}/M00_ACLK] \
    ] {
        if {[llength [get_bd_nets -quiet -of_objects $p]] == 0} {
            connect_bd_net $ps_fclk0_pin $p
        }
    }

    foreach p [list \
        [get_bd_pins ${ctrl_ic_name}/ARESETN] \
        [get_bd_pins ${ctrl_ic_name}/S00_ARESETN] \
        [get_bd_pins ${ctrl_ic_name}/M00_ARESETN] \
    ] {
        if {[llength [get_bd_nets -quiet -of_objects $p]] == 0} {
            connect_bd_net $ps_fclk_resetn_pin $p
        }
    }

    set pp_aclk_pin [get_bd_pins -quiet ${PP_INST}/S_AXI_ACLK]
    if {[llength $pp_aclk_pin] == 0} {
        set pp_aclk_pin [get_bd_pins ${PP_INST}/s_axi_aclk]
    }
    if {[llength [get_bd_nets -quiet -of_objects $pp_aclk_pin]] == 0} {
        connect_bd_net $ps_fclk0_pin $pp_aclk_pin
    }

    set pp_aresetn_pin [get_bd_pins -quiet ${PP_INST}/S_AXI_ARESETN]
    if {[llength $pp_aresetn_pin] == 0} {
        set pp_aresetn_pin [get_bd_pins ${PP_INST}/s_axi_aresetn]
    }
    if {[llength [get_bd_nets -quiet -of_objects $pp_aresetn_pin]] == 0} {
        connect_bd_net $ps_fclk_resetn_pin $pp_aresetn_pin
    }
}

# DDR write path: $PP_INST/M_AXI -> hp0_mem_ic -> ps7/S_AXI_HP0
set pp_m_axi_pin [get_bd_intf_pins -quiet $PP_INST/m_axi]
if {[llength $pp_m_axi_pin] == 0} {
    set pp_m_axi_pin [get_bd_intf_pins $PP_INST/M_AXI]
}

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 hp0_mem_ic
set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {1} \
] [get_bd_cells hp0_mem_ic]

connect_bd_intf_net $pp_m_axi_pin [get_bd_intf_pins hp0_mem_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins hp0_mem_ic/M00_AXI] [get_bd_intf_pins ps7/S_AXI_HP0]

set ps_hp0_aclk_pin [get_bd_pins ps7/S_AXI_HP0_ACLK]
if {[llength [get_bd_nets -quiet -of_objects $ps_hp0_aclk_pin]] == 0} {
    connect_bd_net $ps_fclk0_pin $ps_hp0_aclk_pin
}

foreach p [list \
    [get_bd_pins hp0_mem_ic/ACLK] \
    [get_bd_pins hp0_mem_ic/S00_ACLK] \
    [get_bd_pins hp0_mem_ic/M00_ACLK] \
] {
    if {[llength [get_bd_nets -quiet -of_objects $p]] == 0} {
        connect_bd_net $ps_fclk0_pin $p
    }
}

foreach p [list \
    [get_bd_pins hp0_mem_ic/ARESETN] \
    [get_bd_pins hp0_mem_ic/S00_ARESETN] \
    [get_bd_pins hp0_mem_ic/M00_ARESETN] \
] {
    if {[llength [get_bd_nets -quiet -of_objects $p]] == 0} {
        connect_bd_net $ps_fclk_resetn_pin $p
    }
}

assign_bd_address

# ── 6. Validate and save ─────────────────────────────────────
regenerate_bd_layout
validate_bd_design
save_bd_design

set bd_files [get_files -quiet "*/${BD_NAME}.bd"]
if {[llength $bd_files] > 0} {
    set_property synth_checkpoint_mode None $bd_files
}

# Force IP/BD targets so module-reference XCI paths are materialized
# before launching synth/impl runs.
set bd_obj [get_files -quiet ${BD_NAME}.bd]
if {[llength $bd_obj] > 0} {
    generate_target all $bd_obj
    catch {export_ip_user_files -of_objects $bd_obj -no_script -sync -force -quiet}
}

# ── 7. Create HDL wrapper ────────────────────────────────────
make_wrapper -files $bd_obj -top
set wrapper_path [file normalize [glob AES_VERILOG.gen/sources_1/bd/${BD_NAME}/hdl/${BD_NAME}_wrapper.v]]
if {[llength [get_files -quiet $wrapper_path]] == 0} {
    add_files -norecurse $wrapper_path
}

# Use manual compile order when pinning top to avoid auto-update races.
set_property source_mgmt_mode None [current_project]
update_compile_order -fileset sources_1

# Avoid stale incremental checkpoint carry-over from prior top-level designs.
if {[llength [get_runs -quiet synth_1]] > 0} {
    # Some Vivado builds expect numeric boolean for this run property.
    if {[catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]}]} {
        catch {set_property AUTO_INCREMENTAL_CHECKPOINT false [get_runs synth_1]}
    }
    set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
}

# ── 8. Set wrapper as synthesis top ──────────────────────────
set_property top ${BD_NAME}_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Restore automatic hierarchy updates so other module-reference IP in this
# multi-design project resolve correctly.
set_property source_mgmt_mode All [current_project]
update_compile_order -fileset sources_1

puts ""
puts "==========================================================="
puts "  Block design created: $BD_NAME"
puts "  Top module: ${BD_NAME}_wrapper"
puts ""
puts "  Next steps:"
puts "    1. launch_runs synth_1 -jobs 16"
puts "    2. wait_on_run synth_1"
puts "    3. launch_runs impl_1 -to_step write_bitstream -jobs 16"
puts "    4. wait_on_run impl_1"
puts "    5. Copy .bit + .hwh to PYNQ board"
puts "       (see pynq/test_ping_pong_ctrl.py)"
puts "==========================================================="
