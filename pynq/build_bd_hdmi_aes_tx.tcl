# ──────────────────────────────────────────────────────────────
#  build_bd_hdmi_aes_tx.tcl  –  Create the first dedicated block
#  design scaffold for the PYNQ-Z2 HDMI -> AES -> Ethernet TX path.
#
#  Usage (from Vivado Tcl console):
#    cd <AES-256-SystemVerilog repo root>
#    source pynq/create_hdmi_aes_tx_project.tcl
#    set ::env(PYNQ_Z2_BASE_DIR) <path-to-PYNQ>/boards/Pynq-Z2/base
#    source pynq/build_bd_hdmi_aes_tx.tcl
#
#  This scaffold creates the crypto + DDR-writer half of the design and
#  exposes a packet-plaintext AXI-Stream input port (`pkt_pt_axis_in`).
#  The next slice replaces that external insertion point with the real
#  PYNQ-Z2 HDMI video subsystem + PL packetizer.
# ──────────────────────────────────────────────────────────────

set AES_MODULE   "AXI_AES_GCM_Stream_wrapper"
set AES_INST     "aes_gcm_0"
set WRITER_MODULE "AXI_PingPong_Ctrl_wrapper"
set WRITER_INST  "frame_writer_0"
set BD_NAME      "hdmi_aes_tx"

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
    error "PYNQ_Z2_BASE_DIR is required. Point it at the official PYNQ boards/Pynq-Z2/base directory before sourcing this script."
}

proc require_file {path label} {
    if {![file exists $path]} {
        error "Missing $label: $path"
    }
}

proc require_ip {vlnv} {
    set defs [get_ipdefs -quiet -all $vlnv]
    if {[llength $defs] == 0} {
        error "Required Vivado IP '$vlnv' was not found in the current catalog."
    }
}

proc remove_existing_bd {bd_name} {
    set bd_src_file "HDMI_AES_TX.srcs/sources_1/bd/${bd_name}/${bd_name}.bd"
    set bd_gen_file "HDMI_AES_TX.gen/sources_1/bd/${bd_name}/${bd_name}.bd"
    set bd_gen_dir  "HDMI_AES_TX.gen/sources_1/bd/${bd_name}"

    set existing_bd [get_bd_designs -quiet $bd_name]
    set existing_bd_files [get_files -quiet "*/${bd_name}.bd"]

    set current_bd ""
    catch {set current_bd [current_bd_design -quiet]}
    if {$current_bd eq $bd_name} {
        catch {close_bd_design $current_bd}
    }

    foreach d $existing_bd {
        catch {close_bd_design $d}
    }

    if {[llength $existing_bd_files] > 0} {
        catch {remove_files $existing_bd_files}
    }

    catch {file delete -force $bd_src_file}
    catch {file delete -force $bd_gen_file}
    catch {file delete -force $bd_gen_dir}
}

proc connect_if_unconnected {src dst} {
    if {[llength [get_bd_nets -quiet -of_objects $dst]] == 0} {
        connect_bd_net $src $dst
    }
}

if {[catch {current_project} current_proj]} {
    error "No Vivado project is open. Source pynq/create_hdmi_aes_tx_project.tcl first."
}

set current_project_name [get_property NAME [current_project]]
if {$current_project_name ne "HDMI_AES_TX"} {
    error "Current project is '$current_project_name'. Open or create the dedicated HDMI_AES_TX project before sourcing this script."
}

set pynq_base_dir [resolve_pynq_base_dir]
require_file [file join $pynq_base_dir "build_base_ip.tcl"] "PYNQ-Z2 base build script"
require_file [file join $pynq_base_dir "base.tcl"] "PYNQ-Z2 base overlay Tcl"

require_ip "xilinx.com:ip:processing_system7:5.5"
require_ip "xilinx.com:ip:axi_interconnect:2.1"
require_ip "xilinx.com:ip:v_vid_in_axi4s:5.0"
require_ip "xilinx.com:ip:v_tc:6.2"
require_ip "digilentinc.com:ip:dvi2rgb:1.7"

set pynq_part [detect_pynq_board_part]
if {$pynq_part ne ""} {
    set_property board_part $pynq_part [current_project]
}

remove_existing_bd $BD_NAME
create_bd_design $BD_NAME

create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7
set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
] [get_bd_cells ps7]

create_bd_cell -type module -reference $AES_MODULE $AES_INST
create_bd_cell -type module -reference $WRITER_MODULE $WRITER_INST

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

apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {
        Clk_master {/ps7/FCLK_CLK0 (100 MHz)}
        Clk_slave  {Auto}
        Clk_xbar   {Auto}
        Master     {/ps7/M_AXI_GP0}
        Slave      {/$WRITER_INST/S_AXI}
        ddr_seg    {Auto}
        intc_ip    {Auto}
        master_apm {0}
    } [get_bd_intf_pins $WRITER_INST/S_AXI]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 hp0_mem_ic
set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {1} \
] [get_bd_cells hp0_mem_ic]

connect_bd_intf_net [get_bd_intf_pins $WRITER_INST/M_AXI] [get_bd_intf_pins hp0_mem_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins hp0_mem_ic/M00_AXI] [get_bd_intf_pins ps7/S_AXI_HP0]

set pkt_pt_axis_in [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 pkt_pt_axis_in]
set_property -dict [list \
    CONFIG.TDATA_NUM_BYTES {16} \
    CONFIG.HAS_TKEEP {1} \
    CONFIG.HAS_TLAST {1} \
    CONFIG.HAS_TSTRB {0} \
    CONFIG.TUSER_WIDTH {0} \
    CONFIG.TID_WIDTH {0} \
    CONFIG.TDEST_WIDTH {0} \
] [get_bd_intf_ports pkt_pt_axis_in]

connect_bd_intf_net [get_bd_intf_ports pkt_pt_axis_in] [get_bd_intf_pins $AES_INST/S_AXIS_PT]
connect_bd_intf_net [get_bd_intf_pins $AES_INST/M_AXIS_CT] [get_bd_intf_pins $WRITER_INST/S_AXIS_SRC]

create_bd_port -dir O frame_writer_irq
connect_bd_net [get_bd_ports frame_writer_irq] [get_bd_pins $WRITER_INST/irq]

set ps_fclk0_pin       [get_bd_pins ps7/FCLK_CLK0]
set ps_fclk_resetn_pin [get_bd_pins ps7/FCLK_RESET0_N]
set ps_hp0_aclk_pin    [get_bd_pins ps7/S_AXI_HP0_ACLK]

connect_if_unconnected $ps_fclk0_pin $ps_hp0_aclk_pin

foreach p [list \
    [get_bd_pins hp0_mem_ic/ACLK] \
    [get_bd_pins hp0_mem_ic/S00_ACLK] \
    [get_bd_pins hp0_mem_ic/M00_ACLK] \
    [get_bd_pins $AES_INST/S_AXI_ACLK] \
    [get_bd_pins $WRITER_INST/S_AXI_ACLK] \
] {
    connect_if_unconnected $ps_fclk0_pin $p
}

foreach p [list \
    [get_bd_pins hp0_mem_ic/ARESETN] \
    [get_bd_pins hp0_mem_ic/S00_ARESETN] \
    [get_bd_pins hp0_mem_ic/M00_ARESETN] \
    [get_bd_pins $AES_INST/S_AXI_ARESETN] \
    [get_bd_pins $WRITER_INST/S_AXI_ARESETN] \
] {
    connect_if_unconnected $ps_fclk_resetn_pin $p
}

assign_bd_address
regenerate_bd_layout
validate_bd_design
save_bd_design

set bd_files [get_files -quiet "*/${BD_NAME}.bd"]
if {[llength $bd_files] > 0} {
    set_property synth_checkpoint_mode None $bd_files
}

make_wrapper -files [get_files ${BD_NAME}.bd] -top
set wrapper_path [file normalize [glob HDMI_AES_TX.gen/sources_1/bd/${BD_NAME}/hdl/${BD_NAME}_wrapper.v]]
add_files -norecurse $wrapper_path
set_property top ${BD_NAME}_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts ""
puts "==========================================================="
puts "  Block design scaffold created: $BD_NAME"
puts "  Top module: ${BD_NAME}_wrapper"
puts ""
puts "  What is real in this slice:"
puts "    - PS7 control plane"
puts "    - AES-GCM stream wrapper"
puts "    - Existing DDR writer path"
puts "    - External AXIS insertion point: pkt_pt_axis_in"
puts ""
puts "  What remains for the literal HDMI TX path:"
puts "    - Import/wire PYNQ-Z2 HDMI subsystem from official base overlay"
puts "    - Insert HDMI video -> packetizer block ahead of pkt_pt_axis_in"
puts "    - Replace/extend DDR writer with packet-ready TX ring writer for PS Ethernet send"
puts "==========================================================="