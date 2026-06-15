# PYNQ-Z2 constraints for hdmi_aes_tx_wrapper external HDMI RX ports.
# Pin mapping derived from the official PYNQ base constraints.

# HDMI RX TMDS reference clock (120 MHz for 1080p60 class signaling).
create_clock -period 8.334 -waveform {0.000 4.167} [get_ports TMDS_0_clk_p]

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
set_clock_groups -asynchronous \
    -group [get_clocks {clk_fpga_0 clk_fpga_1 clk_fpga_2}] \
    -group [get_clocks {dvi2rgb_0_PixelClk CLK_OUT_5x_hdmi_clk TMDS_0_clk_p CLKFBIN}]
