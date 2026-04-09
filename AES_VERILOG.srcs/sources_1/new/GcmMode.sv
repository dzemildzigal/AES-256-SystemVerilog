`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// AES-256 GCM datapath top.
//
// Shared datapath resources:
//   - 1x KeyExpansion
//   - 1x EncryptPipelined (shared for H, E_K(J0), payload CTR keystream)
//   - 1x GHashEngine
//
// Scheduler order per cycle (highest priority first):
//   1) H   = AES_K(0^128)                    (on new key)
//   2) J0  = AES_K(nonce || 0x00000001)      (on session start)
//   3) CTR payload keystream blocks           (streaming)
//////////////////////////////////////////////////////////////////////////////////

module GcmMode #(
    parameter integer GHASH_FIFO_DEPTH = 16
)(
    input  logic         clk,
    input  logic         rst,

    // Key interface
    input  logic         new_masterkey,
    input  logic [0:255] masterkey,
    output logic [3:0]   keys_ready,

    // Session control
    input  logic         session_start_i,
    input  logic [0:95]  nonce_i,
    input  logic [0:63]  aad_len_bits_i,
    input  logic [0:63]  pt_len_bits_i,
    output logic         session_ready_o,

    // AAD stream (128-bit block aligned)
    input  logic [0:127] aad_data_i,
    input  logic         aad_valid_i,
    input  logic         aad_last_i,
    output logic         aad_ready_o,

    // Plaintext stream (128-bit blocks)
    input  logic [0:127] pt_data_i,
    input  logic         pt_valid_i,
    input  logic         pt_last_i,
    output logic         pt_ready_o,

    // Ciphertext stream (128-bit blocks)
    output logic [0:127] ct_data_o,
    output logic         ct_valid_o,
    output logic         ct_last_o,

    // Auth outputs
    output logic [0:127] ghash_out_o,
    output logic         ghash_valid_o,
    output logic [0:127] tag_out_o,
    output logic         tag_valid_o,

    // Status
    output logic [0:31]  counter_val_o,
    output logic         h_valid_o,
    output logic         busy_o,
    output logic [0:31]  session_cycles_o,
    output logic         session_cycles_valid_o
    );

    localparam integer ENC_LAT = 15;

    localparam logic [1:0] SRC_IDLE = 2'b00;
    localparam logic [1:0] SRC_H    = 2'b01;
    localparam logic [1:0] SRC_J0   = 2'b10;
    localparam logic [1:0] SRC_PT   = 2'b11;

    // ----------------------------------------------------------------
    // Key expansion
    // ----------------------------------------------------------------
    logic [0:1919] expanded_key;

    KeyExpansion ke(
        .clk(clk),
        .rst(rst),
        .new_masterkey(new_masterkey),
        .masterkey(masterkey),
        .w(expanded_key),
        .keys_ready(keys_ready)
    );

    // ----------------------------------------------------------------
    // Session/key state
    // ----------------------------------------------------------------
    logic         key_present;
    logic         pending_h;
    logic [0:127] h_reg;

    logic         pending_j0;
    logic         j0_launched;
    logic [0:127] tag_mask_reg;
    logic         tag_mask_valid;

    logic         sess_pending;
    logic         sess_running;

    logic [0:95]  nonce_reg;
    logic [0:63]  aad_len_bits_reg;
    logic [0:63]  pt_len_bits_reg;
    logic [0:31]  session_cycles_live;
    logic         session_count_active;

    // ----------------------------------------------------------------
    // Shared encrypt scheduler
    // ----------------------------------------------------------------
    wire session_accept = session_start_i && session_ready_o;
    wire sched_block    = new_masterkey || session_accept;

    wire launch_h  = (!sched_block) && pending_h;
    wire launch_j0 = (!sched_block) && (!pending_h) && pending_j0 && key_present;
    wire slot_for_pt = (!sched_block) && (!pending_h) && !(pending_j0 && key_present);

    wire h_path_ready      = h_valid_o || pending_h;
    wire pt_path_pending   = sess_pending && (aad_len_bits_reg == 64'd0) && j0_launched && h_path_ready;

    logic gh_ct_ready;
    wire pt_path_running   = sess_running && gh_ct_ready;
    wire pt_base_ready     = key_present && (pt_path_pending || pt_path_running);

    assign pt_ready_o      = slot_for_pt && pt_base_ready;
    wire pt_fire           = pt_valid_i && pt_ready_o;

    wire enc_start = launch_h || launch_j0 || pt_fire;
    wire [1:0] enc_src = launch_h ? SRC_H :
                         launch_j0 ? SRC_J0 :
                         pt_fire ? SRC_PT : SRC_IDLE;

    wire [0:127] enc_in = launch_h ? 128'd0 :
                          launch_j0 ? {nonce_reg, 32'h00000001} :
                          {nonce_reg, counter_val_o};

    // ----------------------------------------------------------------
    // Shared EncryptPipelined core
    // ----------------------------------------------------------------
    wire [0:127] enc_out;
    wire         enc_valid;

    EncryptPipelined ep(
        .clk(clk),
        .rst(rst),
        .start_i(enc_start),
        .in(enc_in),
        .expanded_key(expanded_key),
        .out(enc_out),
        .valid_data(enc_valid)
    );

    // Track which source launched each block so output can be routed.
    logic [1:0] src_pipe [0:ENC_LAT-1];

    // Delay plaintext to align with keystream output.
    logic [0:127] pt_delay [0:ENC_LAT-1];
    logic         last_delay [0:ENC_LAT-1];

    // ----------------------------------------------------------------
    // GHASH engine
    // ----------------------------------------------------------------
    logic         gh_start;
    wire          gh_ready;
    wire          gh_busy;
    wire [0:127]  gh_out;
    wire          gh_out_valid;
    wire [0:127]  gh_tag;
    wire          gh_tag_valid;

    wire          gh_aad_ready;
    wire          gh_ct_ready_int;

    assign gh_ct_ready = gh_ct_ready_int;

    GHashEngine #(
        .FIFO_DEPTH(GHASH_FIFO_DEPTH)
    ) gh(
        .clk(clk),
        .rst(rst),
        .start_i(gh_start),
        .h_i(h_reg),
        .tag_mask_i(tag_mask_reg),
        .aad_len_bits_i(aad_len_bits_reg),
        .ct_len_bits_i(pt_len_bits_reg),
        .aad_data_i(aad_data_i),
        .aad_valid_i(aad_valid_i && sess_running),
        .aad_last_i(aad_last_i && sess_running),
        .aad_ready_o(gh_aad_ready),
        .ct_data_i(ct_data_o),
        .ct_valid_i(ct_valid_o && sess_running),
        .ct_last_i(ct_last_o && sess_running),
        .ct_ready_o(gh_ct_ready_int),
        .ready_o(gh_ready),
        .busy_o(gh_busy),
        .ghash_out_o(gh_out),
        .ghash_valid_o(gh_out_valid),
        .tag_out_o(gh_tag),
        .tag_valid_o(gh_tag_valid)
    );

    assign aad_ready_o = sess_running ? gh_aad_ready : 1'b0;

    // ----------------------------------------------------------------
    // Top-level status
    // ----------------------------------------------------------------
    assign session_ready_o = !sess_pending && !sess_running && !pending_j0 && gh_ready;

    assign busy_o = pending_h || pending_j0 || sess_pending || sess_running || gh_busy;

    assign ghash_out_o   = gh_out;
    assign ghash_valid_o = gh_out_valid;
    assign tag_out_o     = gh_tag;
    assign tag_valid_o   = gh_tag_valid;

    // ----------------------------------------------------------------
    // Sequential control / datapath
    // ----------------------------------------------------------------
    integer i;
    always_ff @(posedge clk) begin
        if (rst) begin
            key_present      <= 1'b0;
            pending_h        <= 1'b0;
            h_reg            <= '0;
            h_valid_o        <= 1'b0;

            pending_j0       <= 1'b0;
            j0_launched      <= 1'b0;
            tag_mask_reg     <= '0;
            tag_mask_valid   <= 1'b0;

            sess_pending     <= 1'b0;
            sess_running     <= 1'b0;

            nonce_reg        <= '0;
            aad_len_bits_reg <= '0;
            pt_len_bits_reg  <= '0;

            counter_val_o    <= 32'd2;

            ct_data_o        <= '0;
            ct_valid_o       <= 1'b0;
            ct_last_o        <= 1'b0;

            gh_start         <= 1'b0;
            session_cycles_o <= '0;
            session_cycles_valid_o <= 1'b0;
            session_cycles_live <= '0;
            session_count_active <= 1'b0;

            for (i = 0; i < ENC_LAT; i = i + 1) begin
                src_pipe[i]   <= SRC_IDLE;
                pt_delay[i]   <= '0;
                last_delay[i] <= 1'b0;
            end
        end
        else begin
            // Default pulses
            gh_start   <= 1'b0;
            ct_valid_o <= 1'b0;
            ct_last_o  <= 1'b0;
            session_cycles_valid_o <= 1'b0;

            // Shift routing / data delay pipelines
            src_pipe[0]   <= enc_start ? enc_src : SRC_IDLE;
            pt_delay[0]   <= pt_fire ? pt_data_i : '0;
            last_delay[0] <= pt_fire ? pt_last_i : 1'b0;

            for (i = 1; i < ENC_LAT; i = i + 1) begin
                src_pipe[i]   <= src_pipe[i-1];
                pt_delay[i]   <= pt_delay[i-1];
                last_delay[i] <= last_delay[i-1];
            end

            // New master key: key is considered present immediately,
            // but H must be recomputed for GHASH under this key.
            if (new_masterkey) begin
                key_present    <= 1'b1;
                pending_h      <= 1'b1;
                h_valid_o      <= 1'b0;
                tag_mask_valid <= 1'b0;
            end

            // Accept a new session configuration.
            if (session_accept) begin
                nonce_reg        <= nonce_i;
                aad_len_bits_reg <= aad_len_bits_i;
                pt_len_bits_reg  <= pt_len_bits_i;

                pending_j0       <= 1'b1;
                j0_launched      <= 1'b0;
                tag_mask_valid   <= 1'b0;

                sess_pending     <= 1'b1;
                sess_running     <= 1'b0;

                counter_val_o    <= 32'd2;

                session_cycles_live  <= '0;
                session_count_active <= 1'b1;
            end

            if (session_count_active)
                session_cycles_live <= session_cycles_live + 32'd1;

            // Mark scheduled work items as consumed.
            if (launch_h)
                pending_h <= 1'b0;

            if (launch_j0) begin
                pending_j0  <= 1'b0;
                j0_launched <= 1'b1;
            end

            if (pt_fire)
                counter_val_o <= counter_val_o + 32'd1;

            // Route shared encrypt output by source tag.
            if (enc_valid) begin
                case (src_pipe[ENC_LAT-1])
                    SRC_H: begin
                        h_reg     <= enc_out;
                        h_valid_o <= 1'b1;
                    end

                    SRC_J0: begin
                        tag_mask_reg   <= enc_out;
                        tag_mask_valid <= 1'b1;
                    end

                    SRC_PT: begin
                        ct_data_o  <= enc_out ^ pt_delay[ENC_LAT-1];
                        ct_valid_o <= 1'b1;
                        ct_last_o  <= last_delay[ENC_LAT-1];
                    end

                    default: begin
                        // idle slot
                    end
                endcase
            end

            // Start GHASH once both H and E_K(J0) are available.
            if (sess_pending && h_valid_o && tag_mask_valid && gh_ready) begin
                gh_start     <= 1'b1;
                sess_pending <= 1'b0;
                sess_running <= 1'b1;
            end

            // Session completes when GHASH emits the final tag.
            if (gh_tag_valid)
                sess_running <= 1'b0;

            if (gh_tag_valid && session_count_active) begin
                session_cycles_o       <= session_cycles_live + 32'd1;
                session_cycles_valid_o <= 1'b1;
                session_count_active   <= 1'b0;
            end
        end
    end

endmodule
