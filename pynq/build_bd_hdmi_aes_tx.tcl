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
set WRITER_MODULE "DDRRingWriter_wrapper"
set WRITER_INST  "frame_writer_0"
set INJECTOR_MODULE "NoncePrefixInject_wrapper"
set INJECTOR_INST "nonce_prefix_0"
set PACKETIZER_MODULE  "HDMI_Axis_Packetizer_wrapper"
set PACKETIZER_INST    "hdmi_packetizer_0"
set SEQUENCER_MODULE   "AES_GCM_Session_Sequencer_wrapper"
set SEQUENCER_INST     "aes_seq_0"
set CLK_MUX_MODULE     "clk_mux_ctrl"
set CLK_MUX_INST       "aes_clk_mux"
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

# Generate the 128-line dvi2rgb EDID from the checked-in fetched source.
# This never modifies the PYNQ vendor checkout.
set edid_generator [file normalize [file join $repo_root "pynq" "generate_720p30_edid.py"]]
set edid_hex       [file normalize [file join $repo_root "pynq" "720p30_edid.hex"]]
set native_edid_src [file normalize [file join $repo_root "pynq" "720p30_edid.data"]]
require_file $edid_generator "720p30 EDID generator"
require_file $edid_hex "720p30 EDID source"
if {[catch {exec python $edid_generator --source $edid_hex --output $native_edid_src} _edid_result]} {
    error "720p30 EDID generation failed: $_edid_result"
}
puts $_edid_result

# Ensure module-reference RTL is present even when this script is sourced
# without re-running create_hdmi_aes_tx_project.tcl.
ensure_local_rtl_source $repo_root "AES_GCM_Session_Sequencer_wrapper.v"
ensure_local_rtl_source $repo_root "AES_GCM_Session_Sequencer.sv"
ensure_local_rtl_source $repo_root "HDMI_Axis_Packetizer_wrapper.v"
ensure_local_rtl_source $repo_root "HDMI_Axis_Packetizer.sv"
ensure_local_rtl_source $repo_root "VideoBeatCounter_wrapper.v"
ensure_local_rtl_source $repo_root "VideoBeatCounter.sv"
ensure_local_rtl_source $repo_root "VideoFrontEndProbe_wrapper.v"
ensure_local_rtl_source $repo_root "VideoFrontEndProbe.sv"
ensure_local_rtl_source $repo_root "VideoStatusProbe_wrapper.v"
ensure_local_rtl_source $repo_root "VideoStatusProbe.sv"
ensure_local_rtl_source $repo_root "DDRRingWriter_wrapper.v"
ensure_local_rtl_source $repo_root "DDRRingWriter.sv"
ensure_local_rtl_source $repo_root "NoncePrefixInject_wrapper.v"
ensure_local_rtl_source $repo_root "NoncePrefixInject.sv"
ensure_local_rtl_source $repo_root "clk_mux_ctrl.v"
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
require_ip "xilinx.com:ip:xlslice:1.0"
require_ip "xilinx.com:ip:clk_wiz:6.0"
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
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {142} \
    CONFIG.PCW_FPGA2_PERIPHERAL_FREQMHZ {200} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
] [get_bd_cells ps7]

create_bd_cell -type module -reference $AES_MODULE $AES_INST
create_bd_cell -type module -reference $WRITER_MODULE $WRITER_INST
create_bd_cell -type module -reference $INJECTOR_MODULE $INJECTOR_INST
create_bd_cell -type module -reference $PACKETIZER_MODULE $PACKETIZER_INST
create_bd_cell -type module -reference $SEQUENCER_MODULE $SEQUENCER_INST
create_bd_cell -type module -reference VideoBeatCounter_wrapper video_beat_counter_0
create_bd_cell -type module -reference VideoBeatCounter_wrapper cdc_out_probe_0
create_bd_cell -type module -reference VideoFrontEndProbe_wrapper video_fe_probe_0
create_bd_cell -type module -reference VideoStatusProbe_wrapper video_status_probe_0
create_bd_cell -type module -reference $CLK_MUX_MODULE $CLK_MUX_INST

# Refresh module references from the current RTL on disk. BD module refs
# cache the analyzed port list; without this, ports added to the wrappers
# after a previous session are missing and connect_bd_net fails with
# [BD 41-84] "required object is not specified".
# Pass instance NAMES (documented form), not cell objects: object form
# returns failure silently in 2024.1.
set _mrrc [update_module_reference -quiet aes_gcm_0 frame_writer_0 nonce_prefix_0 hdmi_packetizer_0 aes_seq_0 aes_clk_mux video_beat_counter_0 video_fe_probe_0 video_status_probe_0]
create_bd_cell -type ip -vlnv digilentinc.com:ip:dvi2rgb:1.7 dvi2rgb_0
set_property -dict [list \
    CONFIG.kAddBUFG {false} \
    CONFIG.kClkRange {4} \
    CONFIG.kEdidFileName {720p_edid.data} \
    CONFIG.kRstActiveHigh {false} \
] [get_bd_cells dvi2rgb_0]
# The stock PYNQ file is a 720p60 DTD. Copy the generated native 720p30
# file into this module-reference source tree before synthesis generation.
set native_edid_dst [file normalize [file join \
    [get_property DIRECTORY [current_project]] \
    "HDMI_AES_TX.gen" "sources_1" "bd" $BD_NAME "ip" \
    "hdmi_aes_tx_dvi2rgb_0_0" "src" "720p_edid.data"]]
file mkdir [file dirname $native_edid_dst]
file copy -force $native_edid_src $native_edid_dst


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

# Packet FIFO between the packetizer and the sequencer: decouples the
# packetizer output from the sequencer's per-packet control states
# (setup, tag reads, GHASH reads). Store-and-forward packet mode keeps
# complete 77-beat packets so the sequencer always sees whole packets.
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 packet_seq_fifo_0
set_property -dict [list \
    CONFIG.IS_ACLK_ASYNC {0} \
    CONFIG.TDATA_NUM_BYTES {16} \
    CONFIG.HAS_TKEEP {1} \
    CONFIG.HAS_TSTRB {0} \
    CONFIG.HAS_TLAST {1} \
    CONFIG.TUSER_WIDTH {0} \
    CONFIG.TID_WIDTH {0} \
    CONFIG.TDEST_WIDTH {0} \
    CONFIG.HAS_TREADY {1} \
    CONFIG.FIFO_DEPTH {256} \
    CONFIG.FIFO_MODE {2} \
    CONFIG.FIFO_MEMORY_TYPE {auto} \
    CONFIG.HAS_WR_DATA_COUNT {1} \
    CONFIG.HAS_RD_DATA_COUNT {1} \
] [get_bd_cells packet_seq_fifo_0]

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
# The aux_reset_in (gpio[0] from axi_gpio_clkctrl) is active-HIGH: 1 = hold
# the design domain in reset during a frequency switch.
set_property -dict [list \
    CONFIG.C_AUX_RESET_HIGH {1} \
] [get_bd_cells rst_ps7_100m]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_142m

# ------------------------------------------------------------------
# Runtime-selectable design clock (50 / 75 / 100 MHz), PS-controlled.
# FCLK0 is the fixed 100 MHz master. The MMCM generates all three rates
# simultaneously (VCO 600 MHz: /12 = 50, /8 = 75, /6 = 100); a cascaded
# BUFGMUX_CTRL (aes_clk_mux) picks one for the whole design domain. The
# PS writes axi_gpio_clkctrl (its own AXI-Lite slave on the STABLE FCLK0
# branch of the interconnect) to switch: bit0 = domain reset request
# (proc_sys_reset aux_reset_in), bits[2:1] = mux select. Switching
# procedure (in tx_daemon.py): disable sequencer -> assert reset -> set
# select -> wait -> release reset -> reconfigure.
# ------------------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_aes
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.PRIM_SOURCE {No_buffer} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {75.000} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {50.000} \
    CONFIG.USE_LOCKED {false} \
    CONFIG.USE_RESET {false} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
] [get_bd_cells clk_wiz_aes]

# 3-bit PS-controlled GPIO on the stable FCLK0 domain:
#   gpio[0]   -> rst_ps7_100m/aux_reset_in (1 = hold design domain in reset)
#   gpio[2:1] -> aes_clk_mux/sel (00 = 50 MHz, 01 = 75 MHz, 10 = 100 MHz)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_clkctrl
set_property -dict [list \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_GPIO_WIDTH {3} \
] [get_bd_cells axi_gpio_clkctrl]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 clkctrl_rst_slice
set_property -dict [list \
    CONFIG.DIN_WIDTH {3} \
    CONFIG.DIN_FROM {0} \
    CONFIG.DIN_TO {0} \
    CONFIG.DOUT_WIDTH {1} \
] [get_bd_cells clkctrl_rst_slice]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 clkctrl_sel_slice
set_property -dict [list \
    CONFIG.DIN_WIDTH {3} \
    CONFIG.DIN_FROM {2} \
    CONFIG.DIN_TO {1} \
    CONFIG.DOUT_WIDTH {2} \
] [get_bd_cells clkctrl_sel_slice]

# Reset controller for the STABLE FCLK0 side (the PS->PL interconnect's S00
# branch and axi_gpio_clkctrl). It must NOT be gated by the domain-reset GPIO,
# or the PS could never release the switched domain again.
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_stable

# ------------------------------------------------------------------
# Clock pre-wiring (MUST run before the AXI automation below: the
# automation resolves each slave's clock from its existing ACLK net).
#   FCLK0 (100 MHz, stable) -> MMCM -> BUFGMUX -> design clock
# ------------------------------------------------------------------
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins clk_wiz_aes/clk_in1]
connect_bd_net [get_bd_pins clk_wiz_aes/clk_out3] [get_bd_pins $CLK_MUX_INST/clk_in0]
connect_bd_net [get_bd_pins clk_wiz_aes/clk_out2] [get_bd_pins $CLK_MUX_INST/clk_in1]
connect_bd_net [get_bd_pins clk_wiz_aes/clk_out1] [get_bd_pins $CLK_MUX_INST/clk_in2]
set design_clk_pin [get_bd_pins $CLK_MUX_INST/clk_out]

# Design-domain clocks that NO BD automation rule queries are pre-wired to
# the mux output directly (the AES core's S_AXI_ACLK - driven by the
# sequencer's m_axi, not by the ps7 periph - plus the packetizer and the
# CDC FIFO's m_axis side and the domain reset controller).
# The four AXI-Lite slaves below are deliberately NOT pre-wired: the
# apply_bd_automation rule queries the slave clock frequency in MHz and
# crashes on a module-pin clock with no frequency metadata. They get wired
# to FCLK0 by the automation and re-routed to the mux afterwards (the
# interconnect M-port clocks are re-routed together with them).
foreach _p [list \
    [get_bd_pins $AES_INST/S_AXI_ACLK] \
    [get_bd_pins $PACKETIZER_INST/aclk] \
] {
    connect_if_unconnected $design_clk_pin $_p
}
connect_if_unconnected $design_clk_pin [get_bd_pins hdmi_axis_cdc_fifo/m_axis_aclk]
connect_if_unconnected $design_clk_pin [get_bd_pins packet_seq_fifo_0/s_axis_aclk]
connect_if_unconnected $design_clk_pin [get_bd_pins rst_ps7_100m/slowest_sync_clk]

# Stable-side clocking: clkctrl GPIO + stable reset controller stay on FCLK0.
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins axi_gpio_clkctrl/s_axi_aclk]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins rst_ps7_stable/slowest_sync_clk]

# Domain reset request + mux select from the PS GPIO (active-high aux reset).
# proc_sys_reset v5.0 defaults C_AUX_RESET_HIGH=1, so gpio[0]=1 asserts reset.
connect_bd_net [get_bd_pins axi_gpio_clkctrl/gpio_io_o] [get_bd_pins clkctrl_rst_slice/Din]
connect_bd_net [get_bd_pins axi_gpio_clkctrl/gpio_io_o] [get_bd_pins clkctrl_sel_slice/Din]
connect_bd_net [get_bd_pins clkctrl_rst_slice/Dout] [get_bd_pins rst_ps7_100m/aux_reset_in]
connect_bd_net [get_bd_pins clkctrl_sel_slice/Dout] [get_bd_pins $CLK_MUX_INST/sel]

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

# Clock-control GPIO: lives on the STABLE FCLK0 side of the interconnect
# (its ACLK was pre-wired to FCLK0), so it stays reachable while the design
# domain is held in reset during a frequency switch.
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {
        Clk_master {/ps7/FCLK_CLK0 (100 MHz)}
        Clk_slave  {Auto}
        Clk_xbar   {Auto}
        Master     {/ps7/M_AXI_GP0}
        Slave      {/axi_gpio_clkctrl/S_AXI}
        ddr_seg    {Auto}
        intc_ip    {Auto}
        master_apm {0}
    } [get_bd_intf_pins axi_gpio_clkctrl/S_AXI]

# Re-route the design-domain slaves and the injector clock from FCLK0
# (wired by the automation) to the switchable design clock. The interconnect
# S00 side and the clkctrl branch stay on stable FCLK0.
foreach _p [list \
    [get_bd_pins $WRITER_INST/S_AXI_ACLK] \
    [get_bd_pins $SEQUENCER_INST/aclk] \
    [get_bd_pins $INJECTOR_INST/aclk] \
    [get_bd_pins vtc_in/s_axi_aclk] \
    [get_bd_pins axi_gpio_hdmiin/s_axi_aclk] \
    [get_bd_pins ps7_axi_periph/M00_ACLK] \
    [get_bd_pins ps7_axi_periph/M01_ACLK] \
    [get_bd_pins ps7_axi_periph/M02_ACLK] \
    [get_bd_pins ps7_axi_periph/M03_ACLK] \
] {
    force_connect_bd_net $design_clk_pin $_p
}

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 hp0_mem_ic
set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {1} \
] [get_bd_cells hp0_mem_ic]

connect_bd_intf_net [get_bd_intf_pins $WRITER_INST/M_AXI] [get_bd_intf_pins hp0_mem_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins hp0_mem_ic/M00_AXI] [get_bd_intf_pins ps7/S_AXI_HP0]
connect_bd_intf_net [get_bd_intf_pins dvi2rgb_0/RGB] [get_bd_intf_pins color_swap_0/pixel_input]
connect_bd_intf_net [get_bd_intf_pins color_swap_0/pixel_output] [get_bd_intf_pins video_fe_probe_0/vid_io_in]
connect_bd_intf_net [get_bd_intf_pins video_fe_probe_0/vid_io_out] [get_bd_intf_pins v_vid_in_axi4s_0/vid_io_in]
connect_bd_net [get_bd_pins video_fe_probe_0/pixel_clk_count] [get_bd_pins $SEQUENCER_INST/dbg_pixelclk_count]
connect_bd_net [get_bd_pins video_fe_probe_0/de_count] [get_bd_pins $SEQUENCER_INST/dbg_de_count]
# v_vid_in health probes: coupler overflow/underflow + vid_io_in_reset level.
connect_bd_net [get_bd_pins v_vid_in_axi4s_0/overflow] [get_bd_pins video_status_probe_0/vid_overflow]
connect_bd_net [get_bd_pins v_vid_in_axi4s_0/underflow] [get_bd_pins video_status_probe_0/vid_underflow]
connect_bd_net [get_bd_pins rst_pixelclk/peripheral_reset] [get_bd_pins video_status_probe_0/vid_reset_async]
connect_bd_net [get_bd_pins ps7/FCLK_CLK1] [get_bd_pins video_status_probe_0/aclk]
connect_bd_net [get_bd_pins rst_ps7_142m/peripheral_aresetn] [get_bd_pins video_status_probe_0/aresetn]
connect_bd_net [get_bd_pins video_status_probe_0/overflow_count] [get_bd_pins $SEQUENCER_INST/dbg_vid_overflow_count]
connect_bd_net [get_bd_pins video_status_probe_0/underflow_count] [get_bd_pins $SEQUENCER_INST/dbg_vid_underflow_count]
connect_bd_net [get_bd_pins video_status_probe_0/reset_pulse_count] [get_bd_pins $SEQUENCER_INST/dbg_vid_reset_pulse_count]
connect_bd_net [get_bd_pins video_status_probe_0/reset_level] [get_bd_pins $SEQUENCER_INST/dbg_vid_reset_level]
connect_bd_intf_net [get_bd_intf_pins v_vid_in_axi4s_0/vtiming_out] [get_bd_intf_pins vtc_in/vtiming_in]
connect_bd_intf_net [get_bd_intf_pins v_vid_in_axi4s_0/video_out] [get_bd_intf_pins video_beat_counter_0/s_axis_video]
connect_bd_intf_net [get_bd_intf_pins video_beat_counter_0/m_axis_video] [get_bd_intf_pins hdmi_axis_cdc_fifo/S_AXIS]
connect_bd_net [get_bd_pins video_beat_counter_0/count] [get_bd_pins $SEQUENCER_INST/dbg_prefifo_beats]
connect_bd_net [get_bd_pins video_beat_counter_0/valid_cycles] [get_bd_pins $SEQUENCER_INST/dbg_prefifo_valid_cycles]
connect_bd_net [get_bd_pins video_beat_counter_0/ready_cycles] [get_bd_pins $SEQUENCER_INST/dbg_prefifo_ready_cycles]
# Second inline VideoBeatCounter between the CDC FIFO and the packetizer:
# its handshake count is what actually reaches the packetizer, so comparing
# it against video_beat_counter_0/count names the exact drop stage.
connect_bd_intf_net [get_bd_intf_pins hdmi_axis_cdc_fifo/M_AXIS] [get_bd_intf_pins cdc_out_probe_0/s_axis_video]
connect_bd_intf_net [get_bd_intf_pins cdc_out_probe_0/m_axis_video] [get_bd_intf_pins $PACKETIZER_INST/s_axis_video]
connect_bd_net [get_bd_pins cdc_out_probe_0/count] [get_bd_pins $SEQUENCER_INST/dbg_cdcout_beats]
# Latch the DE position at each coupler overflow, in the pixel domain.
connect_bd_net [get_bd_pins v_vid_in_axi4s_0/overflow] [get_bd_pins video_fe_probe_0/vid_overflow]
connect_bd_net [get_bd_pins video_fe_probe_0/de_at_overflow] [get_bd_pins $SEQUENCER_INST/dbg_de_at_overflow]
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
# the real video path. Use inline passthrough probe cells instead.

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

connect_bd_intf_net [get_bd_intf_pins $PACKETIZER_INST/m_axis_pkt] [get_bd_intf_pins packet_seq_fifo_0/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins packet_seq_fifo_0/M_AXIS] [get_bd_intf_pins $SEQUENCER_INST/s_axis]
connect_bd_intf_net [get_bd_intf_pins $SEQUENCER_INST/m_axis] [get_bd_intf_pins $AES_INST/S_AXIS_PT]
connect_bd_intf_net [get_bd_intf_pins $AES_INST/M_AXIS_CT] [get_bd_intf_pins $INJECTOR_INST/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins $INJECTOR_INST/M_AXIS] [get_bd_intf_pins $WRITER_INST/S_AXIS]
connect_bd_net [get_bd_pins $SEQUENCER_INST/pkt_nonce] [get_bd_pins $INJECTOR_INST/pkt_nonce]
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

# The design clock (mux output) feeds the design-domain logic; the PS-side
# HP0 port stays on stable FCLK0 and hp0_mem_ic bridges the two (S00 = mux
# clock from the writer, M00 = FCLK0 to the PS). M_AXI_GP0 stays on FCLK0
# via the automation.
connect_if_unconnected $ps_fclk0_pin $ps_hp0_aclk_pin
connect_if_unconnected $ps_fclk1_pin [get_bd_pins v_vid_in_axi4s_0/aclk]

connect_if_unconnected $design_clk_pin [get_bd_pins hdmi_axis_cdc_fifo/m_axis_aclk]
connect_if_unconnected $ps_fclk1_pin [get_bd_pins hdmi_axis_cdc_fifo/s_axis_aclk]
connect_if_unconnected $design_clk_pin [get_bd_pins $PACKETIZER_INST/aclk]
connect_if_unconnected $design_clk_pin [get_bd_pins rst_ps7_100m/slowest_sync_clk]
connect_if_unconnected $ps_fclk1_pin [get_bd_pins rst_ps7_142m/slowest_sync_clk]

connect_if_unconnected $ps_fclk_resetn_pin [get_bd_pins rstn_to_rst/Op1]
connect_if_unconnected [get_bd_pins rstn_to_rst/Res] [get_bd_pins rst_ps7_100m/ext_reset_in]
connect_if_unconnected [get_bd_pins rstn_to_rst/Res] [get_bd_pins rst_ps7_142m/ext_reset_in]
connect_if_unconnected [get_bd_pins rstn_to_rst/Res] [get_bd_pins rst_ps7_stable/ext_reset_in]
connect_if_unconnected [get_bd_pins rst_const1/dout] [get_bd_pins rst_ps7_100m/dcm_locked]
connect_if_unconnected [get_bd_pins rst_const1/dout] [get_bd_pins rst_ps7_142m/dcm_locked]
connect_if_unconnected [get_bd_pins rst_const1/dout] [get_bd_pins rst_ps7_stable/dcm_locked]

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
    [get_bd_pins hp0_mem_ic/M00_ACLK] \
] {
    connect_if_unconnected $ps_fclk0_pin $p
}
connect_if_unconnected $design_clk_pin [get_bd_pins hp0_mem_ic/S00_ACLK]
foreach p [list \
    [get_bd_pins $AES_INST/S_AXI_ACLK] \
    [get_bd_pins $WRITER_INST/S_AXI_ACLK] \
    [get_bd_pins $INJECTOR_INST/aclk] \
    [get_bd_pins $SEQUENCER_INST/aclk] \
    [get_bd_pins vtc_in/s_axi_aclk] \
    [get_bd_pins axi_gpio_hdmiin/s_axi_aclk] \
] {
    connect_if_unconnected $design_clk_pin $p
}

force_connect_bd_net [get_bd_pins rst_ps7_100m/interconnect_aresetn] [get_bd_pins hp0_mem_ic/ARESETN]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins hp0_mem_ic/S00_ARESETN]
force_connect_bd_net [get_bd_pins rst_ps7_stable/peripheral_aresetn] [get_bd_pins hp0_mem_ic/M00_ARESETN]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins $AES_INST/S_AXI_ARESETN]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins $WRITER_INST/S_AXI_ARESETN]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins $INJECTOR_INST/aresetn]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins $SEQUENCER_INST/aresetn]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins vtc_in/s_axi_aresetn]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins axi_gpio_hdmiin/s_axi_aresetn]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins $PACKETIZER_INST/aresetn]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins packet_seq_fifo_0/s_axis_aresetn]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins dvi2rgb_0/aRst_n]

force_connect_bd_net [get_bd_pins rst_ps7_142m/peripheral_aresetn] [get_bd_pins v_vid_in_axi4s_0/aresetn]
force_connect_bd_net [get_bd_pins rst_ps7_142m/peripheral_aresetn] [get_bd_pins hdmi_axis_cdc_fifo/s_axis_aresetn]
force_connect_bd_net [get_bd_pins rst_ps7_142m/peripheral_aresetn] [get_bd_pins video_beat_counter_0/aresetn]
connect_bd_net [get_bd_pins ps7/FCLK_CLK1] [get_bd_pins video_beat_counter_0/aclk]
# cdc_out_probe_0 runs on the design clock with the packetizer.
connect_bd_net $design_clk_pin [get_bd_pins cdc_out_probe_0/aclk]
force_connect_bd_net [get_bd_pins rst_ps7_100m/peripheral_aresetn] [get_bd_pins cdc_out_probe_0/aresetn]
# vtc_in/resetn now comes from rst_pixelclk (dvi2rgb_0_PixelClk domain, same
# clock as vtc_in/clk) instead of the 142MHz PS-side reset. This matches the
# official PYNQ-Z2 base overlay and removes the cross-domain reset entirely
# for this net, rather than merely avoiding one specific Vivado timing check.
force_connect_bd_net [get_bd_pins rst_pixelclk/peripheral_aresetn] [get_bd_pins vtc_in/resetn]

set ps7_axi_rst_map [list \
    [list ps7_axi_periph/ARESETN rst_ps7_stable/interconnect_aresetn] \
    [list ps7_axi_periph/S00_ARESETN rst_ps7_stable/peripheral_aresetn] \
    [list ps7_axi_periph/M00_ARESETN rst_ps7_100m/peripheral_aresetn] \
    [list ps7_axi_periph/M01_ARESETN rst_ps7_100m/peripheral_aresetn] \
    [list ps7_axi_periph/M02_ARESETN rst_ps7_100m/peripheral_aresetn] \
    [list ps7_axi_periph/M03_ARESETN rst_ps7_100m/peripheral_aresetn] \
    [list ps7_axi_periph/M04_ARESETN rst_ps7_stable/peripheral_aresetn] \
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
connect_bd_net [get_bd_pins dvi2rgb_0/PixelClk] [get_bd_pins video_fe_probe_0/vid_clk]
connect_bd_net [get_bd_pins rst_pixelclk/peripheral_reset] [get_bd_pins v_vid_in_axi4s_0/vid_io_in_reset]

# AES tag-path debug probes -> sequencer mirror registers (REG_DBG_PUSH_* /
# REG_DBG_MAXIS_* at 0x84-0xA0).
connect_bd_net [get_bd_pins $AES_INST/dbg_push_data] [get_bd_pins $SEQUENCER_INST/dbg_push_data]
connect_bd_net [get_bd_pins $AES_INST/dbg_maxis_last_beat] [get_bd_pins $SEQUENCER_INST/dbg_maxis_last_beat]
connect_bd_net [get_bd_pins $AES_INST/dbg_ct_beats] [get_bd_pins $SEQUENCER_INST/dbg_ct_beats]
connect_bd_net [get_bd_pins $AES_INST/dbg_tag_pushes] [get_bd_pins $SEQUENCER_INST/dbg_tag_pushes]
connect_bd_net [get_bd_pins $AES_INST/dbg_tag_fifo_count] [get_bd_pins $SEQUENCER_INST/dbg_tag_fifo_count]
connect_bd_net [get_bd_pins $AES_INST/dbg_tag_pt_inflight] [get_bd_pins $SEQUENCER_INST/dbg_tag_pt_inflight]
connect_bd_net [get_bd_pins $AES_INST/dbg_last_ct_beats] [get_bd_pins $SEQUENCER_INST/dbg_last_ct_beats]
connect_bd_net [get_bd_pins $AES_INST/dbg_last_fifo_pushes] [get_bd_pins $SEQUENCER_INST/dbg_last_fifo_pushes]
connect_bd_net [get_bd_pins $AES_INST/dbg_last_axis_pops] [get_bd_pins $SEQUENCER_INST/dbg_last_axis_pops]
connect_bd_net [get_bd_pins $AES_INST/dbg_last_tag_attempts] [get_bd_pins $SEQUENCER_INST/dbg_last_tag_attempts]
connect_bd_net [get_bd_pins $AES_INST/dbg_last_fifo_count] [get_bd_pins $SEQUENCER_INST/dbg_last_fifo_count]
connect_bd_net [get_bd_pins $AES_INST/stream_empty] [get_bd_pins $SEQUENCER_INST/aes_stream_empty]

# AES pipeline stall probes -> sequencer mirror registers at 0x100-0x150.
connect_bd_net [get_bd_pins $AES_INST/dbg_aes_stall_status] [get_bd_pins $SEQUENCER_INST/dbg_aes_stall_status]
connect_bd_net [get_bd_pins $AES_INST/dbg_fifo_full_cycles] [get_bd_pins $SEQUENCER_INST/dbg_fifo_full_cycles]
connect_bd_net [get_bd_pins $AES_INST/dbg_empty_no_ct_cycles] [get_bd_pins $SEQUENCER_INST/dbg_empty_no_ct_cycles]
connect_bd_net [get_bd_pins $AES_INST/dbg_pt_blocked_cycles] [get_bd_pins $SEQUENCER_INST/dbg_pt_blocked_cycles]
connect_bd_net [get_bd_pins $AES_INST/dbg_no_offer_cycles] [get_bd_pins $SEQUENCER_INST/dbg_no_offer_cycles]
connect_bd_net [get_bd_pins $AES_INST/dbg_gh_not_ready_cycles] [get_bd_pins $SEQUENCER_INST/dbg_gh_not_ready_cycles]
connect_bd_net [get_bd_pins $AES_INST/dbg_slot_blocked_cycles] [get_bd_pins $SEQUENCER_INST/dbg_slot_blocked_cycles]
connect_bd_net [get_bd_pins $AES_INST/dbg_gcm_busy_cycles] [get_bd_pins $SEQUENCER_INST/dbg_gcm_busy_cycles]
connect_bd_net [get_bd_pins $AES_INST/dbg_last_fifo_full] [get_bd_pins $SEQUENCER_INST/dbg_last_fifo_full]
connect_bd_net [get_bd_pins $AES_INST/dbg_last_empty_no_ct] [get_bd_pins $SEQUENCER_INST/dbg_last_empty_no_ct]
connect_bd_net [get_bd_pins $AES_INST/dbg_last_pt_blocked] [get_bd_pins $SEQUENCER_INST/dbg_last_pt_blocked]
connect_bd_net [get_bd_pins $AES_INST/dbg_last_no_offer] [get_bd_pins $SEQUENCER_INST/dbg_last_no_offer]
connect_bd_net [get_bd_pins $AES_INST/dbg_last_gh_not_ready] [get_bd_pins $SEQUENCER_INST/dbg_last_gh_not_ready]
connect_bd_net [get_bd_pins $AES_INST/dbg_last_slot_blocked] [get_bd_pins $SEQUENCER_INST/dbg_last_slot_blocked]

# Packetizer live probes -> sequencer mirror register REG_PKT_STATUS (0x154).
connect_bd_net [get_bd_pins $PACKETIZER_INST/dbg_pkt_status] [get_bd_pins $SEQUENCER_INST/dbg_pkt_status]
# Packet FIFO probes: occupancy counts only. Do NOT tap the FIFO's
# s_axis_tready or m_axis_tvalid here: a BD pin can only sit on one net, so
# such a tap DISCONNECTS the handshake signal from its interface net and
# grounds it in the generated top (sequencer s_axis_tvalid=1'b0,
# packetizer m_axis_tready=1'b1) - the exact 0-packet stall seen on board.
# The sequencer observes its own s_axis pins internally for REG_PKT_FIFO_STATUS.
connect_bd_net [get_bd_pins packet_seq_fifo_0/axis_wr_data_count] [get_bd_pins $SEQUENCER_INST/dbg_pkt_fifo_wr_count]
connect_bd_net [get_bd_pins packet_seq_fifo_0/axis_rd_data_count] [get_bd_pins $SEQUENCER_INST/dbg_pkt_fifo_rd_count]

assign_bd_address
regenerate_bd_layout
save_bd_design

# Patch the serialized BD: give the BUFGMUX module's clk_out pin an explicit
# frequency so the BD can derive the design-domain clock. It cannot infer
# the frequency through the module boundary, which otherwise leaves the
# auto-generated clock converters at the 10 MHz default and fails both the
# validation and the HDL generation.
set _bd_path [file normalize [file join \
    [get_property DIRECTORY [current_project]] \
    "${current_project_name}.srcs" "sources_1" "bd" $BD_NAME "${BD_NAME}.bd"]]
set _fh [open $_bd_path r]
set _bd_txt [read $_fh]
close $_fh
set _old "\"clk_out\": {\n            \"direction\": \"O\"\n          }"
set _new "\"clk_out\": {\n            \"direction\": \"O\",\n            \"parameters\": {\n              \"FREQ_HZ\": {\n                \"value\": \"100000000\",\n                \"value_src\": \"user_prop\"\n              }\n            }\n          }"
if {[string first $_old $_bd_txt] < 0} {
    error "clk_out pin block not found for the FREQ_HZ patch"
}
set _bd_txt [string map [list $_old $_new] $_bd_txt]
set _fh [open $_bd_path w]
puts -nonewline $_fh $_bd_txt
close $_fh
puts "BD patched: aes_clk_mux/clk_out FREQ_HZ = 100 MHz (worst case)"

# Reopen from the patched file so the BD re-derives the design clock
# frequency from the pin metadata.
close_bd_design [get_bd_designs $BD_NAME]
open_bd_design [get_files "*/${BD_NAME}.bd"]

validate_bd_design
save_bd_design

set bd_files [get_files -quiet "*/${BD_NAME}.bd"]
if {[llength $bd_files] > 0} {
    set_property synth_checkpoint_mode None $bd_files
}

# Force-generate the module-reference synthesis wrappers. Vivado can leave a
# carried-over module_ref OOC as a half-generated stub (xml only, no synth
# .v), which later fails synthesis with [Synth 8-439] "module not found".
puts "=== generating BD synthesis targets (module refs) ==="
generate_target {synthesis} [get_files "*/${BD_NAME}.bd"]
# generate_target may refresh module-reference sources. Re-apply the generated
# 720p30 memory image after that operation, before synthesis starts.
file mkdir [file dirname $native_edid_dst]
file copy -force $native_edid_src $native_edid_dst

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
puts "    - B.1 nonce-prefix injector"
puts "    - B.2 padded DDR packet ring writer"
puts "    - native 720p30 HDMI input path"
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