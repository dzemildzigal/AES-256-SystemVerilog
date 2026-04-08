# ──────────────────────────────────────────────────────────────
#  build_bd.tcl  –  Create PYNQ Z2 block design for AES roundtrip
#
#  Usage (from Vivado Tcl console):
#    cd <project_directory>
#    source pynq/build_bd.tcl
#
#  This creates a block design with:
#    Zynq PS  →  AXI Interconnect  →  AXI_AES_Roundtrip
#
#  AXI_AES_Roundtrip wraps TopRoundtrip (EncryptPipelined + DecryptPipelined)
#  with an AXI4-Lite register interface.
#
#  Prerequisites:
#    - All AES sources must be in the project
#    - PYNQ-Z2 board files installed (see README), OR the script
#      falls back to manual Zynq PS configuration
# ──────────────────────────────────────────────────────────────

set AES_MODULE  "AXI_AES_Roundtrip_wrapper"
set AES_INST    "aes_roundtrip_0"
set BD_NAME     "aes_roundtrip"

# ── 1. Create block design ───────────────────────────────────
create_bd_design $BD_NAME

# ── 2. Set board part so automation can configure PS correctly ─
set pynq_parts [get_board_parts -filter {NAME =~ *pynq*}]
if {[llength $pynq_parts] > 0} {
    set pynq_part [lindex $pynq_parts 0]
    puts "INFO: Setting board_part to $pynq_part"
    set_property board_part $pynq_part [current_project]
} else {
    puts "WARNING: PYNQ-Z2 board files not found."
    puts "         Download from: https://github.com/cathalmccabe/pynq-z2_board_files"
    puts "         Install to: <Vivado_install>/data/boards/board_files/pynq-z2/"
    puts "         Continuing with manual PS config..."
}

# ── 3. Add Zynq PS ──────────────────────────────────────────
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7

# Essential PS settings
set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {0} \
] [get_bd_cells ps7]

# ── 4. Add AES module reference ──────────────────────────────
#    Module references require automatic compile order.
#    The .v wrapper is needed because Vivado BD doesn't support
#    SystemVerilog as the top file of a module reference.
set_property source_mgmt_mode All [current_project]
add_files -norecurse AES_VERILOG.srcs/sources_1/new/AXI_AES_Roundtrip_wrapper.v
update_compile_order -fileset sources_1

#    Vivado auto-detects the AXI4-Lite slave interface from
#    the S_AXI_* port naming convention.
create_bd_cell -type module -reference $AES_MODULE $AES_INST

# ── 4. Run connection automation ─────────────────────────────
#    Wires: ps7/FCLK_CLK0 → clocks, ps7/M_AXI_GP0 → aes_0/s_axi
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable"} \
    [get_bd_cells ps7]

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

# ── 5. Validate & save ──────────────────────────────────────
regenerate_bd_layout
validate_bd_design
save_bd_design

# ── 6. Create HDL wrapper ───────────────────────────────────
make_wrapper -files [get_files ${BD_NAME}.bd] -top
set wrapper_path [file normalize [glob AES_VERILOG.gen/sources_1/bd/${BD_NAME}/hdl/${BD_NAME}_wrapper.v]]
add_files -norecurse $wrapper_path
update_compile_order -fileset sources_1

# ── 7. Set wrapper as synthesis top ─────────────────────────
set_property top ${BD_NAME}_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts ""
puts "═══════════════════════════════════════════════════════════"
puts "  Block design created: $BD_NAME"
puts "  Top module: ${BD_NAME}_wrapper"
puts ""
puts "  Next steps:"
puts "    1. Run Synthesis:  launch_runs synth_1 -jobs 4"
puts "    2. Wait:           wait_on_run synth_1"
puts "    3. Run Implement:  launch_runs impl_1 -to_step write_bitstream -jobs 4"
puts "    4. Wait:           wait_on_run impl_1"
puts "    5. Copy .bit + .hwh to PYNQ board (see pynq/test_aes.py)"
puts "═══════════════════════════════════════════════════════════"
