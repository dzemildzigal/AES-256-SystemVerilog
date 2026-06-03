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
set PACKETIZER_MODULE "HDMI_Axis_Packetizer"
set PACKETIZER_INST "hdmi_packetizer_0"
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
    # Common Vivado Tcl typo: set ::(PYNQ_Z2_BASE_DIR) ...
    # That creates variable named "(PYNQ_Z2_BASE_DIR)" in global namespace.
    if {[info exists ::(PYNQ_Z2_BASE_DIR)] && $::(PYNQ_Z2_BASE_DIR) ne ""} {
        return [file normalize $::(PYNQ_Z2_BASE_DIR)]
    }
    error "PYNQ_Z2_BASE_DIR is required. Use one of: 'set ::PYNQ_Z2_BASE_DIR <path>' or 'set ::env(PYNQ_Z2_BASE_DIR) <path>', then source script again."
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

proc configure_pynq_ip_repo {pynq_base_dir} {
    set repo_dir [file normalize [file join $pynq_base_dir ".." ".." "ip"]]
    if {![file isdirectory $repo_dir]} {
        puts "WARNING: PYNQ IP repo folder not found at $repo_dir"
        return
    }

    set current_repos [get_property ip_repo_paths [current_project]]
    if {[lsearch -exact $current_repos $repo_dir] < 0} {
        lappend current_repos $repo_dir
        set_property ip_repo_paths $current_repos [current_project]
    }

    update_ip_catalog -rebuild -scan_changes
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
configure_pynq_ip_repo $pynq_base_dir

require_ip "xilinx.com:ip:processing_system7:5.5"
require_ip "xilinx.com:ip:axi_interconnect:2.1"
require_ip "xilinx.com:ip:v_vid_in_axi4s:5.0"
require_ip "xilinx.com:ip:v_tc:6.2"
require_ip "xilinx.com:user:color_swap:1.1"
require_ip "xilinx.com:ip:xlconstant:1.1"
require_ip "xilinx.com:ip:axi_gpio:2.0"
require_ip "xilinx.com:ip:axis_data_fifo:2.0"
require_ip "digilentinc.com:ip:dvi2rgb:1.7"
require_ip "digilentinc.com:ip:axi_dynclk:1.0"
require_ip "digilentinc.com:ip:rgb2dvi:1.2"

set pynq_part [detect_pynq_board_part]
if {$pynq_part ne ""} {
    set_property board_part $pynq_part [current_project]
}

remove_existing_bd $BD_NAME
create_bd_design $BD_NAME

create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7
set_property -dict [list \
    CONFIG.PCW_EN_CLK0_PORT {1} \
    CONFIG.PCW_EN_CLK1_PORT {1} \
    CONFIG.PCW_EN_CLK2_PORT {1} \
    CONFIG.PCW_FCLK_CLK1_BUF {TRUE} \
    CONFIG.PCW_FCLK_CLK2_BUF {TRUE} \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {142} \
    CONFIG.PCW_FPGA2_PERIPHERAL_FREQMHZ {200} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
] [get_bd_cells ps7]

create_bd_cell -type module -reference $AES_MODULE $AES_INST
create_bd_cell -type module -reference $WRITER_MODULE $WRITER_INST
create_bd_cell -type module -reference $PACKETIZER_MODULE $PACKETIZER_INST
create_bd_cell -type ip -vlnv digilentinc.com:ip:dvi2rgb:1.7 dvi2rgb_0
set_property -dict [list \
    CONFIG.kAddBUFG {false} \
    CONFIG.kClkRange {1} \
    CONFIG.kEdidFileName {720p_edid.data} \
    CONFIG.kRstActiveHigh {false} \
] [get_bd_cells dvi2rgb_0]

create_bd_cell -type ip -vlnv xilinx.com:user:color_swap:1.1 color_swap_0
set_property -dict [list \
    CONFIG.input_format {rbg} \
    CONFIG.output_format {rgb} \
] [get_bd_cells color_swap_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:v_vid_in_axi4s:5.0 v_vid_in_axi4s_0
set_property -dict [list \
    CONFIG.C_ADDR_WIDTH {12} \
    CONFIG.C_HAS_ASYNC_CLK {1} \
] [get_bd_cells v_vid_in_axi4s_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:v_tc:6.2 vtc_in
set_property -dict [list \
    CONFIG.HAS_INTC_IF {true} \
    CONFIG.enable_generation {false} \
    CONFIG.horizontal_blank_detection {false} \
    CONFIG.max_lines_per_frame {2048} \
    CONFIG.vertical_blank_detection {false} \
] [get_bd_cells vtc_in]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_hdmiin
set_property -dict [list \
    CONFIG.C_ALL_INPUTS_2 {1} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_GPIO2_WIDTH {1} \
    CONFIG.C_GPIO_WIDTH {1} \
    CONFIG.C_INTERRUPT_PRESENT {1} \
    CONFIG.C_IS_DUAL {1} \
] [get_bd_cells axi_gpio_hdmiin]

create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 hdmi_axis_cdc_fifo
set_property -dict [list \
    CONFIG.IS_ACLK_ASYNC {1} \
    CONFIG.TDATA_NUM_BYTES {3} \
    CONFIG.HAS_TKEEP {0} \
    CONFIG.HAS_TSTRB {0} \
    CONFIG.HAS_TLAST {1} \
    CONFIG.HAS_TUSER {1} \
    CONFIG.TUSER_WIDTH {1} \
    CONFIG.FIFO_DEPTH {2048} \
] [get_bd_cells hdmi_axis_cdc_fifo]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 hdmi_vidrst_const
set_property -dict [list \
    CONFIG.CONST_VAL {0} \
    CONFIG.CONST_WIDTH {1} \
] [get_bd_cells hdmi_vidrst_const]

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

apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {
        Clk_master {/ps7/FCLK_CLK0 (100 MHz)}
        Clk_slave  {Auto}
        Clk_xbar   {Auto}
        Master     {/ps7/M_AXI_GP0}
        Slave      {/vtc_in/ctrl}
        ddr_seg    {Auto}
        intc_ip    {Auto}
        master_apm {0}
    } [get_bd_intf_pins vtc_in/ctrl]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {
        Clk_master {/ps7/FCLK_CLK0 (100 MHz)}
        Clk_slave  {Auto}
        Clk_xbar   {Auto}
        Master     {/ps7/M_AXI_GP0}
        Slave      {/axi_gpio_hdmiin/S_AXI}
        ddr_seg    {Auto}
        intc_ip    {Auto}
        master_apm {0}
    } [get_bd_intf_pins axi_gpio_hdmiin/S_AXI]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 hp0_mem_ic
set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {1} \
] [get_bd_cells hp0_mem_ic]

connect_bd_intf_net [get_bd_intf_pins $WRITER_INST/M_AXI] [get_bd_intf_pins hp0_mem_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins hp0_mem_ic/M00_AXI] [get_bd_intf_pins ps7/S_AXI_HP0]
connect_bd_intf_net [get_bd_intf_pins dvi2rgb_0/RGB] [get_bd_intf_pins color_swap_0/pixel_input]
connect_bd_intf_net [get_bd_intf_pins color_swap_0/pixel_output] [get_bd_intf_pins v_vid_in_axi4s_0/vid_io_in]
connect_bd_intf_net [get_bd_intf_pins v_vid_in_axi4s_0/vtiming_out] [get_bd_intf_pins vtc_in/vtiming_in]
connect_bd_intf_net [get_bd_intf_pins v_vid_in_axi4s_0/video_out] [get_bd_intf_pins hdmi_axis_cdc_fifo/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins hdmi_axis_cdc_fifo/M_AXIS] [get_bd_intf_pins $PACKETIZER_INST/s_axis_video]

if {[llength [get_bd_intf_ports -quiet hdmi_in]] > 0} {
    connect_bd_intf_net [get_bd_intf_ports hdmi_in] [get_bd_intf_pins dvi2rgb_0/TMDS]
} else {
    set hdmi_in_ext [make_bd_intf_pins_external [get_bd_intf_pins dvi2rgb_0/TMDS]]
    if {[llength $hdmi_in_ext] > 0} {
        set_property name hdmi_in [lindex $hdmi_in_ext 0]
    }
}

if {[llength [get_bd_intf_ports -quiet hdmi_in_ddc]] > 0} {
    connect_bd_intf_net [get_bd_intf_ports hdmi_in_ddc] [get_bd_intf_pins dvi2rgb_0/DDC]
} else {
    set hdmi_in_ddc_ext [make_bd_intf_pins_external [get_bd_intf_pins dvi2rgb_0/DDC]]
    if {[llength $hdmi_in_ddc_ext] > 0} {
        set_property name hdmi_in_ddc [lindex $hdmi_in_ddc_ext 0]
    }
}

if {[llength [get_bd_intf_ports -quiet hdmi_in_video_out]] > 0} {
    connect_bd_intf_net [get_bd_intf_ports hdmi_in_video_out] [get_bd_intf_pins hdmi_axis_cdc_fifo/M_AXIS]
} else {
    set hdmi_in_video_out_ext [make_bd_intf_pins_external [get_bd_intf_pins hdmi_axis_cdc_fifo/M_AXIS]]
    if {[llength $hdmi_in_video_out_ext] > 0} {
        set_property name hdmi_in_video_out [lindex $hdmi_in_video_out_ext 0]
    }
}

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

connect_bd_intf_net [get_bd_intf_pins $PACKETIZER_INST/m_axis_pkt] [get_bd_intf_pins $AES_INST/S_AXIS_PT]
connect_bd_intf_net [get_bd_intf_pins $AES_INST/M_AXIS_CT] [get_bd_intf_pins $WRITER_INST/S_AXIS_SRC]

create_bd_port -dir O frame_writer_irq
connect_bd_net [get_bd_ports frame_writer_irq] [get_bd_pins $WRITER_INST/irq]
if {[llength [get_bd_ports -quiet hdmi_in_hpd]] > 0} {
    connect_bd_net [get_bd_ports hdmi_in_hpd] [get_bd_pins axi_gpio_hdmiin/gpio_io_o]
} else {
    create_bd_port -dir O hdmi_in_hpd
    connect_bd_net [get_bd_ports hdmi_in_hpd] [get_bd_pins axi_gpio_hdmiin/gpio_io_o]
}
if {[llength [get_bd_ports -quiet hdmi_hpd_irq]] > 0} {
    connect_bd_net [get_bd_ports hdmi_hpd_irq] [get_bd_pins axi_gpio_hdmiin/ip2intc_irpt]
} else {
    create_bd_port -dir O hdmi_hpd_irq
    connect_bd_net [get_bd_ports hdmi_hpd_irq] [get_bd_pins axi_gpio_hdmiin/ip2intc_irpt]
}
if {[llength [get_bd_ports -quiet hdmi_vtc_irq]] > 0} {
    connect_bd_net [get_bd_ports hdmi_vtc_irq] [get_bd_pins vtc_in/irq]
} else {
    create_bd_port -dir O hdmi_vtc_irq
    connect_bd_net [get_bd_ports hdmi_vtc_irq] [get_bd_pins vtc_in/irq]
}

set ps_fclk0_pin       [get_bd_pins ps7/FCLK_CLK0]
set ps_fclk1_pin       [get_bd_pins ps7/FCLK_CLK1]
set ps_fclk2_pin       [get_bd_pins ps7/FCLK_CLK2]
set ps_fclk_resetn_pin [get_bd_pins ps7/FCLK_RESET0_N]
set ps_fclk1_resetn_pin [get_bd_pins ps7/FCLK_RESET1_N]
set ps_hp0_aclk_pin    [get_bd_pins ps7/S_AXI_HP0_ACLK]

connect_if_unconnected $ps_fclk0_pin $ps_hp0_aclk_pin
connect_if_unconnected $ps_fclk1_pin [get_bd_pins v_vid_in_axi4s_0/aclk]

connect_if_unconnected $ps_fclk0_pin [get_bd_pins hdmi_axis_cdc_fifo/m_axis_aclk]
connect_if_unconnected $ps_fclk1_pin [get_bd_pins hdmi_axis_cdc_fifo/s_axis_aclk]
connect_if_unconnected $ps_fclk0_pin [get_bd_pins $PACKETIZER_INST/aclk]

foreach p [list \
    [get_bd_pins hp0_mem_ic/ACLK] \
    [get_bd_pins hp0_mem_ic/S00_ACLK] \
    [get_bd_pins hp0_mem_ic/M00_ACLK] \
    [get_bd_pins $AES_INST/S_AXI_ACLK] \
    [get_bd_pins $WRITER_INST/S_AXI_ACLK] \
    [get_bd_pins vtc_in/s_axi_aclk] \
    [get_bd_pins axi_gpio_hdmiin/s_axi_aclk] \
] {
    connect_if_unconnected $ps_fclk0_pin $p
}

foreach p [list \
    [get_bd_pins hp0_mem_ic/ARESETN] \
    [get_bd_pins hp0_mem_ic/S00_ARESETN] \
    [get_bd_pins hp0_mem_ic/M00_ARESETN] \
    [get_bd_pins $AES_INST/S_AXI_ARESETN] \
    [get_bd_pins $WRITER_INST/S_AXI_ARESETN] \
    [get_bd_pins vtc_in/s_axi_aresetn] \
    [get_bd_pins dvi2rgb_0/aRst_n] \
    [get_bd_pins axi_gpio_hdmiin/s_axi_aresetn] \
    [get_bd_pins hdmi_axis_cdc_fifo/m_axis_aresetn] \
    [get_bd_pins $PACKETIZER_INST/aresetn] \
    [get_bd_pins vtc_in/resetn] \
] {
    connect_if_unconnected $ps_fclk_resetn_pin $p
}

connect_if_unconnected $ps_fclk1_resetn_pin [get_bd_pins v_vid_in_axi4s_0/aresetn]
connect_if_unconnected $ps_fclk1_resetn_pin [get_bd_pins hdmi_axis_cdc_fifo/s_axis_aresetn]
connect_bd_net [get_bd_pins dvi2rgb_0/aPixelClkLckd] [get_bd_pins axi_gpio_hdmiin/gpio2_io_i]

connect_if_unconnected $ps_fclk2_pin [get_bd_pins dvi2rgb_0/RefClk]
connect_bd_net [get_bd_pins dvi2rgb_0/PixelClk] [get_bd_pins v_vid_in_axi4s_0/vid_io_in_clk]
connect_bd_net [get_bd_pins dvi2rgb_0/PixelClk] [get_bd_pins vtc_in/clk]
connect_bd_net [get_bd_pins hdmi_vidrst_const/dout] [get_bd_pins v_vid_in_axi4s_0/vid_io_in_reset]

assign_bd_address
regenerate_bd_layout
validate_bd_design
save_bd_design

set bd_files [get_files -quiet "*/${BD_NAME}.bd"]
if {[llength $bd_files] > 0} {
    set_property synth_checkpoint_mode None $bd_files
}

make_wrapper -files [get_files ${BD_NAME}.bd] -top
set project_dir [file normalize [get_property DIRECTORY [current_project]]]
set wrapper_glob [file join $project_dir "${current_project_name}.gen" "sources_1" "bd" $BD_NAME "hdl" "${BD_NAME}_wrapper.v"]
set wrapper_matches [glob -nocomplain $wrapper_glob]
if {[llength $wrapper_matches] == 0} {
    error "Wrapper file not found at expected path: $wrapper_glob"
}
set wrapper_path [file normalize [lindex $wrapper_matches 0]]
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
puts "    - HDMI ingress chain: dvi2rgb -> color_swap -> v_vid_in_axi4s"
puts "    - CDC + packetizer: axis_data_fifo(async) -> HDMI_Axis_Packetizer"
puts "    - AES plaintext source is packetizer output (pkt_pt_axis_in kept external-only)"
puts "    - External HDMI interfaces: hdmi_in, hdmi_in_ddc, hdmi_in_hpd"
puts "    - External AXIS insertion point: pkt_pt_axis_in"
puts ""
puts "  What remains for the literal HDMI TX path:"
puts "    - Tighten packetizer header fields to full OS-VideoSDR runtime-config contract"
puts "    - Add AES control sequencer to program nonce/length per emitted packet"
puts "    - Replace/extend DDR writer with packet-ready TX ring writer for PS Ethernet send"
puts "==========================================================="