# ──────────────────────────────────────────────────────────────
#  build_bd_gcm_ping_pong.tcl  –  Create PYNQ Z2 block design
#                                for ping-pong DDR writer + AES stream source path.
#
#  Usage (Vivado Tcl console):
#    open_project AES_VERILOG.xpr
#    source pynq/build_bd_gcm_ping_pong.tcl
#
#  This implementation keeps deterministic writer mode and adds stream mode:
#    AXI DMA MM2S -> AXI_AES_GCM_Stream -> AXI_PingPong_Ctrl -> DDR (HP0)
# ──────────────────────────────────────────────────────────────

set PP_MODULE  "AXI_PingPong_Ctrl_wrapper"
set PP_INST    "aes_pingpong_0"
set AES_MODULE "AXI_AES_GCM_Stream_wrapper"
set AES_INST   "aes_gcm_0"
set DMA_INST   "axi_dma_0"
set BD_NAME    "aes_gcm_ping_pong"

# Keep a known-valid RTL top while rebuilding BD artifacts.
catch {
    set_property top Top [current_fileset]
    update_compile_order -fileset sources_1
}

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

# ── 4. Add module references and RTL dependencies ───────────
set_property source_mgmt_mode All [current_project]

proc first_existing_intf_pin {candidates} {
    foreach c $candidates {
        set p [get_bd_intf_pins -quiet $c]
        if {[llength $p] > 0} {
            return $p
        }
    }
    return ""
}

proc first_existing_pin {candidates} {
    foreach c $candidates {
        set p [get_bd_pins -quiet $c]
        if {[llength $p] > 0} {
            return $p
        }
    }
    return ""
}

set rtl_dir "AES_VERILOG.srcs/sources_1/new"
set pp_sources [list \
    "$rtl_dir/AXI_PingPong_Ctrl_wrapper.v" \
    "$rtl_dir/AXI_PingPong_Ctrl.sv" \
]

set aes_sources [list \
    "$rtl_dir/AXI_AES_GCM_Stream_wrapper.v" \
    "$rtl_dir/AXI_AES_GCM_Stream.sv" \
    "$rtl_dir/GcmMode.sv" \
    "$rtl_dir/GHashEngine.sv" \
    "$rtl_dir/GFMult128.sv" \
    "$rtl_dir/KeyExpansion.sv" \
    "$rtl_dir/EncryptPipelined.sv" \
    "$rtl_dir/EncryptionRound.sv" \
    "$rtl_dir/EncryptionInitialRound.sv" \
    "$rtl_dir/EncryptionFinalRound.sv" \
    "$rtl_dir/SubBytes.sv" \
    "$rtl_dir/ShiftRows.sv" \
    "$rtl_dir/MixColumns.sv" \
    "$rtl_dir/MixColumn.sv" \
    "$rtl_dir/XTime.sv" \
    "$rtl_dir/AddRoundKey.sv" \
]

set all_sources [concat $pp_sources $aes_sources]

foreach f $all_sources {
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
create_bd_cell -type module -reference $AES_MODULE $AES_INST
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 $DMA_INST

set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_include_mm2s {1} \
    CONFIG.c_include_s2mm {0} \
    CONFIG.c_m_axi_mm2s_data_width {128} \
    CONFIG.c_m_axis_mm2s_tdata_width {128} \
    CONFIG.c_mm2s_burst_size {256} \
] [get_bd_cells $DMA_INST]

# ── 5. Run base automation + explicit AXI/control/data wiring ──
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable"} \
    [get_bd_cells ps7]

set ps_fclk0_pin       [get_bd_pins ps7/FCLK_CLK0]
set ps_fclk_resetn_pin [get_bd_pins ps7/FCLK_RESET0_N]
set ps_gp0_aclk_pin    [get_bd_pins -quiet ps7/M_AXI_GP0_ACLK]

if {[llength $ps_gp0_aclk_pin] > 0 && [llength [get_bd_nets -quiet -of_objects $ps_gp0_aclk_pin]] == 0} {
    connect_bd_net $ps_fclk0_pin $ps_gp0_aclk_pin
}

set pp_s_axi_pin [first_existing_intf_pin [list "/${PP_INST}/S_AXI" "/${PP_INST}/s_axi"]]
set aes_s_axi_pin [first_existing_intf_pin [list "/${AES_INST}/S_AXI" "/${AES_INST}/s_axi"]]

if {$pp_s_axi_pin eq ""} {
    error "Unable to resolve AXI-Lite slave interface for $PP_INST"
}
if {$aes_s_axi_pin eq ""} {
    error "Unable to resolve AXI-Lite slave interface for $AES_INST"
}

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 gp0_ctrl_ic
set_property -dict [list \
    CONFIG.NUM_MI {3} \
    CONFIG.NUM_SI {1} \
] [get_bd_cells gp0_ctrl_ic]

connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins gp0_ctrl_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins gp0_ctrl_ic/M00_AXI] $pp_s_axi_pin
connect_bd_intf_net [get_bd_intf_pins gp0_ctrl_ic/M01_AXI] $aes_s_axi_pin
connect_bd_intf_net [get_bd_intf_pins gp0_ctrl_ic/M02_AXI] [get_bd_intf_pins $DMA_INST/S_AXI_LITE]

foreach p [list \
    [get_bd_pins gp0_ctrl_ic/ACLK] \
    [get_bd_pins gp0_ctrl_ic/S00_ACLK] \
    [get_bd_pins gp0_ctrl_ic/M00_ACLK] \
    [get_bd_pins gp0_ctrl_ic/M01_ACLK] \
    [get_bd_pins gp0_ctrl_ic/M02_ACLK] \
] {
    if {[llength [get_bd_nets -quiet -of_objects $p]] == 0} {
        connect_bd_net $ps_fclk0_pin $p
    }
}

foreach p [list \
    [get_bd_pins gp0_ctrl_ic/ARESETN] \
    [get_bd_pins gp0_ctrl_ic/S00_ARESETN] \
    [get_bd_pins gp0_ctrl_ic/M00_ARESETN] \
    [get_bd_pins gp0_ctrl_ic/M01_ARESETN] \
    [get_bd_pins gp0_ctrl_ic/M02_ARESETN] \
] {
    if {[llength [get_bd_nets -quiet -of_objects $p]] == 0} {
        connect_bd_net $ps_fclk_resetn_pin $p
    }
}

set pp_aclk_pin [first_existing_pin [list "${PP_INST}/S_AXI_ACLK" "${PP_INST}/s_axi_aclk"]]
set pp_aresetn_pin [first_existing_pin [list "${PP_INST}/S_AXI_ARESETN" "${PP_INST}/s_axi_aresetn"]]
set aes_aclk_pin [first_existing_pin [list "${AES_INST}/S_AXI_ACLK" "${AES_INST}/s_axi_aclk"]]
set aes_aresetn_pin [first_existing_pin [list "${AES_INST}/S_AXI_ARESETN" "${AES_INST}/s_axi_aresetn"]]

if {$pp_aclk_pin ne "" && [llength [get_bd_nets -quiet -of_objects $pp_aclk_pin]] == 0} {
    connect_bd_net $ps_fclk0_pin $pp_aclk_pin
}
if {$pp_aresetn_pin ne "" && [llength [get_bd_nets -quiet -of_objects $pp_aresetn_pin]] == 0} {
    connect_bd_net $ps_fclk_resetn_pin $pp_aresetn_pin
}
if {$aes_aclk_pin ne "" && [llength [get_bd_nets -quiet -of_objects $aes_aclk_pin]] == 0} {
    connect_bd_net $ps_fclk0_pin $aes_aclk_pin
}
if {$aes_aresetn_pin ne "" && [llength [get_bd_nets -quiet -of_objects $aes_aresetn_pin]] == 0} {
    connect_bd_net $ps_fclk_resetn_pin $aes_aresetn_pin
}

foreach p [get_bd_pins -quiet -of_objects [get_bd_cells $DMA_INST]] {
    set pin_name [string tolower [get_property NAME $p]]
    if {[string match "*aclk" $pin_name]} {
        if {[llength [get_bd_nets -quiet -of_objects $p]] == 0} {
            connect_bd_net $ps_fclk0_pin $p
        }
    }
}

set dma_aresetn_pin [get_bd_pins -quiet ${DMA_INST}/axi_resetn]
if {[llength $dma_aresetn_pin] > 0 && [llength [get_bd_nets -quiet -of_objects $dma_aresetn_pin]] == 0} {
    connect_bd_net $ps_fclk_resetn_pin $dma_aresetn_pin
}

# DDR write/read memory path:
#   ping-pong M_AXI + DMA MM2S M_AXI -> hp0_mem_ic -> ps7/S_AXI_HP0
set pp_m_axi_pin [first_existing_intf_pin [list "/${PP_INST}/M_AXI" "/${PP_INST}/m_axi"]]
if {$pp_m_axi_pin eq ""} {
    error "Unable to resolve AXI master interface for $PP_INST"
}

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 hp0_mem_ic
set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {2} \
] [get_bd_cells hp0_mem_ic]

connect_bd_intf_net $pp_m_axi_pin [get_bd_intf_pins hp0_mem_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins $DMA_INST/M_AXI_MM2S] [get_bd_intf_pins hp0_mem_ic/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins hp0_mem_ic/M00_AXI] [get_bd_intf_pins ps7/S_AXI_HP0]

set ps_hp0_aclk_pin [get_bd_pins ps7/S_AXI_HP0_ACLK]
if {[llength [get_bd_nets -quiet -of_objects $ps_hp0_aclk_pin]] == 0} {
    connect_bd_net $ps_fclk0_pin $ps_hp0_aclk_pin
}

foreach p [list \
    [get_bd_pins hp0_mem_ic/ACLK] \
    [get_bd_pins hp0_mem_ic/S00_ACLK] \
    [get_bd_pins hp0_mem_ic/S01_ACLK] \
    [get_bd_pins hp0_mem_ic/M00_ACLK] \
] {
    if {[llength [get_bd_nets -quiet -of_objects $p]] == 0} {
        connect_bd_net $ps_fclk0_pin $p
    }
}

foreach p [list \
    [get_bd_pins hp0_mem_ic/ARESETN] \
    [get_bd_pins hp0_mem_ic/S00_ARESETN] \
    [get_bd_pins hp0_mem_ic/S01_ARESETN] \
    [get_bd_pins hp0_mem_ic/M00_ARESETN] \
] {
    if {[llength [get_bd_nets -quiet -of_objects $p]] == 0} {
        connect_bd_net $ps_fclk_resetn_pin $p
    }
}

# Stream data path:
#   DMA MM2S -> AES PT stream input
#   AES CT stream output -> ping-pong stream writer input
set aes_s_axis_pt_pin [first_existing_intf_pin [list "/${AES_INST}/S_AXIS_PT" "/${AES_INST}/s_axis_pt"]]
set aes_m_axis_ct_pin [first_existing_intf_pin [list "/${AES_INST}/M_AXIS_CT" "/${AES_INST}/m_axis_ct"]]
set pp_s_axis_src_pin [first_existing_intf_pin [list "/${PP_INST}/S_AXIS_SRC" "/${PP_INST}/s_axis_src"]]

if {$aes_s_axis_pt_pin eq ""} {
    error "Unable to resolve AXIS plaintext input interface for $AES_INST"
}
if {$aes_m_axis_ct_pin eq ""} {
    error "Unable to resolve AXIS ciphertext output interface for $AES_INST"
}
if {$pp_s_axis_src_pin eq ""} {
    error "Unable to resolve AXIS source input interface for $PP_INST"
}

connect_bd_intf_net [get_bd_intf_pins $DMA_INST/M_AXIS_MM2S] $aes_s_axis_pt_pin
connect_bd_intf_net $aes_m_axis_ct_pin $pp_s_axis_src_pin

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
set wrapper_candidates [glob -nocomplain AES_VERILOG.gen/sources_1/bd/${BD_NAME}/hdl/${BD_NAME}_wrapper.v]
if {[llength $wrapper_candidates] == 0} {
    error "Wrapper file not generated for ${BD_NAME}; leaving Top as active top."
}

set wrapper_path [file normalize [lindex $wrapper_candidates 0]]
if {[llength [get_files -quiet $wrapper_path]] == 0} {
    add_files -norecurse $wrapper_path
}

# Keep automatic source management enabled. Module references are ignored
# in manual compile-order mode and can destabilize this flow.
set_property source_mgmt_mode All [current_project]
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

# Keep automatic hierarchy updates so other module-reference IP in this
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
puts "       (see pynq/test_ping_pong_ctrl.py, pynq/test_ping_pong_writer_ddr.py,"
puts "        and pynq/test_ping_pong_writer_aes_stream.py)"
puts "==========================================================="
