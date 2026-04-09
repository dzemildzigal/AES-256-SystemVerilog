# ──────────────────────────────────────────────────────────────
#  build_bd_gcm.tcl  –  Create PYNQ Z2 block design for AES-256 GCM mode
#
#  Usage (from Vivado Tcl console):
#    cd <project_directory>
#    source pynq/build_bd_gcm.tcl
#
#  This creates a block design with:
#    Zynq PS  →  AXI Interconnect  →  AXI_AES_GCM_wrapper
#
#  AXI_AES_GCM wraps:
#    GcmMode (KeyExpansion + shared EncryptPipelined + GHashEngine)
#
#  Prerequisites:
#    - All GCM/AES sources present in AES_VERILOG.srcs/sources_1/new
#    - PYNQ-Z2 board files installed
# ──────────────────────────────────────────────────────────────

set AES_MODULE  "AXI_AES_GCM_wrapper"
set AES_INST    "aes_gcm_0"
set BD_NAME     "aes_gcm"

# ── 1. Create block design ───────────────────────────────────
# Re-runnable flow: close/remove any stale in-memory, project, and on-disk BD state.
set bd_src_file "AES_VERILOG.srcs/sources_1/bd/${BD_NAME}/${BD_NAME}.bd"
set bd_gen_file "AES_VERILOG.gen/sources_1/bd/${BD_NAME}/${BD_NAME}.bd"
set bd_gen_dir  "AES_VERILOG.gen/sources_1/bd/${BD_NAME}"

set existing_bd [get_bd_designs -quiet $BD_NAME]
set existing_bd_files [get_files -quiet "*/${BD_NAME}.bd"]

if {[llength $existing_bd] > 0 || [llength $existing_bd_files] > 0 || [file exists $bd_src_file]} {
    puts "INFO: Existing block design '$BD_NAME' found; removing it."
}

# Close currently-open BD if it matches this name.
set current_bd ""
catch {set current_bd [current_bd_design -quiet]}
if {$current_bd eq $BD_NAME} {
    catch {close_bd_design $current_bd}
}

# Close any named design handles that still exist.
foreach d $existing_bd {
    catch {close_bd_design $d}
}

# Remove BD files from project (if registered).
if {[llength $existing_bd_files] > 0} {
    catch {remove_files $existing_bd_files}
}

# Remove stale generated BD products so create_bd_design has a clean slate.
if {[file exists $bd_src_file]} {
    catch {file delete -force $bd_src_file}
}
if {[file exists $bd_gen_file]} {
    catch {file delete -force $bd_gen_file}
}
if {[file exists $bd_gen_dir]} {
    catch {file delete -force $bd_gen_dir}
}

# Create BD, with one forced retry path for stubborn stale state.
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
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {0} \
] [get_bd_cells ps7]

# ── 4. Add AES GCM module reference and RTL dependencies ────
set_property source_mgmt_mode All [current_project]

set rtl_dir "AES_VERILOG.srcs/sources_1/new"
set gcm_sources [list \
    "$rtl_dir/AXI_AES_GCM_wrapper.v" \
    "$rtl_dir/AXI_AES_GCM.sv" \
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

# Keep GCM logic in top-level synthesis to avoid missing OOC checkpoint
# races for module-reference IP during implementation.
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
puts "    5. Copy .bit + .hwh to PYNQ board (see pynq/test_aes_gcm.py)"
puts "==========================================================="
