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
// - Uses a single 1-cycle-latency GFMult128 with result forwarding
//   to achieve 1 block per cycle throughput.
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

    // ----------------------------------------------------------------
    // Session registers
    // ----------------------------------------------------------------
    phase_t       phase;

    logic [0:127] h_reg;
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

    // Combinational FIFO read port.
    wire [0:127]  fifo_head = fifo_mem[rd_ptr];

    // ----------------------------------------------------------------
    // Single GF(2^128) multiplier (1-cycle latency)
    // ----------------------------------------------------------------
    wire [0:127]  mul_out;
    wire          mul_valid;

    // Forwarding: use just-completed result instead of stale y_acc.
    wire          mul_completing = mul_valid && busy_o;
    wire [0:127]  y_fwd = mul_completing ? mul_out : y_acc;

    // Can we launch a multiply this cycle?
    wire          can_process = busy_o && !done_emitted && (fifo_count > 0);

    // Combinational drive to multiplier (enables 1-block/cycle forwarding).
    wire [0:127]  mul_a = y_fwd ^ fifo_head;
    wire [0:127]  mul_b = h_reg;

    GFMult128 mul(
        .clk(clk),
        .rst(rst),
        .start_i(can_process),
        .in_a(mul_a),
        .in_b(mul_b),
        .out_o(mul_out),
        .valid_o(mul_valid)
    );

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

            h_reg              <= '0;
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

            ghash_out_o        <= '0;
            ghash_valid_o      <= 1'b0;
            tag_out_o          <= '0;
            tag_valid_o        <= 1'b0;
        end
        else begin
            logic         do_enq;
            logic [0:127] enq_data;
            int           count_next;

            // 1-cycle pulse defaults
            ghash_valid_o <= 1'b0;
            tag_valid_o   <= 1'b0;

            do_enq        = 1'b0;
            enq_data      = '0;

            // Start a new session only when idle.
            if (start_i && ready_o) begin
                busy_o             <= 1'b1;
                phase              <= (aad_len_bits_i != 64'd0) ? PH_AAD :
                                     ((ct_len_bits_i != 64'd0) ? PH_CT : PH_DONE);

                h_reg              <= h_i;
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
            end
            else if (busy_o) begin
                // ----------------------------------------------------
                // Update y_acc when multiply completes
                // ----------------------------------------------------
                if (mul_completing)
                    y_acc <= mul_out;

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
                // Advance FIFO read pointer on multiply launch
                // ----------------------------------------------------
                if (can_process)
                    rd_ptr <= rd_ptr + {{(PTR_W-1){1'b0}}, 1'b1};

                // ----------------------------------------------------
                // FIFO count accounting
                // ----------------------------------------------------
                count_next = fifo_count;
                if (do_enq)
                    count_next = count_next + 1;
                if (can_process)
                    count_next = count_next - 1;
                fifo_count <= count_next[PTR_W:0];

                // ----------------------------------------------------
                // Session complete: emit GHASH + TAG pulse
                // ----------------------------------------------------
                if (all_input_enqueued && (fifo_count == 0)
                    && !mul_valid && !done_emitted) begin
                    ghash_out_o   <= y_acc;
                    tag_out_o     <= y_acc ^ tag_mask_reg;
                    ghash_valid_o <= 1'b1;
                    tag_valid_o   <= 1'b1;
                    done_emitted  <= 1'b1;
                    busy_o        <= 1'b0;
                    phase         <= PH_IDLE;
                end
            end
        end
    end

endmodule
