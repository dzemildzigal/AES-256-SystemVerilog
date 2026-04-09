`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// GHASH engine for AES-GCM.
//
// Computes:
//   Y_0 = 0
//   Y_i = (Y_{i-1} xor X_i) * H
// over X = AAD blocks || CT blocks || {len(AAD)_bits, len(CT)_bits}
//
// Then forms tag mask combination:
//   TAG = Y_final xor E_K(J0)  (tag_mask_i)
//
// Notes:
// - Inputs are assumed 128-bit block aligned (caller zero-pads final block).
// - aad_len_bits_i / ct_len_bits_i carry the true bit lengths.
// - Supports streaming with separate AAD and CT channels.
//////////////////////////////////////////////////////////////////////////////////

module GHashEngine #(
    parameter integer FIFO_DEPTH = 16  // Must be a power of 2.
)(
    input  logic         clk,
    input  logic         rst,

    // Session control
    input  logic         start_i,
    input  logic [0:127] h_i,
    input  logic [0:127] tag_mask_i,     // E_K(J0)
    input  logic [0:63]  aad_len_bits_i,
    input  logic [0:63]  ct_len_bits_i,

    // AAD stream (must come before CT stream)
    input  logic [0:127] aad_data_i,
    input  logic         aad_valid_i,
    input  logic         aad_last_i,
    output logic         aad_ready_o,

    // Ciphertext stream
    input  logic [0:127] ct_data_i,
    input  logic         ct_valid_i,
    input  logic         ct_last_i,
    output logic         ct_ready_o,

    // Status / result
    output logic         ready_o,
    output logic         busy_o,
    output logic [0:127] ghash_out_o,
    output logic         ghash_valid_o,
    output logic [0:127] tag_out_o,
    output logic         tag_valid_o
    );

    localparam integer PTR_W = $clog2(FIFO_DEPTH);

    typedef enum logic [1:0] {
        PH_IDLE = 2'b00,
        PH_AAD  = 2'b01,
        PH_CT   = 2'b10,
        PH_DONE = 2'b11
    } phase_t;

    typedef enum logic [2:0] {
        PREP_IDLE      = 3'd0,
        PREP_H2_LAUNCH = 3'd1,
        PREP_H2_WAIT   = 3'd2,
        PREP_H3_LAUNCH = 3'd3,
        PREP_H3_WAIT   = 3'd4,
        PREP_H4_LAUNCH = 3'd5,
        PREP_H4_WAIT   = 3'd6,
        PREP_READY     = 3'd7
    } prep_t;

    // ----------------------------------------------------------------
    // Session registers
    // ----------------------------------------------------------------
    phase_t       phase;
    prep_t        prep_state;

    logic [0:127] h1_reg, h2_reg, h3_reg, h4_reg;
    logic [0:127] tag_mask_reg;
    logic [0:63]  aad_len_bits_reg;
    logic [0:63]  ct_len_bits_reg;

    logic [0:127] y_acc;

    logic         recv_done;
    logic         len_block_enqueued;
    logic         done_emitted;

    wire all_input_enqueued = recv_done && len_block_enqueued;

    // ----------------------------------------------------------------
    // FIFO for incoming GHASH blocks
    // ----------------------------------------------------------------
    logic [0:127] fifo_mem [0:FIFO_DEPTH-1];
    logic [PTR_W-1:0] wr_ptr;
    logic [PTR_W-1:0] rd_ptr;
    logic [PTR_W:0]   fifo_count;

    localparam logic [PTR_W-1:0] PTR_INC1 = 1;
    localparam logic [PTR_W-1:0] PTR_INC2 = 2;
    localparam logic [PTR_W-1:0] PTR_INC3 = 3;
    localparam logic [PTR_W-1:0] PTR_INC4 = 4;

    // ----------------------------------------------------------------
    // Precompute H powers with one GF multiplier: H^2, H^3, H^4
    // ----------------------------------------------------------------
    logic         pre_start;
    logic [0:127] pre_a;
    logic [0:127] pre_b;
    wire          pre_valid;
    wire [0:127]  pre_out;

    GFMult128 pre_mul(
        .clk(clk),
        .rst(rst),
        .start_i(pre_start),
        .in_a(pre_a),
        .in_b(pre_b),
        .out_o(pre_out),
        .valid_o(pre_valid)
    );

    // ----------------------------------------------------------------
    // 4-lane GHASH batch multipliers
    // ----------------------------------------------------------------
    logic         lane_start;
    logic [0:127] lane_a0, lane_a1, lane_a2, lane_a3;
    logic [0:127] lane_b0, lane_b1, lane_b2, lane_b3;

    wire          lane_v0, lane_v1, lane_v2, lane_v3;
    wire [0:127]  lane_o0, lane_o1, lane_o2, lane_o3;

    GFMult128 lane0(
        .clk(clk), .rst(rst), .start_i(lane_start),
        .in_a(lane_a0), .in_b(lane_b0), .out_o(lane_o0), .valid_o(lane_v0)
    );

    GFMult128 lane1(
        .clk(clk), .rst(rst), .start_i(lane_start),
        .in_a(lane_a1), .in_b(lane_b1), .out_o(lane_o1), .valid_o(lane_v1)
    );

    GFMult128 lane2(
        .clk(clk), .rst(rst), .start_i(lane_start),
        .in_a(lane_a2), .in_b(lane_b2), .out_o(lane_o2), .valid_o(lane_v2)
    );

    GFMult128 lane3(
        .clk(clk), .rst(rst), .start_i(lane_start),
        .in_a(lane_a3), .in_b(lane_b3), .out_o(lane_o3), .valid_o(lane_v3)
    );

    logic       batch_busy;
    logic [2:0] batch_size_launch;

    wire lane_done = batch_busy && lane_v0;
    wire [0:127] lane_xor = lane_o0 ^ lane_o1 ^ lane_o2 ^ lane_o3;

    // ----------------------------------------------------------------
    // Ready signals
    // ----------------------------------------------------------------
    assign ready_o     = ~busy_o;
    assign aad_ready_o = busy_o && (phase == PH_AAD) && (fifo_count < FIFO_DEPTH);
    assign ct_ready_o  = busy_o && (phase == PH_CT)  && (fifo_count < FIFO_DEPTH);

    // ----------------------------------------------------------------
    // Main control
    // ----------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            busy_o             <= 1'b0;
            phase              <= PH_IDLE;
            prep_state         <= PREP_IDLE;

            h1_reg             <= '0;
            h2_reg             <= '0;
            h3_reg             <= '0;
            h4_reg             <= '0;
            tag_mask_reg       <= '0;
            aad_len_bits_reg   <= '0;
            ct_len_bits_reg    <= '0;

            y_acc              <= '0;

            recv_done          <= 1'b0;
            len_block_enqueued <= 1'b0;
            done_emitted       <= 1'b0;

            wr_ptr             <= '0;
            rd_ptr             <= '0;
            fifo_count         <= '0;

            pre_start          <= 1'b0;
            pre_a              <= '0;
            pre_b              <= '0;

            lane_start         <= 1'b0;
            lane_a0            <= '0;
            lane_a1            <= '0;
            lane_a2            <= '0;
            lane_a3            <= '0;
            lane_b0            <= '0;
            lane_b1            <= '0;
            lane_b2            <= '0;
            lane_b3            <= '0;
            batch_busy         <= 1'b0;
            batch_size_launch  <= 3'd0;

            ghash_out_o        <= '0;
            ghash_valid_o      <= 1'b0;
            tag_out_o          <= '0;
            tag_valid_o        <= 1'b0;
        end
        else begin
            logic         do_enq;
            logic [0:127] enq_data;
            logic         do_batch;
            logic [2:0]   batch_size_sel;
            int           count_next;

            // 1-cycle pulse defaults
            pre_start     <= 1'b0;
            lane_start    <= 1'b0;
            ghash_valid_o <= 1'b0;
            tag_valid_o   <= 1'b0;

            do_enq        = 1'b0;
            enq_data      = '0;
            do_batch      = 1'b0;
            batch_size_sel= 3'd0;

            // Start a new session only when idle.
            if (start_i && ready_o) begin
                busy_o             <= 1'b1;
                phase              <= (aad_len_bits_i != 64'd0) ? PH_AAD :
                                     ((ct_len_bits_i != 64'd0) ? PH_CT : PH_DONE);
                prep_state         <= PREP_H2_LAUNCH;

                h1_reg             <= h_i;
                h2_reg             <= '0;
                h3_reg             <= '0;
                h4_reg             <= '0;
                tag_mask_reg       <= tag_mask_i;
                aad_len_bits_reg   <= aad_len_bits_i;
                ct_len_bits_reg    <= ct_len_bits_i;

                y_acc              <= '0;

                recv_done          <= (aad_len_bits_i == 64'd0) && (ct_len_bits_i == 64'd0);
                len_block_enqueued <= 1'b0;
                done_emitted       <= 1'b0;

                wr_ptr             <= '0;
                rd_ptr             <= '0;
                fifo_count         <= '0;

                batch_busy         <= 1'b0;
                batch_size_launch  <= 3'd0;
            end
            else if (busy_o) begin
                // ----------------------------------------------------
                // H-power precompute scheduler
                // ----------------------------------------------------
                case (prep_state)
                    PREP_H2_LAUNCH: begin
                        pre_a      <= h1_reg;
                        pre_b      <= h1_reg;
                        pre_start  <= 1'b1;
                        prep_state <= PREP_H2_WAIT;
                    end

                    PREP_H2_WAIT: begin
                        if (pre_valid) begin
                            h2_reg     <= pre_out;
                            prep_state <= PREP_H3_LAUNCH;
                        end
                    end

                    PREP_H3_LAUNCH: begin
                        pre_a      <= h2_reg;
                        pre_b      <= h1_reg;
                        pre_start  <= 1'b1;
                        prep_state <= PREP_H3_WAIT;
                    end

                    PREP_H3_WAIT: begin
                        if (pre_valid) begin
                            h3_reg     <= pre_out;
                            prep_state <= PREP_H4_LAUNCH;
                        end
                    end

                    PREP_H4_LAUNCH: begin
                        pre_a      <= h2_reg;
                        pre_b      <= h2_reg;
                        pre_start  <= 1'b1;
                        prep_state <= PREP_H4_WAIT;
                    end

                    PREP_H4_WAIT: begin
                        if (pre_valid) begin
                            h4_reg     <= pre_out;
                            prep_state <= PREP_READY;
                        end
                    end

                    default: begin
                        // PREP_IDLE / PREP_READY: no action
                    end
                endcase

                // ----------------------------------------------------
                // Ingest AAD/CT stream into FIFO (plus length block)
                // ----------------------------------------------------
                if ((phase == PH_AAD) && aad_valid_i && aad_ready_o) begin
                    do_enq   = 1'b1;
                    enq_data = aad_data_i;

                    if (aad_last_i) begin
                        if (ct_len_bits_reg != 64'd0)
                            phase <= PH_CT;
                        else begin
                            phase     <= PH_DONE;
                            recv_done <= 1'b1;
                        end
                    end
                end
                else if ((phase == PH_CT) && ct_valid_i && ct_ready_o) begin
                    do_enq   = 1'b1;
                    enq_data = ct_data_i;

                    if (ct_last_i) begin
                        phase     <= PH_DONE;
                        recv_done <= 1'b1;
                    end
                end
                else if ((phase == PH_DONE) && recv_done && !len_block_enqueued
                         && (fifo_count < FIFO_DEPTH)) begin
                    do_enq            = 1'b1;
                    enq_data          = {aad_len_bits_reg, ct_len_bits_reg};
                    len_block_enqueued<= 1'b1;
                end

                if (do_enq) begin
                    fifo_mem[wr_ptr] <= enq_data;
                    wr_ptr <= wr_ptr + {{(PTR_W-1){1'b0}}, 1'b1};
                end

                // ----------------------------------------------------
                // Launch next GHASH batch when powers are ready
                // ----------------------------------------------------
                if ((prep_state == PREP_READY) && !batch_busy) begin
                    if (fifo_count >= 4)
                        batch_size_sel = 3'd4;
                    else if (all_input_enqueued && (fifo_count != 0))
                        batch_size_sel = fifo_count[2:0];
                    else
                        batch_size_sel = 3'd0;

                    if (batch_size_sel != 3'd0)
                        do_batch = 1'b1;
                end

                if (do_batch) begin
                    logic [0:127] b0, b1, b2, b3;
                    b0 = fifo_mem[rd_ptr];
                    b1 = fifo_mem[rd_ptr + PTR_INC1];
                    b2 = fifo_mem[rd_ptr + PTR_INC2];
                    b3 = fifo_mem[rd_ptr + PTR_INC3];

                    // Default unused lanes to zero.
                    lane_a0 <= '0; lane_b0 <= h1_reg;
                    lane_a1 <= '0; lane_b1 <= h1_reg;
                    lane_a2 <= '0; lane_b2 <= h1_reg;
                    lane_a3 <= '0; lane_b3 <= h1_reg;

                    case (batch_size_sel)
                        3'd1: begin
                            lane_a0 <= y_acc ^ b0; lane_b0 <= h1_reg;
                        end
                        3'd2: begin
                            lane_a0 <= y_acc ^ b0; lane_b0 <= h2_reg;
                            lane_a1 <= b1;         lane_b1 <= h1_reg;
                        end
                        3'd3: begin
                            lane_a0 <= y_acc ^ b0; lane_b0 <= h3_reg;
                            lane_a1 <= b1;         lane_b1 <= h2_reg;
                            lane_a2 <= b2;         lane_b2 <= h1_reg;
                        end
                        default: begin // 4
                            lane_a0 <= y_acc ^ b0; lane_b0 <= h4_reg;
                            lane_a1 <= b1;         lane_b1 <= h3_reg;
                            lane_a2 <= b2;         lane_b2 <= h2_reg;
                            lane_a3 <= b3;         lane_b3 <= h1_reg;
                        end
                    endcase

                    lane_start        <= 1'b1;
                    batch_busy        <= 1'b1;
                    batch_size_launch <= batch_size_sel;

                    case (batch_size_sel)
                        3'd1: rd_ptr <= rd_ptr + PTR_INC1;
                        3'd2: rd_ptr <= rd_ptr + PTR_INC2;
                        3'd3: rd_ptr <= rd_ptr + PTR_INC3;
                        default: rd_ptr <= rd_ptr + PTR_INC4;
                    endcase
                end

                // ----------------------------------------------------
                // Batch completion updates Y accumulator
                // ----------------------------------------------------
                if (lane_done) begin
                    y_acc      <= lane_xor;
                    batch_busy <= 1'b0;
                end

                // ----------------------------------------------------
                // FIFO count accounting
                // ----------------------------------------------------
                count_next = fifo_count;
                if (do_enq)
                    count_next = count_next + 1;
                if (do_batch)
                    count_next = count_next - batch_size_sel;
                fifo_count <= count_next[PTR_W:0];

                // ----------------------------------------------------
                // Session complete: emit GHASH + TAG pulse
                // ----------------------------------------------------
                if ((prep_state == PREP_READY) && all_input_enqueued
                    && (fifo_count == 0) && !batch_busy && !done_emitted) begin
                    ghash_out_o   <= y_acc;
                    tag_out_o     <= y_acc ^ tag_mask_reg;
                    ghash_valid_o <= 1'b1;
                    tag_valid_o   <= 1'b1;
                    done_emitted  <= 1'b1;
                    busy_o        <= 1'b0;
                    phase         <= PH_IDLE;
                    prep_state    <= PREP_IDLE;
                end
            end
        end
    end

endmodule
