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
#  This scaffold creates the crypto + DDR-writer half of the design with
#  PS-programmable sequencer control and HDMI ingress packetization.
# ──────────────────────────────────────────────────────────────

set AES_MODULE   "AXI_AES_GCM_Stream_wrapper"
set AES_INST     "aes_gcm_0"
set WRITER_MODULE "AXI_PingPong_Ctrl_wrapper"
set WRITER_INST  "frame_writer_0"
set PACKETIZER_MODULE  "HDMI_Axis_Packetizer_wrapper"
set PACKETIZER_INST    "hdmi_packetizer_0"
set SEQUENCER_MODULE   "AES_GCM_Session_Sequencer_wrapper"
set SEQUENCER_INST     "aes_seq_0"
set BD_NAME            "hdmi_aes_tx"

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

proc ensure_local_rtl_source {repo_root file_name} {
    set src_path [file normalize [file join $repo_root "AES_VERILOG.srcs" "sources_1" "new" $file_name]]
    if {![file exists $src_path]} {
        error "Required local RTL source is missing: $src_path"
    }
    if {[llength [get_files -quiet $src_path]] == 0} {
        add_files -norecurse $src_path
    }
}

proc ensure_local_constraint_source {repo_root file_name} {
    set xdc_path [file normalize [file join $repo_root "pynq" "constraints" $file_name]]
    if {![file exists $xdc_path]} {
        error "Required local constraints file is missing: $xdc_path"
    }
    if {[llength [get_files -quiet $xdc_path]] == 0} {
        add_files -fileset constrs_1 -norecurse $xdc_path
    }
}

proc reset_bd_in_place {bd_name} {
    # Rebuild the BD IN PLACE instead of deleting/recreating the .bd file.
    # Deleting the .bd and its generated dirs breaks automatic hierarchy
    # tracking in Vivado 2024.1: the project then has an empty compile order
    # and silently auto-swaps the top module (filemgmt 20-742), synthesizing a
    # bare RTL module as top. Keep the project's .bd association intact, strip
    # the design contents, and rebuild below.
    #
    # Only the mref cache is deleted: it caches module-reference port lists,
    # and a stale copy makes freshly added wrapper ports invisible on the
    # cells ([BD 41-84]). It is regenerated on demand.
    set _proj_dir [file normalize [get_property DIRECTORY [current_project]]]
    set _bd_gen_dir [file normalize [file join $_proj_dir "HDMI_AES_TX.gen" "sources_1" "bd" ${bd_name}]]
    catch {file delete -force [file join [file dirname $_bd_gen_dir] "mref"]}

    set _bd_files [get_files -quiet "*/${bd_name}.bd"]
    if {[llength $_bd_files] > 0} {
        puts "INFO: resetting existing BD in place: [lindex $_bd_files 0]"
        open_bd_design [lindex $_bd_files 0]
        foreach n [get_bd_intf_nets -quiet *]   { catch {delete_bd_objs [get_bd_intf_nets $n]} }
        foreach n [get_bd_nets -quiet *]        { catch {delete_bd_objs [get_bd_nets $n]} }
        foreach c [get_bd_cells -quiet *]       { catch {delete_bd_objs [get_bd_cells $c]} }
        foreach p [get_bd_ports -quiet *]       { catch {delete_bd_objs [get_bd_ports $p]} }
        foreach p [get_bd_intf_ports -quiet *]  { catch {delete_bd_objs [get_bd_intf_ports $p]} }
    } else {
        puts "INFO: creating new BD: $bd_name"
        create_bd_design $bd_name
    }
}

proc connect_if_unconnected {src dst} {
    if {[llength [get_bd_nets -quiet -of_objects $dst]] == 0} {
        connect_bd_net $src $dst
    }
}

proc force_connect_bd_net {src dst} {
    set existing_nets [get_bd_nets -quiet -of_objects $dst]
    if {[llength $existing_nets] > 0} {
        disconnect_bd_net [lindex $existing_nets 0] $dst
    }
    connect_bd_net $src $dst
}

if {[catch {current_project} current_proj]} {
    error "No Vivado project is open. Source pynq/create_hdmi_aes_tx_project.tcl first."
}

set current_project_name [get_property NAME [current_project]]
if {$current_project_name ne "HDMI_AES_TX"} {
    error "Current project is '$current_project_name'. Open or create the dedicated HDMI_AES_TX project before sourcing this script."
}

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file dirname $script_dir]

# Ensure module-reference RTL is present even when this script is sourced
# without re-running create_hdmi_aes_tx_project.tcl.
ensure_local_rtl_source $repo_root "AES_GCM_Session_Sequencer_wrapper.v"
ensure_local_rtl_source $repo_root "AES_GCM_Session_Sequencer.sv"
ensure_local_rtl_source $repo_root "HDMI_Axis_Packetizer_wrapper.v"
ensure_local_rtl_source $repo_root "HDMI_Axis_Packetizer.sv"
ensure_local_rtl_source $repo_root "VideoBeatCounter_wrapper.v"
ensure_local_rtl_source $repo_root "VideoBeatCounter.sv"
ensure_local_constraint_source $repo_root "hdmi_aes_tx_pynq_z2.xdc"
update_compile_order -fileset sources_1

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
require_ip "xilinx.com:ip:xlconcat:2.1"
require_ip "xilinx.com:ip:axi_gpio:2.0"
require_ip "xilinx.com:ip:axis_data_fifo:2.0"
require_ip "xilinx.com:ip:proc_sys_reset:5.0"
require_ip "xilinx.com:ip:util_vector_logic:2.0"
require_ip "digilentinc.com:ip:dvi2rgb:1.7"
require_ip "digilentinc.com:ip:axi_dynclk:1.0"
require_ip "digilentinc.com:ip:rgb2dvi:1.2"

set pynq_part [detect_pynq_board_part]
if {$pynq_part ne ""} {
    set_property board_part $pynq_part [current_project]
}

reset_bd_in_place $BD_NAME

create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7
set_property -dict [list \
    CONFIG.PCW_EN_CLK0_PORT {1} \
    CONFIG.PCW_EN_CLK1_PORT {1} \
    CONFIG.PCW_EN_CLK2_PORT {1} \
    CONFIG.PCW_FCLK_CLK1_BUF {TRUE} \
    CONFIG.PCW_FCLK_CLK2_BUF {TRUE} \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {50} \
    CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {142} \
    CONFIG.PCW_FPGA2_PERIPHERAL_FREQMHZ {200} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
] [get_bd_cells ps7]

create_bd_cell -type module -reference $AES_MODULE $AES_INST
create_bd_cell -type module -reference $WRITER_MODULE $WRITER_INST
create_bd_cell -type module -reference $PACKETIZER_MODULE $PACKETIZER_INST
create_bd_cell -type module -reference $SEQUENCER_MODULE $SEQUENCER_INST
create_bd_cell -type module -reference VideoBeatCounter_wrapper video_beat_counter_0

# Refresh module references from the current RTL on disk. BD module refs
# cache the analyzed port list; without this, ports added to the wrappers
# after a previous session are missing and connect_bd_net fails with
# [BD 41-84] "required object is not specified".
# Pass instance NAMES (documented form), not cell objects: object form
# returns failure silently in 2024.1.
set _mrrc [update_module_reference -quiet aes_gcm_0 frame_writer_0 hdmi_packetizer_0 aes_seq_0]
puts "INFO: update_module_reference rc=$_mrrc"
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
    CONFIG.TUSER_WIDTH {1} \
    CONFIG.FIFO_DEPTH {2048} \
] [get_bd_cells hdmi_axis_cdc_fifo]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 rst_const1
set_property -dict [list \
    CONFIG.CONST_VAL {1} \
    CONFIG.CONST_WIDTH {1} \
] [get_bd_cells rst_const1]

create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 rstn_to_rst
set_property -dict [list \
    CONFIG.C_OPERATION {not} \
    CONFIG.C_SIZE {1} \
] [get_bd_cells rstn_to_rst]

create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_100m
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_142m

# Matches the official PYNQ-Z2 base overlay pattern: a reset pulse generated
# in the recovered pixel-clock domain, triggered by pixel clock lock
# acquisition (aux_reset_in <- aPixelClkLckd). v_vid_in_axi4s and vtc_in need
# this to initialize correctly once a real HDMI source starts driving TMDS.
# Without it v_vid_in_axi4s can sit in an undefined state forever: verified on
# hardware that vtc_in still detects correct timing (1650x750 for 720p60)
# while zero AXI4-Stream video beats ever reach the packetizer. Replaces the
# old permanent hdmi_vidrst_const=0 tie-off, which never reset this IP at all.
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_pixelclk
# proc_sys_reset v5.0 (Vivado 2024.1) defaults C_AUX_RESET_HIGH=1 (active-HIGH,
# verified in the IP's component.xml). aPixelClkLckd is HIGH while the source is
# locked, so with the default this block would hold peripheral_reset asserted
# for as long as a source is connected -> v_vid_in vid_io_in_reset stuck HIGH
# -> video pipeline permanently dead. Set active-LOW aux so "locked" releases.
set_property -dict [list \
    CONFIG.C_AUX_RESET_HIGH {0} \
] [get_bd_cells rst_pixelclk]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 irq_concat
set_property CONFIG.NUM_PORTS {3} [get_bd_cells irq_concat]

apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable"} \
    [get_bd_cells ps7]

# The PYNQ-Z2 board preset applied by automation above may reset PCW_USE_FABRIC_INTERRUPT.
# Re-assert it here so IRQ_F2P is exposed on the PS7 cell.
set_property CONFIG.PCW_USE_FABRIC_INTERRUPT {1} [get_bd_cells ps7]
set_property CONFIG.PCW_IRQ_F2P_INTR {1} [get_bd_cells ps7]

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

apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {
        Clk_master {/ps7/FCLK_CLK0 (100 MHz)}
        Clk_slave  {Auto}
        Clk_xbar   {Auto}
        Master     {/ps7/M_AXI_GP0}
        Slave      {/$SEQUENCER_INST/s_axi}
        ddr_seg    {Auto}
        intc_ip    {Auto}
        master_apm {0}
    } [get_bd_intf_pins $SEQUENCER_INST/s_axi]

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
connect_bd_net [get_bd_pins $SEQUENCER_INST/cfg_session_id] [get_bd_pins $PACKETIZER_INST/cfg_session_id]
connect_bd_net [get_bd_pins $SEQUENCER_INST/cfg_stream_id] [get_bd_pins $PACKETIZER_INST/cfg_stream_id]
connect_bd_net [get_bd_pins $SEQUENCER_INST/cfg_payload_type] [get_bd_pins $PACKETIZER_INST/cfg_payload_type]
connect_bd_net [get_bd_pins $SEQUENCER_INST/cfg_key_id] [get_bd_pins $PACKETIZER_INST/cfg_key_id]
connect_bd_net [get_bd_pins $SEQUENCER_INST/cfg_payload_bytes] [get_bd_pins $PACKETIZER_INST/cfg_payload_bytes]
connect_bd_net [get_bd_pins $SEQUENCER_INST/cfg_nonce_counter] [get_bd_pins $PACKETIZER_INST/cfg_nonce_counter]
connect_bd_net [get_bd_pins $SEQUENCER_INST/cfg_enable] [get_bd_pins $PACKETIZER_INST/cfg_enable]
# Diagnostic counter readback: packetizer -> sequencer (new read-only AXI-Lite
# registers REG_VIDEO_BEAT_COUNT_* / REG_VIDEO_FRAME_COUNT_* at 0x48-0x54).
connect_bd_net [get_bd_pins $PACKETIZER_INST/dbg_video_beat_count]  [get_bd_pins $SEQUENCER_INST/dbg_video_beat_count]
connect_bd_net [get_bd_pins $PACKETIZER_INST/dbg_video_frame_count] [get_bd_pins $SEQUENCER_INST/dbg_video_frame_count]

# NOTE: do NOT tap hdmi_axis_cdc_fifo/S_AXIS_tvalid into a probe here. A BD pin
# can only sit on one net, so such a tap DISCONNECTS tvalid from the video
# interface connection and grounds it (BD 41-1271/41-166 warnings), killing
# the real video path. The packetizer's own counters above are safe (they
# observe their internal s_axis pins directly). The prefifo probe cell
# (video_beat_counter_0) remains with its input tied low and reads 0 - left in
# place to avoid touching sequencer ports again; ignore its register.

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

connect_bd_intf_net [get_bd_intf_pins $PACKETIZER_INST/m_axis_pkt] [get_bd_intf_pins $SEQUENCER_INST/s_axis]
connect_bd_intf_net [get_bd_intf_pins $SEQUENCER_INST/m_axis] [get_bd_intf_pins $AES_INST/S_AXIS_PT]
connect_bd_intf_net [get_bd_intf_pins $AES_INST/M_AXIS_CT] [get_bd_intf_pins $WRITER_INST/S_AXIS_SRC]
connect_bd_intf_net [get_bd_intf_pins $SEQUENCER_INST/m_axi] [get_bd_intf_pins $AES_INST/s_axi]

# Remove any stale top-level IRQ ports from previous BD runs
foreach _irq_port {frame_writer_irq hdmi_hpd_irq hdmi_vtc_irq} {
    if {[llength [get_bd_ports -quiet $_irq_port]] > 0} {
        delete_bd_objs [get_bd_ports $_irq_port]
    }
}
# Route IRQs into PS7 fabric interrupt via xlconcat
# In0=frame_writer (IRQ 61), In1=hdmi_hpd (IRQ 62), In2=vtc (IRQ 63)
connect_bd_net [get_bd_pins $WRITER_INST/irq]              [get_bd_pins irq_concat/In0]
connect_bd_net [get_bd_pins axi_gpio_hdmiin/ip2intc_irpt]  [get_bd_pins irq_concat/In1]
connect_bd_net [get_bd_pins vtc_in/irq]                    [get_bd_pins irq_concat/In2]
set irq_f2p_pin [get_bd_pins -quiet ps7/IRQ_F2P]
if {[llength $irq_f2p_pin] == 0} {
    # In some Vivado versions the port needs to be found hierarchically
    set irq_f2p_pin [get_bd_pins -hierarchical -quiet -filter {NAME =~ IRQ_F2P}]
}
if {[llength $irq_f2p_pin] > 0} {
    connect_bd_net [get_bd_pins irq_concat/dout] [lindex $irq_f2p_pin 0]
    puts "INFO: irq_concat/dout connected to PS7 IRQ_F2P."
} else {
    puts "WARNING: ps7/IRQ_F2P pin not found - IRQ will not reach PS. Bitstream will still build."
}
# HPD is a physical board signal - still exposed as a real port
if {[llength [get_bd_ports -quiet hdmi_in_hpd]] > 0} {
    connect_bd_net [get_bd_ports hdmi_in_hpd] [get_bd_pins axi_gpio_hdmiin/gpio_io_o]
} else {
    create_bd_port -dir O hdmi_in_hpd
    connect_bd_net [get_bd_ports hdmi_in_hpd] [get_bd_pins axi_gpio_hdmiin/gpio_io_o]
}

set ps_fclk0_pin       [get_bd_pins ps7/FCLK_CLK0]
set ps_fclk1_pin       [get_bd_pins ps7/FCLK_CLK1]
set ps_fclk2_pin       [get_bd_pins ps7/FCLK_CLK2]
set ps_fclk_resetn_pin [get_bd_pins ps7/FCLK_RESET0_N]
set ps_hp0_aclk_pin    [get_bd_pins ps7/S_AXI_HP0_ACLK]

connect_if_unconnected $ps_fclk0_pin $ps_hp0_aclk_pin
connect_if_unconnected $ps_fclk1_pin [get_bd_pins v_vid_in_axi4s_0/aclk]

connect_if_unconnected $ps_fclk0_pin [get_bd_pins hdmi_axis_cdc_fifo/m_axis_aclk]
connect_if_unconnected $ps_fclk1_pin [get_bd_pins hdmi_axis_cdc_fifo/s_axis_aclk]
connect_if_unconnected $ps_fclk0_pin [get_bd_pins $PACKETIZER_INST/aclk]
connect_if_unconnected $ps_fclk0_pin [get_bd_pins rst_ps7_100m/slowest_sync_clk]
connect_if_unconnected $ps_fclk1_pin [get_bd_pins rst_ps7_142m/slowest_sync_clk]

connect_if_unconnected $ps_fclk_resetn_pin [get_bd_pins rstn_to_rst/Op1]
connect_if_unconnected [get_bd_pins rstn_to_rst/Res] [get_bd_pins rst_ps7_100m/ext_reset_in]
connect_if_unconnected [get_bd_pins rstn_to_rst/Res] [get_bd_pins rst_ps7_142m/ext_reset_in]
connect_if_unconnected [get_bd_pins rst_const1/dout] [get_bd_pins rst_ps7_100m/dcm_locked]
connect_if_unconnected [get_bd_pins rst_const1/dout] [get_bd_pins rst_ps7_142m/dcm_locked]

# rst_pixelclk lives in the recovered pixel-clock domain and resets while the
# pixel clock is NOT locked. proc_sys_reset v5.0 defaults BOTH reset inputs to
# ACTIVE-HIGH, so:
#  - ext_reset_in takes rstn_to_rst/Res (the active-high form of
#    FCLK_RESET0_N). The BD automation had auto-connected the active-LOW
#    FCLK_RESET0_N directly here, which held the block permanently asserted.
#  - aux_reset_in takes aPixelClkLckd with C_AUX_RESET_HIGH=0 (set at cell
#    creation), so "locked" (high) RELEASES the reset instead of asserting it.
force_connect_bd_net [get_bd_pins rstn_to_rst/Res] [get_bd_pins rst_pixelclk/ext_reset_in]
force_connect_bd_net [get_bd_pins dvi2rgb_0/PixelClk] [get_bd_pins rst_pixelclk/slowest_sync_clk]
connect_if_unconnected [get_bd_pins rst_const1/dout] [get_bd_pins rst_pixelclk/dcm_locked]
connect_bd_net [get_bd_pins dvi2rgb_0/aPixelClkLckd] [get_bd_pins rst_pixelclk/aux_reset_in]

foreach p [list \
    [get_bd_pins hp0_mem_ic/ACLK] \
    [get_bd_pins hp0_mem_ic/S00_ACLK] \
    [get_bd_pins hp0_mem_ic/M00_ACLK] \
    [get_bd_pins $AES_INST/S_AXI_ACLK] \
    [get_bd_pins $WRITER_INST/S_AXI_ACLK] \
    [get_bd_pins $SEQUENCER_INST/aclk] \
    [get_bd_pins vtc_in/s_axi_aclk] \
    [get_bd_pins axi_gpio_hdmiin/s_axi_aclk] \
] {
    connect_if_unconnected $ps_fclk0_pin $p
}

force_connect_bd_net [get_bd_pins rst_ps7_100m/interconnect_aresetn] [get_bd_pins hp0_mem_ic/ARESETN]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins hp0_mem_ic/S00_ARESETN]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins hp0_mem_ic/M00_ARESETN]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins $AES_INST/S_AXI_ARESETN]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins $WRITER_INST/S_AXI_ARESETN]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins $SEQUENCER_INST/aresetn]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins vtc_in/s_axi_aresetn]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins axi_gpio_hdmiin/s_axi_aresetn]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins $PACKETIZER_INST/aresetn]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins dvi2rgb_0/aRst_n]

force_connect_bd_net [get_bd_pins rst_ps7_142m/peripheral_aresetn] [get_bd_pins v_vid_in_axi4s_0/aresetn]
force_connect_bd_net [get_bd_pins rst_ps7_142m/peripheral_aresetn] [get_bd_pins hdmi_axis_cdc_fifo/s_axis_aresetn]
force_connect_bd_net [get_bd_pins rst_ps7_142m/peripheral_aresetn] [get_bd_pins video_beat_counter_0/aresetn]
connect_bd_net [get_bd_pins ps7/FCLK_CLK1] [get_bd_pins video_beat_counter_0/aclk]
# vtc_in/resetn now comes from rst_pixelclk (dvi2rgb_0_PixelClk domain, same
# clock as vtc_in/clk) instead of the 142MHz PS-side reset. This matches the
# official PYNQ-Z2 base overlay and removes the cross-domain reset entirely
# for this net, rather than merely avoiding one specific Vivado timing check.
force_connect_bd_net [get_bd_pins rst_pixelclk/peripheral_aresetn] [get_bd_pins vtc_in/resetn]

set ps7_axi_rst_map [list \
    [list ps7_axi_periph/ARESETN rst_ps7_100m/interconnect_aresetn] \
    [list ps7_axi_periph/S00_ARESETN rst_ps7_100m/peripheral_aresetn] \
    [list ps7_axi_periph/M00_ARESETN rst_ps7_100m/peripheral_aresetn] \
    [list ps7_axi_periph/M01_ARESETN rst_ps7_100m/peripheral_aresetn] \
    [list ps7_axi_periph/M02_ARESETN rst_ps7_100m/peripheral_aresetn] \
    [list ps7_axi_periph/M03_ARESETN rst_ps7_100m/peripheral_aresetn] \
]
foreach pair $ps7_axi_rst_map {
    set sink_pin [get_bd_pins -quiet [lindex $pair 0]]
    set src_pin  [get_bd_pins -quiet [lindex $pair 1]]
    if {[llength $sink_pin] > 0 && [llength $src_pin] > 0} {
        force_connect_bd_net $src_pin $sink_pin
    }
}
connect_bd_net [get_bd_pins dvi2rgb_0/aPixelClkLckd] [get_bd_pins axi_gpio_hdmiin/gpio2_io_i]

connect_if_unconnected $ps_fclk2_pin [get_bd_pins dvi2rgb_0/RefClk]
connect_bd_net [get_bd_pins dvi2rgb_0/PixelClk] [get_bd_pins v_vid_in_axi4s_0/vid_io_in_clk]
connect_bd_net [get_bd_pins dvi2rgb_0/PixelClk] [get_bd_pins vtc_in/clk]
connect_bd_net [get_bd_pins rst_pixelclk/peripheral_reset] [get_bd_pins v_vid_in_axi4s_0/vid_io_in_reset]

# FCLK0 was dropped to 75 MHz (opens the GHASH GF-multiply timing margin from
# ~0.2ns to ~3.5ns). Vivado's automation updates some interface FREQ_HZ
# metadata but leaves custom-IP interfaces at their stale 100 MHz creation-
# time defaults, which fails validate_bd_design. Force all of them.
foreach _ipin [list \
    [get_bd_intf_pins -quiet $WRITER_INST/M_AXI] \
    [get_bd_intf_pins -quiet $WRITER_INST/S_AXIS_SRC] \
    [get_bd_intf_pins -quiet $AES_INST/S_AXIS_PT] \
    [get_bd_intf_pins -quiet $AES_INST/M_AXIS_CT] \
    [get_bd_intf_pins -quiet $AES_INST/S_AXI] \
    [get_bd_intf_pins -quiet $SEQUENCER_INST/s_axis] \
    [get_bd_intf_pins -quiet $PACKETIZER_INST/s_axis_video] \
    [get_bd_intf_pins -quiet $PACKETIZER_INST/m_axis_pkt] \
    [get_bd_intf_pins -quiet hdmi_axis_cdc_fifo/M_AXIS] \
] {
    if {[llength $_ipin] > 0} {
        set_property CONFIG.FREQ_HZ {50000000} $_ipin
    }
}
puts "FREQ_HZ forced on stale FCLK0-domain intf pins"

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
puts "    - CDC + packetizer: axis_data_fifo(async) -> HDMI_Axis_Packetizer_wrapper"
puts "    - PS->sequencer AXI-Lite control path for session/key/nonce/payload policy"
puts "    - AES session sequencer gates AXIS and programs AES nonce/lengths per packet"
puts "    - AES plaintext source is sequencer output"
puts "    - External HDMI interfaces: hdmi_in, hdmi_in_ddc, hdmi_in_hpd"
puts ""
puts "  What remains for the literal HDMI TX path:"
puts "    - Replace/extend DDR writer with packet-ready TX ring writer for PS Ethernet send"
puts "==========================================================="