# ──────────────────────────────────────────────────────────────
#  build_bd_ctr.tcl  –  Create PYNQ Z2 block design for AES-256 CTR mode
#
#  Usage (from Vivado Tcl console):
#    cd <project_directory>
#    source pynq/build_bd_ctr.tcl
#
#  This creates a block design with:
#    Zynq PS  →  AXI Interconnect  →  AXI_AES_CTR_wrapper
#
#  AXI_AES_CTR wraps CtrMode (KeyExpansion + EncryptPipelined + XOR)
#  with an AXI4-Lite register interface.
#
#  Prerequisites:
#    - All AES sources must be in the project
#    - PYNQ-Z2 board files installed (see README)
# ──────────────────────────────────────────────────────────────

set AES_MODULE  "AXI_AES_CTR_wrapper"
set AES_INST    "aes_ctr_0"
set BD_NAME     "aes_ctr"

# ── 1. Create block design ───────────────────────────────────
# Re-runnable flow: if BD already exists, close and remove it.
if {[llength [get_bd_designs -quiet $BD_NAME]] > 0} {
    puts "INFO: Existing block design '$BD_NAME' found; removing it."
    catch {close_bd_design [get_bd_designs $BD_NAME]}

    set bd_file "AES_VERILOG.srcs/sources_1/bd/${BD_NAME}/${BD_NAME}.bd"
    if {[llength [get_files -quiet $bd_file]] > 0} {
        remove_files [get_files $bd_file]
    }
}

create_bd_design $BD_NAME

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
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {0} \
] [get_bd_cells ps7]

# ── 4. Add AES CTR module reference and RTL dependencies ─────
set_property source_mgmt_mode All [current_project]

set rtl_dir "AES_VERILOG.srcs/sources_1/new"
set ctr_sources [list \
    "$rtl_dir/AXI_AES_CTR_wrapper.v" \
    "$rtl_dir/AXI_AES_CTR.sv" \
    "$rtl_dir/CtrMode.sv" \
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

foreach f $ctr_sources {
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

# ── 5. Run connection automation ─────────────────────────────
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

# ── 6. Validate & save ──────────────────────────────────────
regenerate_bd_layout
validate_bd_design
save_bd_design

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
puts "    5. Copy .bit + .hwh to PYNQ board (see pynq/test_aes_ctr.py)"
puts "==========================================================="
