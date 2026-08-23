`timescale 1ns / 1ps
// Capture probe for v_vid_in_axi4s health: counts overflow/underflow pulses
// from its internal coupler and counts reset pulses on vid_io_in_reset (the
// rst_pixelclk peripheral_reset), all synchronized into the aclk domain.
module VideoStatusProbe (
    input  logic         aclk,
    input  logic         aresetn,

    input  logic         vid_overflow,     // v_vid_in coupler overflow (aclk)
    input  logic         vid_underflow,    // v_vid_in coupler underflow (aclk)
    input  logic         vid_reset_async,  // rst_pixelclk peripheral_reset (pixel domain)

    output logic [63:0]  overflow_count,
    output logic [63:0]  underflow_count,
    output logic [63:0]  reset_pulse_count,
    output logic         reset_level
);
    logic of_d, uf_d;
    logic rst_s1, rst_s2, rst_s2_d;
    logic [63:0] ofc, ufc, rpc;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            of_d     <= 1'b0;
            uf_d     <= 1'b0;
            rst_s1   <= 1'b0;
            rst_s2   <= 1'b0;
            rst_s2_d <= 1'b0;
            ofc      <= '0;
            ufc      <= '0;
            rpc      <= '0;
        end else begin
            of_d     <= vid_overflow;
            uf_d     <= vid_underflow;
            rst_s1   <= vid_reset_async;
            rst_s2   <= rst_s1;
            rst_s2_d <= rst_s2;
            if (vid_overflow  && !of_d)      ofc <= ofc + 1'b1;
            if (vid_underflow && !uf_d)      ufc <= ufc + 1'b1;
            if (rst_s2 && !rst_s2_d)         rpc <= rpc + 1'b1;
        end
    end

    assign reset_level     = rst_s2;
    assign overflow_count  = ofc;
    assign underflow_count = ufc;
    assign reset_pulse_count = rpc;
endmodule
