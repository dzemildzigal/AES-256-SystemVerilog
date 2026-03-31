`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Pipelined AES-256 Encrypt: 14 registered round stages + 1 output register.
// Throughput: 1 block/cycle (after 15-cycle fill latency).
// Requirement: expanded_key must be held stable while data is in the pipeline.

module EncryptPipelined(
    input  logic         clk,
    input  logic         rst,
    input  logic         start_i,
    input  logic [0:127] in,
    input  logic [0:1919] expanded_key,
    output logic [0:127] out,
    output logic         valid_data
    );

// Internal pipeline wires between stages
wire [0:127] ff_1_2;
wire [0:127] ff_2_3;
wire [0:127] ff_3_4;
wire [0:127] ff_4_5;
wire [0:127] ff_5_6;
wire [0:127] ff_6_7;
wire [0:127] ff_7_8;
wire [0:127] ff_8_9;
wire [0:127] ff_9_10;
wire [0:127] ff_10_11;
wire [0:127] ff_11_12;
wire [0:127] ff_12_13;
wire [0:127] ff_13_14;
wire [0:127] final_out;

// 14-bit shift register tracking valid data through the 14 round stages
logic [13:0] valid_pipe;

// Pipeline stages (14 registered stages total)
EncryptionInitialRound round1(.clk(clk), .rst(rst),
                              .in(in), .expanded_key(expanded_key),
                              .out(ff_1_2));

EncryptionRound #(.i(2))  round2  (.clk(clk), .rst(rst), .in(ff_1_2),   .expanded_key(expanded_key), .out(ff_2_3));
EncryptionRound #(.i(3))  round3  (.clk(clk), .rst(rst), .in(ff_2_3),   .expanded_key(expanded_key), .out(ff_3_4));
EncryptionRound #(.i(4))  round4  (.clk(clk), .rst(rst), .in(ff_3_4),   .expanded_key(expanded_key), .out(ff_4_5));
EncryptionRound #(.i(5))  round5  (.clk(clk), .rst(rst), .in(ff_4_5),   .expanded_key(expanded_key), .out(ff_5_6));
EncryptionRound #(.i(6))  round6  (.clk(clk), .rst(rst), .in(ff_5_6),   .expanded_key(expanded_key), .out(ff_6_7));
EncryptionRound #(.i(7))  round7  (.clk(clk), .rst(rst), .in(ff_6_7),   .expanded_key(expanded_key), .out(ff_7_8));
EncryptionRound #(.i(8))  round8  (.clk(clk), .rst(rst), .in(ff_7_8),   .expanded_key(expanded_key), .out(ff_8_9));
EncryptionRound #(.i(9))  round9  (.clk(clk), .rst(rst), .in(ff_8_9),   .expanded_key(expanded_key), .out(ff_9_10));
EncryptionRound #(.i(10)) round10 (.clk(clk), .rst(rst), .in(ff_9_10),  .expanded_key(expanded_key), .out(ff_10_11));
EncryptionRound #(.i(11)) round11 (.clk(clk), .rst(rst), .in(ff_10_11), .expanded_key(expanded_key), .out(ff_11_12));
EncryptionRound #(.i(12)) round12 (.clk(clk), .rst(rst), .in(ff_11_12), .expanded_key(expanded_key), .out(ff_12_13));
EncryptionRound #(.i(13)) round13 (.clk(clk), .rst(rst), .in(ff_12_13), .expanded_key(expanded_key), .out(ff_13_14));

EncryptionFinalRound round14(.clk(clk), .rst(rst),
                             .in(ff_13_14), .expanded_key(expanded_key),
                             .out(final_out));

// Output register stage (15th register): captures final_out and valid_pipe[13]
always_ff @(posedge clk) begin
    if (rst) begin
        valid_pipe <= 14'b0;
        valid_data <= 1'b0;
        out        <= '0;
    end
    else begin
        valid_pipe <= {valid_pipe[12:0], start_i};
        valid_data <= valid_pipe[13];
        out        <= final_out;
    end
end
endmodule
