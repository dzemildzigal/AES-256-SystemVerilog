`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// AXI4-Lite slave wrapper for AES-256 CTR mode on PYNQ-Z2.
//
// Register map (32-bit words):
//   Addr   Name     R/W   Description
//   0x00   CTRL     W     [0] go — process one block (1-cycle pulse)
//                         [1] load_key — trigger key expansion (1-cycle pulse)
//                         [2] load_ctr — load counter from CTR register (1-cycle pulse)
//                         [3] zeroize  — clear key_reg and force reset on KeyExpansion
//   0x04   STATUS   R     [3:0] keys_ready (15 = all round keys computed)
//                         [4]   out_valid (sticky, cleared by next go)
//   0x08   KEY0     R/W   masterkey[0:31]     (MSB of key)
//   0x0C   KEY1     R/W   masterkey[32:63]
//   0x10   KEY2     R/W   masterkey[64:95]
//   0x14   KEY3     R/W   masterkey[96:127]
//   0x18   KEY4     R/W   masterkey[128:159]
//   0x1C   KEY5     R/W   masterkey[160:191]
//   0x20   KEY6     R/W   masterkey[192:223]
//   0x24   KEY7     R/W   masterkey[224:255]  (LSB of key)
//   0x28   NONCE0   R/W   nonce[0:31]         (MSB of nonce)
//   0x2C   NONCE1   R/W   nonce[32:63]
//   0x30   NONCE2   R/W   nonce[64:95]        (LSB of nonce)
//   0x34   CTR      R/W   counter[0:31]       (auto-increments after each block)
//   0x38   DIN0     R/W   data_in[0:31]       (plaintext or ciphertext)
//   0x3C   DIN1     R/W   data_in[32:63]
//   0x40   DIN2     R/W   data_in[64:95]
//   0x44   DIN3     R/W   data_in[96:127]
//   0x48   DOUT0    R     data_out[0:31]      (ciphertext or plaintext)
//   0x4C   DOUT1    R     data_out[32:63]
//   0x50   DOUT2    R     data_out[64:95]
//   0x54   DOUT3    R     data_out[96:127]

module AXI_AES_CTR #(
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
    wire rst_axi = ~S_AXI_ARESETN;

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
    reg [0:95]  nonce_reg;
    reg [0:31]  ctr_reg;
    reg [0:127] din_reg;
    reg         go_pulse;
    reg         load_key_pulse;
    reg         load_ctr_pulse;
    reg         zeroize_pulse;

    // Combine resets: AXI reset OR zeroize command
    wire rst = rst_axi | zeroize_pulse;

    // CtrMode interface wires
    wire [3:0]   keys_ready;
    wire [0:127] data_out;
    wire         out_valid;
    wire [0:31]  counter_val;

    CtrMode cm(
        .clk(clk),
        .rst(rst),
        .new_masterkey(load_key_pulse),
        .masterkey(key_reg),
        .keys_ready(keys_ready),
        .start_i(go_pulse),
        .nonce(nonce_reg),
        .data_in(din_reg),
        .data_out(data_out),
        .out_valid(out_valid),
        .counter_init(ctr_reg),
        .counter_load(load_ctr_pulse),
        .counter_val(counter_val)
    );

    // ----------------------------------------------------------------
    // Sticky status latch
    // out_valid is a single-cycle pulse; latch it for AXI polling.
    // Cleared by the next go_pulse.
    // ----------------------------------------------------------------
    reg out_valid_sticky;

    always_ff @(posedge clk) begin
        if (rst)
            out_valid_sticky <= 1'b0;
        else if (go_pulse)
            out_valid_sticky <= 1'b0;
        else if (out_valid)
            out_valid_sticky <= 1'b1;
    end

    // ----------------------------------------------------------------
    // AXI Write Address + Write Data (accept together)
    // ----------------------------------------------------------------
    wire wr_handshake = axi_awready && S_AXI_AWVALID
                     && axi_wready  && S_AXI_WVALID;

    always_ff @(posedge clk) begin
        if (rst_axi) begin
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
        if (rst_axi) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b00;
        end
        else if (wr_handshake && ~axi_bvalid) begin
            axi_bvalid <= 1'b1;
            axi_bresp  <= 2'b00;
        end
        else if (S_AXI_BREADY && axi_bvalid)
            axi_bvalid <= 1'b0;
    end

    // ----------------------------------------------------------------
    // Register Writes
    // ----------------------------------------------------------------
    wire [4:0] wr_index = axi_awaddr[6:2];

    always_ff @(posedge clk) begin
        if (rst_axi) begin
            key_reg        <= '0;
            nonce_reg      <= '0;
            ctr_reg        <= '0;
            din_reg        <= '0;
            go_pulse       <= 1'b0;
            load_key_pulse <= 1'b0;
            load_ctr_pulse <= 1'b0;
            zeroize_pulse  <= 1'b0;
        end
        else begin
            // Auto-clear pulses every cycle
            go_pulse       <= 1'b0;
            load_key_pulse <= 1'b0;
            load_ctr_pulse <= 1'b0;
            zeroize_pulse  <= 1'b0;

            if (wr_handshake) begin
                case (wr_index)
                    5'd0: begin                             // CTRL
                        go_pulse       <= S_AXI_WDATA[0];
                        load_key_pulse <= S_AXI_WDATA[1];
                        load_ctr_pulse <= S_AXI_WDATA[2];
                        zeroize_pulse  <= S_AXI_WDATA[3];
                    end
                    5'd2:  key_reg[0   +:32] <= S_AXI_WDATA;   // KEY0
                    5'd3:  key_reg[32  +:32] <= S_AXI_WDATA;   // KEY1
                    5'd4:  key_reg[64  +:32] <= S_AXI_WDATA;   // KEY2
                    5'd5:  key_reg[96  +:32] <= S_AXI_WDATA;   // KEY3
                    5'd6:  key_reg[128 +:32] <= S_AXI_WDATA;   // KEY4
                    5'd7:  key_reg[160 +:32] <= S_AXI_WDATA;   // KEY5
                    5'd8:  key_reg[192 +:32] <= S_AXI_WDATA;   // KEY6
                    5'd9:  key_reg[224 +:32] <= S_AXI_WDATA;   // KEY7
                    5'd10: nonce_reg[0  +:32] <= S_AXI_WDATA;  // NONCE0
                    5'd11: nonce_reg[32 +:32] <= S_AXI_WDATA;  // NONCE1
                    5'd12: nonce_reg[64 +:32] <= S_AXI_WDATA;  // NONCE2
                    5'd13: ctr_reg            <= S_AXI_WDATA;   // CTR
                    5'd14: din_reg[0   +:32]  <= S_AXI_WDATA;  // DIN0
                    5'd15: din_reg[32  +:32]  <= S_AXI_WDATA;  // DIN1
                    5'd16: din_reg[64  +:32]  <= S_AXI_WDATA;  // DIN2
                    5'd17: din_reg[96  +:32]  <= S_AXI_WDATA;  // DIN3
                    default: ;
                endcase
            end
        end
    end

    // ----------------------------------------------------------------
    // AXI Read Address
    // ----------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst_axi) begin
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
    reg [C_S_AXI_DATA_WIDTH-1:0] rd_mux;
    wire [4:0] rd_index = axi_araddr[6:2];

    always_comb begin
        case (rd_index)
            5'd1:  rd_mux = {27'b0, out_valid_sticky, keys_ready};
            5'd2:  rd_mux = key_reg[0   +:32];
            5'd3:  rd_mux = key_reg[32  +:32];
            5'd4:  rd_mux = key_reg[64  +:32];
            5'd5:  rd_mux = key_reg[96  +:32];
            5'd6:  rd_mux = key_reg[128 +:32];
            5'd7:  rd_mux = key_reg[160 +:32];
            5'd8:  rd_mux = key_reg[192 +:32];
            5'd9:  rd_mux = key_reg[224 +:32];
            5'd10: rd_mux = nonce_reg[0  +:32];
            5'd11: rd_mux = nonce_reg[32 +:32];
            5'd12: rd_mux = nonce_reg[64 +:32];
            5'd13: rd_mux = counter_val;
            5'd14: rd_mux = din_reg[0   +:32];
            5'd15: rd_mux = din_reg[32  +:32];
            5'd16: rd_mux = din_reg[64  +:32];
            5'd17: rd_mux = din_reg[96  +:32];
            5'd18: rd_mux = data_out[0   +:32];
            5'd19: rd_mux = data_out[32  +:32];
            5'd20: rd_mux = data_out[64  +:32];
            5'd21: rd_mux = data_out[96  +:32];
            default: rd_mux = 32'd0;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst_axi) begin
            axi_rvalid <= 1'b0;
            axi_rresp  <= 2'b00;
            axi_rdata  <= '0;
        end
        else if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
            axi_rvalid <= 1'b1;
            axi_rresp  <= 2'b00;
            axi_rdata  <= rd_mux;
        end
        else if (axi_rvalid && S_AXI_RREADY)
            axi_rvalid <= 1'b0;
    end

endmodule
