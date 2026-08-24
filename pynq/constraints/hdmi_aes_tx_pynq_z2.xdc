# PYNQ-Z2 constraints for hdmi_aes_tx_wrapper external HDMI RX ports.
# Pin mapping derived from the official PYNQ base constraints.

# HDMI RX TMDS reference clock for the generated native 720p30 EDID:
# 37.13 MHz pixel/TMDS clock, period 26.9324 ns.
create_clock -period 26.932 -waveform {0.000 13.466} [get_ports TMDS_0_clk_p]

set_property -dict {PACKAGE_PIN P19 IOSTANDARD TMDS_33} [get_ports TMDS_0_clk_n]
set_property -dict {PACKAGE_PIN N18 IOSTANDARD TMDS_33} [get_ports TMDS_0_clk_p]
set_property -dict {PACKAGE_PIN W20 IOSTANDARD TMDS_33} [get_ports {TMDS_0_data_n[0]}]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD TMDS_33} [get_ports {TMDS_0_data_p[0]}]
set_property -dict {PACKAGE_PIN U20 IOSTANDARD TMDS_33} [get_ports {TMDS_0_data_n[1]}]
set_property -dict {PACKAGE_PIN T20 IOSTANDARD TMDS_33} [get_ports {TMDS_0_data_p[1]}]
set_property -dict {PACKAGE_PIN P20 IOSTANDARD TMDS_33} [get_ports {TMDS_0_data_n[2]}]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD TMDS_33} [get_ports {TMDS_0_data_p[2]}]

set_property -dict {PACKAGE_PIN T19 IOSTANDARD LVCMOS33} [get_ports {hdmi_in_hpd[0]}]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports DDC_0_scl_io]
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports DDC_0_sda_io]

# HDMI recovered pixel clocks are asynchronous to PS FCLK domains.
# Without this, Vivado times CDC/reset-like paths inside vtc_in AXI4-Lite logic
# against unrelated clocks (clk_fpga_2 -> dvi2rgb_0_PixelClk), producing false
# setup violations around read_ack/write_ack reset pins.
# -include_generated_clocks also covers the MMCM outputs behind aes_clk_mux
# (the switchable 50/75/100 MHz design clock).
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks {clk_fpga_0 clk_fpga_1 clk_fpga_2}] \
    -group [get_clocks {dvi2rgb_0_PixelClk CLK_OUT_5x_hdmi_clk TMDS_0_clk_p CLKFBIN}]

# The three MMCM outputs feed the BUFGMUX: only ONE drives the design domain
# at a time (PS-selected), so cross-pair paths between them are physically
# impossible and must not be timed (they were the -6.5ns WNS artifacts).
set_clock_groups -physically_exclusive \
    -group [get_clocks {clk_out1_*}] \
    -group [get_clocks {clk_out2_*}] \
    -group [get_clocks {clk_out3_*}]

# The 3-way clock mux = two cascaded BUFGMUX_CTRLs fed by the wizard's BUFGs.
# The placer's rule_cascaded_bufg wants the BUFG->BUFG pairs adjacent; with
# the domain held in reset during every switch (PS-controlled proc_sys_reset
# aux) the dedicated-route strictness is not needed.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets hdmi_aes_tx_i/clk_wiz_aes/inst/clk_out1]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets hdmi_aes_tx_i/clk_wiz_aes/inst/clk_out2]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets hdmi_aes_tx_i/clk_wiz_aes/inst/clk_out3]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets hdmi_aes_tx_i/clk_wiz_aes_clk_out1]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets hdmi_aes_tx_i/clk_wiz_aes_clk_out2]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets hdmi_aes_tx_i/clk_wiz_aes_clk_out3]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets hdmi_aes_tx_i/aes_clk_mux/inst/mux0_out]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets hdmi_aes_tx_i/aes_clk_mux/clk_out]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets hdmi_aes_tx_i/aes_clk_mux/inst/clk_out]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets hdmi_aes_tx_i/aes_clk_mux_clk_out]
