`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// AXI4-Lite slave wrapper for AES-256 Encrypt-Decrypt roundtrip on PYNQ-Z2.
//
// Register map (32-bit words, active on AXI write/read):
//   Addr   Name     R/W   Description
//   0x00   CTRL     W     [0] go — start roundtrip (1-cycle pulse)
//                         [1] load_key — trigger key expansion (1-cycle pulse)
//   0x04   STATUS   R     [3:0] keys_ready counter (15 = all keys done)
//                         [4]   ct_valid (latched, cleared by go)
//                         [5]   result_valid (latched, cleared by go)
//                         [6]   match (latched, cleared by go)
//   0x08   KEY0     R/W   masterkey[0:31]     (MSB of key)
//   0x0C   KEY1     R/W   masterkey[32:63]
//   0x10   KEY2     R/W   masterkey[64:95]
//   0x14   KEY3     R/W   masterkey[96:127]
//   0x18   KEY4     R/W   masterkey[128:159]
//   0x1C   KEY5     R/W   masterkey[160:191]
//   0x20   KEY6     R/W   masterkey[192:223]
//   0x24   KEY7     R/W   masterkey[224:255]  (LSB of key)
//   0x28   PT0      R/W   plaintext[0:31]
//   0x2C   PT1      R/W   plaintext[32:63]
//   0x30   PT2      R/W   plaintext[64:95]
//   0x34   PT3      R/W   plaintext[96:127]
//   0x38   CT0      R     ciphertext[0:31]    (intermediate, latched)
//   0x3C   CT1      R     ciphertext[32:63]
//   0x40   CT2      R     ciphertext[64:95]
//   0x44   CT3      R     ciphertext[96:127]
//   0x48   RES0     R     result[0:31]        (decrypted, should match PT)
//   0x4C   RES1     R     result[32:63]
//   0x50   RES2     R     result[64:95]
//   0x54   RES3     R     result[96:127]
//
// PYNQ Python usage example:
//   from pynq import Overlay, MMIO
//   ol = Overlay('aes_roundtrip.bit')
//   aes = MMIO(ol.ip_dict['aes_roundtrip_0']['phys_addr'], 0x80)
//   # Write key (NIST 256-bit)
//   for i, w in enumerate([0x00010203,0x04050607,0x08090a0b,0x0c0d0e0f,
//                           0x10111213,0x14151617,0x18191a1b,0x1c1d1e1f]):
//       aes.write(0x08 + i*4, w)
//   aes.write(0x00, 0x2)                         # load_key
//   while (aes.read(0x04) & 0xF) != 15: pass     # wait for key expansion
//   # Write plaintext
//   for i, w in enumerate([0x00112233,0x44556677,0x8899aabb,0xccddeeff]):
//       aes.write(0x28 + i*4, w)
//   aes.write(0x00, 0x1)                         # go
//   while not (aes.read(0x04) & 0x20): pass       # wait for result_valid
//   match = (aes.read(0x04) >> 6) & 1
//   print(f"Roundtrip match: {match}")

module AXI_AES_Roundtrip #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 7
)(
    input  wire                                S_AXI_ACLK,
    input  wire                                S_AXI_ARESETN,
    // Write address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_AWADDR,
    input  wire [2:0]                          S_AXI_AWPROT,
    input  wire                                S_AXI_AWVALID,
    output wire                                S_AXI_AWREADY,
    // Write data channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]   S_AXI_WSTRB,
    input  wire                                S_AXI_WVALID,
    output wire                                S_AXI_WREADY,
    // Write response channel
    output wire [1:0]                          S_AXI_BRESP,
    output wire                                S_AXI_BVALID,
    input  wire                                S_AXI_BREADY,
    // Read address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_ARADDR,
    input  wire [2:0]                          S_AXI_ARPROT,
    input  wire                                S_AXI_ARVALID,
    output wire                                S_AXI_ARREADY,
    // Read data channel
    output wire [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_RDATA,
    output wire [1:0]                          S_AXI_RRESP,
    output wire                                S_AXI_RVALID,
    input  wire                                S_AXI_RREADY
);

    // ----------------------------------------------------------------
    // Internal signals
    // ----------------------------------------------------------------
    wire clk = S_AXI_ACLK;
    wire rst = ~S_AXI_ARESETN;

    // AXI handshake registers
    reg                            axi_awready;
    reg                            axi_wready;
    reg [1:0]                      axi_bresp;
    reg                            axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0]   axi_awaddr;
    reg                            axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1:0]   axi_rdata;
    reg [1:0]                      axi_rresp;
    reg                            axi_rvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0]   axi_araddr;

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    // ----------------------------------------------------------------
    // User register file
    // ----------------------------------------------------------------
    reg [0:255] key_reg;
    reg [0:127] pt_reg;
    reg         go_pulse;
    reg         load_key_pulse;

    // TopRoundtrip interface wires
    wire [3:0]   keys_ready;
    wire [0:127] ct_out;
    wire         ct_valid;
    wire [0:127] result;
    wire         result_valid;
    wire         match;

    TopRoundtrip tr(
        .clk(clk),
        .rst(rst),
        .new_masterkey(load_key_pulse),
        .masterkey(key_reg),
        .keys_ready(keys_ready),
        .start_i(go_pulse),
        .plaintext(pt_reg),
        .ct_out(ct_out),
        .ct_valid(ct_valid),
        .result(result),
        .result_valid(result_valid),
        .match(match)
    );

    // ----------------------------------------------------------------
    // Sticky status latches
    // ct_valid/result_valid/match are single-cycle pulses from the
    // pipeline.  Latch them so slow AXI polling can observe them.
    // Cleared by the next go_pulse.
    // ----------------------------------------------------------------
    reg ct_valid_sticky;
    reg result_valid_sticky;
    reg match_sticky;

    always_ff @(posedge clk) begin
        if (rst) begin
            ct_valid_sticky     <= 1'b0;
            result_valid_sticky <= 1'b0;
            match_sticky        <= 1'b0;
        end
        else if (go_pulse) begin
            ct_valid_sticky     <= 1'b0;
            result_valid_sticky <= 1'b0;
            match_sticky        <= 1'b0;
        end
        else begin
            if (ct_valid)     ct_valid_sticky     <= 1'b1;
            if (result_valid) result_valid_sticky  <= 1'b1;
            if (result_valid) match_sticky         <= match;
        end
    end

    // ----------------------------------------------------------------
    // AXI Write Address + Write Data (accept together)
    // ----------------------------------------------------------------
    wire wr_handshake = axi_awready && S_AXI_AWVALID
                     && axi_wready  && S_AXI_WVALID;

    always_ff @(posedge clk) begin
        if (rst) begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_awaddr  <= '0;
        end
        else if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && (~axi_bvalid || S_AXI_BREADY)) begin
            axi_awready <= 1'b1;
            axi_wready  <= 1'b1;
            axi_awaddr  <= S_AXI_AWADDR;
        end
        else begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
        end
    end

    // ----------------------------------------------------------------
    // Write Response
    // ----------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b00;
        end
        else if (wr_handshake && ~axi_bvalid) begin
            axi_bvalid <= 1'b1;
            axi_bresp  <= 2'b00;   // OKAY
        end
        else if (S_AXI_BREADY && axi_bvalid)
            axi_bvalid <= 1'b0;
    end

    // ----------------------------------------------------------------
    // Register Writes
    // ----------------------------------------------------------------
    wire [4:0] wr_index = axi_awaddr[6:2];

    always_ff @(posedge clk) begin
        if (rst) begin
            key_reg        <= '0;
            pt_reg         <= '0;
            go_pulse       <= 1'b0;
            load_key_pulse <= 1'b0;
        end
        else begin
            // Auto-clear pulses every cycle
            go_pulse       <= 1'b0;
            load_key_pulse <= 1'b0;

            if (wr_handshake) begin
                case (wr_index)
                    5'd0: begin                         // CTRL
                        go_pulse       <= S_AXI_WDATA[0];
                        load_key_pulse <= S_AXI_WDATA[1];
                    end
                    5'd2:  key_reg[0   +:32] <= S_AXI_WDATA;   // KEY0
                    5'd3:  key_reg[32  +:32] <= S_AXI_WDATA;   // KEY1
                    5'd4:  key_reg[64  +:32] <= S_AXI_WDATA;   // KEY2
                    5'd5:  key_reg[96  +:32] <= S_AXI_WDATA;   // KEY3
                    5'd6:  key_reg[128 +:32] <= S_AXI_WDATA;   // KEY4
                    5'd7:  key_reg[160 +:32] <= S_AXI_WDATA;   // KEY5
                    5'd8:  key_reg[192 +:32] <= S_AXI_WDATA;   // KEY6
                    5'd9:  key_reg[224 +:32] <= S_AXI_WDATA;   // KEY7
                    5'd10: pt_reg[0   +:32]  <= S_AXI_WDATA;   // PT0
                    5'd11: pt_reg[32  +:32]  <= S_AXI_WDATA;   // PT1
                    5'd12: pt_reg[64  +:32]  <= S_AXI_WDATA;   // PT2
                    5'd13: pt_reg[96  +:32]  <= S_AXI_WDATA;   // PT3
                    default: ;
                endcase
            end
        end
    end

    // ----------------------------------------------------------------
    // AXI Read Address
    // ----------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            axi_arready <= 1'b0;
            axi_araddr  <= '0;
        end
        else if (~axi_arready && S_AXI_ARVALID) begin
            axi_arready <= 1'b1;
            axi_araddr  <= S_AXI_ARADDR;
        end
        else
            axi_arready <= 1'b0;
    end

    // ----------------------------------------------------------------
    // Read Data + Response
    // ----------------------------------------------------------------
    // Combinational read mux
    reg [C_S_AXI_DATA_WIDTH-1:0] rd_mux;
    wire [4:0] rd_index = axi_araddr[6:2];

    always_comb begin
        case (rd_index)
            5'd1:  rd_mux = {25'b0, match_sticky, result_valid_sticky, ct_valid_sticky, keys_ready};
            5'd2:  rd_mux = key_reg[0   +:32];
            5'd3:  rd_mux = key_reg[32  +:32];
            5'd4:  rd_mux = key_reg[64  +:32];
            5'd5:  rd_mux = key_reg[96  +:32];
            5'd6:  rd_mux = key_reg[128 +:32];
            5'd7:  rd_mux = key_reg[160 +:32];
            5'd8:  rd_mux = key_reg[192 +:32];
            5'd9:  rd_mux = key_reg[224 +:32];
            5'd10: rd_mux = pt_reg[0   +:32];
            5'd11: rd_mux = pt_reg[32  +:32];
            5'd12: rd_mux = pt_reg[64  +:32];
            5'd13: rd_mux = pt_reg[96  +:32];
            5'd14: rd_mux = ct_out[0   +:32];
            5'd15: rd_mux = ct_out[32  +:32];
            5'd16: rd_mux = ct_out[64  +:32];
            5'd17: rd_mux = ct_out[96  +:32];
            5'd18: rd_mux = result[0   +:32];
            5'd19: rd_mux = result[32  +:32];
            5'd20: rd_mux = result[64  +:32];
            5'd21: rd_mux = result[96  +:32];
            default: rd_mux = 32'd0;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            axi_rvalid <= 1'b0;
            axi_rresp  <= 2'b00;
            axi_rdata  <= '0;
        end
        else if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
            axi_rvalid <= 1'b1;
            axi_rresp  <= 2'b00;   // OKAY
            axi_rdata  <= rd_mux;
        end
        else if (axi_rvalid && S_AXI_RREADY)
            axi_rvalid <= 1'b0;
    end

endmodule
