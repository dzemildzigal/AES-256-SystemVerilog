# ──────────────────────────────────────────────────────────────
#  build_bd_gcm_dma.tcl  –  Create PYNQ Z2 block design for AES-256 GCM
#                         with AXI-Stream + AXI DMA data path.
#
#  Usage (from Vivado Tcl console):
#    cd <project_directory>
#    source pynq/build_bd_gcm_dma.tcl
#
#  This creates a block design with:
#    PS7 GP0  -> AXI-Lite -> AXI_AES_GCM_Stream_wrapper + AXI DMA control
#    PS7 HP0  <-/-> AXI DMA memory ports
#    AXI DMA M_AXIS_MM2S -> AES S_AXIS_PT
#    AES M_AXIS_CT       -> AXI DMA S_AXIS_S2MM
# ──────────────────────────────────────────────────────────────

set AES_MODULE  "AXI_AES_GCM_Stream_wrapper"
set AES_INST    "aes_gcm_0"
set DMA_INST    "axi_dma_0"
set BD_NAME     "aes_gcm_dma"

# ── 1. Create block design ───────────────────────────────────
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

# ── 4. Add AES GCM module reference and RTL dependencies ────
set_property source_mgmt_mode All [current_project]

set rtl_dir "AES_VERILOG.srcs/sources_1/new"
set gcm_sources [list \
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

foreach f $gcm_sources {
    if {[file exists $f]} {
        if {[llength [get_files -quiet $f]] == 0} {
            add_files -norecurse $f
        }
    } else {
        puts "WARNING: Missing source file: $f"
    }
}

update_compile_order -fileset sources_1

create_bd_cell -type module -reference $AES_MODULE $AES_INST
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 $DMA_INST

set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_include_mm2s {1} \
    CONFIG.c_include_s2mm {1} \
    CONFIG.c_sg_length_width {26} \
    CONFIG.c_m_axi_mm2s_data_width {128} \
    CONFIG.c_m_axis_mm2s_tdata_width {128} \
    CONFIG.c_m_axi_s2mm_data_width {128} \
    CONFIG.c_s_axis_s2mm_tdata_width {128} \
    CONFIG.c_mm2s_burst_size {256} \
    CONFIG.c_s2mm_burst_size {256} \
] [get_bd_cells $DMA_INST]

# ── 5. Run connection automation ─────────────────────────────
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable"} \
    [get_bd_cells ps7]

# GP0 AXI-Lite: PS -> aes_gcm_0/s_axi
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {
        Clk_master {/ps7/FCLK_CLK0 (100 MHz)}
        Clk_slave  {Auto}
        Clk_xbar   {Auto}
        Master     {/ps7/M_AXI_GP0}
        Slave      {/$AES_INST/s_axi}
        ddr_seg    {Auto}
        intc_ip    {New AXI Interconnect}
        master_apm {0}
    } [get_bd_intf_pins $AES_INST/s_axi]

# GP0 AXI-Lite: PS -> axi_dma_0/S_AXI_LITE
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {
        Clk_master {/ps7/FCLK_CLK0 (100 MHz)}
        Clk_slave  {Auto}
        Clk_xbar   {Auto}
        Master     {/ps7/M_AXI_GP0}
        Slave      {/$DMA_INST/S_AXI_LITE}
        ddr_seg    {Auto}
        intc_ip    {Auto}
        master_apm {0}
    } [get_bd_intf_pins $DMA_INST/S_AXI_LITE]

# HP0 memory path: dma masters -> ps7/S_AXI_HP0
# Some Vivado versions fail bd_rule:axi4 when invoked from DMA master interfaces,
# so build this path explicitly.
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 hp0_mem_ic
set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {2} \
] [get_bd_cells hp0_mem_ic]

connect_bd_intf_net [get_bd_intf_pins $DMA_INST/M_AXI_MM2S] [get_bd_intf_pins hp0_mem_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins $DMA_INST/M_AXI_S2MM] [get_bd_intf_pins hp0_mem_ic/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins hp0_mem_ic/M00_AXI]   [get_bd_intf_pins ps7/S_AXI_HP0]

set ps_fclk0_pin      [get_bd_pins ps7/FCLK_CLK0]
set ps_fclk_resetn_pin [get_bd_pins ps7/FCLK_RESET0_N]

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

# Stream data path
connect_bd_intf_net [get_bd_intf_pins $DMA_INST/M_AXIS_MM2S] [get_bd_intf_pins $AES_INST/S_AXIS_PT]
connect_bd_intf_net [get_bd_intf_pins $AES_INST/M_AXIS_CT]   [get_bd_intf_pins $DMA_INST/S_AXIS_S2MM]

# Ensure all control/data clocks share FCLK_CLK0.
set clock_pins [list [get_bd_pins $AES_INST/S_AXI_ACLK]]
foreach p [get_bd_pins -quiet -of_objects [get_bd_cells $DMA_INST]] {
    set pin_name [get_property NAME $p]
    if {[string match "*aclk" $pin_name]} {
        lappend clock_pins $p
    }
}

foreach p $clock_pins {
    if {[llength [get_bd_nets -quiet -of_objects $p]] == 0} {
        connect_bd_net $ps_fclk0_pin $p
    }
}

set aes_aresetn_pin [get_bd_pins $AES_INST/S_AXI_ARESETN]
if {[llength [get_bd_nets -quiet -of_objects $aes_aresetn_pin]] == 0} {
    connect_bd_net $ps_fclk_resetn_pin $aes_aresetn_pin
}

set dma_aresetn_pin [get_bd_pins $DMA_INST/axi_resetn]
if {[llength [get_bd_nets -quiet -of_objects $dma_aresetn_pin]] == 0} {
    connect_bd_net $ps_fclk_resetn_pin $dma_aresetn_pin
}

assign_bd_address

# ── 6. Validate & save ──────────────────────────────────────
regenerate_bd_layout
validate_bd_design
save_bd_design

set bd_files [get_files -quiet "*/${BD_NAME}.bd"]
if {[llength $bd_files] > 0} {
    set_property synth_checkpoint_mode None $bd_files
}

# ── 7. Create HDL wrapper ───────────────────────────────────
make_wrapper -files [get_files ${BD_NAME}.bd] -top
set wrapper_path [file normalize [glob AES_VERILOG.gen/sources_1/bd/${BD_NAME}/hdl/${BD_NAME}_wrapper.v]]
add_files -norecurse $wrapper_path
update_compile_order -fileset sources_1

# ── 8. Set wrapper as synthesis top ─────────────────────────
set_property top ${BD_NAME}_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts ""
puts "==========================================================="
puts "  Block design created: $BD_NAME"
puts "  Top module: ${BD_NAME}_wrapper"
puts ""
puts "  Next steps:"
puts "    1. Run Synthesis:  launch_runs synth_1 -jobs 4"
puts "    2. Wait:           wait_on_run synth_1"
puts "    3. Run Implement:  launch_runs impl_1 -to_step write_bitstream -jobs 4"
puts "    4. Wait:           wait_on_run impl_1"
puts "    5. Copy .bit + .hwh to PYNQ board (see pynq/test_aes_gcm_dma.py)"
puts "==========================================================="
