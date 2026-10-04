`timescale 1ns/1ps
// ============================================================
// ALU shift / rotate sub-unit (bit-serial, multi-cycle)
//
// A single serial shifter covers SHL, SHR, arithmetic right shift and
// the ROL/ROR rotations. SHL/SHR/SAR hold the serialiser for the first
// (shift amount) cycles while emitting the fill bit, then stream the
// operand. Rotations pre-rotate a circular register into position
// before emitting, so they take cpu_pkg::WORD_WIDTH + offset cycles.
// ============================================================

module shifter (
    input  logic clk,
    input  logic rst,
    input  logic start,

    input  cpu_pkg::word_t operand_a, operand_b,
    input  opcode_pkg::opcode_t op,

    output cpu_pkg::word_t result,
    output logic busy,
    output logic done
);

    import cpu_pkg::*;
    import opcode_pkg::*;

    // Shift-amount width and a counter wide enough for rotate offsets.
    localparam int SHIFT_WIDTH   = $clog2(cpu_pkg::WORD_WIDTH);
    localparam int COUNTER_WIDTH = SHIFT_WIDTH + 1;

    logic is_shl, is_shr, is_sar, is_rol, is_rotate, is_shift;

    always_comb begin
        is_shl    = (op == ALU_SHL);
        is_shr    = (op == ALU_SHR);
        is_sar    = (op == ALU_SAR);
        is_rol    = (op == ALU_ROL);
        is_rotate = is_rol || (op == ALU_ROR);
        is_shift  = is_shl || is_shr || is_sar;
    end

    function automatic logic [cpu_pkg::WORD_WIDTH-1:0] rev(
        input logic [cpu_pkg::WORD_WIDTH-1:0] x);
        integer i;
        for (i = 0; i < cpu_pkg::WORD_WIDTH; i = i + 1)
            rev[i] = x[cpu_pkg::WORD_WIDTH-1-i];
        return rev;
    endfunction

    typedef enum logic [1:0] {
        S_IDLE,
        S_RUN,
        S_DONE
    } state_e;

    state_e state;

    logic [cpu_pkg::WORD_WIDTH-1:0] a_r, a_sr, r_sr;
    logic [COUNTER_WIDTH-1:0]       cnt, limit, rot_pre;

    // ------------------------------------------------------------
    // Preload
    // ------------------------------------------------------------
    logic [cpu_pkg::WORD_WIDTH-1:0]   ld_a_sr;
    logic [COUNTER_WIDTH-1:0]         ld_rot_pre, ld_limit;
    logic [SHIFT_WIDTH-1:0]           rot_k;

    assign rot_k     = operand_b[SHIFT_WIDTH-1:0];
    assign ld_a_sr   = (is_shr || is_sar) ? rev(operand_a) : operand_a;
    assign ld_rot_pre = is_rol
                        ? ((cpu_pkg::WORD_WIDTH - rot_k) &
                           (cpu_pkg::WORD_WIDTH - 1))
                        : rot_k;
    assign ld_limit  = is_rotate
                       ? (cpu_pkg::WORD_WIDTH + ld_rot_pre - 1)
                       : (cpu_pkg::WORD_WIDTH - 1);

    // ------------------------------------------------------------
    // Per-cycle serial cpu_datapath
    // ------------------------------------------------------------
    logic [COUNTER_WIDTH-1:0] sh_amt;
    logic                     shift_hold, shift_fill, emitting, r_msb_first;
    logic                     a_bit, out_bit;
    logic [cpu_pkg::WORD_WIDTH-1:0] a_sr_nxt, r_sr_nxt;

    assign a_bit = a_sr[0];
    assign r_msb_first = is_shr || is_sar;

    // Shift amount capped at a full-width shift.
    assign sh_amt = (operand_b >= cpu_pkg::WORD_WIDTH)
                    ? cpu_pkg::WORD_WIDTH
                    : {1'b0, rot_k};

    assign shift_hold = is_shift && (cnt < sh_amt);
    assign shift_fill = is_sar ? a_r[cpu_pkg::WORD_WIDTH-1] : 1'b0;
    assign emitting   = is_rotate ? (cnt >= rot_pre) : 1'b1;

    always_comb begin
        if (is_shift)        out_bit = shift_hold ? shift_fill : a_bit;
        else if (is_rotate)  out_bit = a_bit;
        else                 out_bit = 1'b0;
    end

    always_comb begin
        // Circular for rotate offsets, held during a shift fill.
        a_sr_nxt = is_rotate
                   ? {a_sr[0], a_sr[cpu_pkg::WORD_WIDTH-1:1]}
                   : (shift_hold ? a_sr
                                 : {1'b0, a_sr[cpu_pkg::WORD_WIDTH-1:1]});

        // LSB-first streams fill from the top; MSB-first from the bottom.
        if (is_rotate)
            r_sr_nxt = emitting ? {out_bit, r_sr[cpu_pkg::WORD_WIDTH-1:1]}
                                : r_sr;
        else if (r_msb_first)
            r_sr_nxt = {r_sr[cpu_pkg::WORD_WIDTH-2:0], out_bit};
        else
            r_sr_nxt = {out_bit, r_sr[cpu_pkg::WORD_WIDTH-1:1]};
    end

    assign result = r_sr;
    assign busy   = (state != S_IDLE);
    assign done   = (state == S_DONE);

    // ------------------------------------------------------------
    // Sequencer
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state   <= S_IDLE;
            cnt     <= '0;
            limit   <= '0;
            rot_pre <= '0;
            a_r     <= '0;
            a_sr    <= '0;
            r_sr    <= '0;
        end else begin
            case (state)

                S_IDLE: begin
                    if (start) begin
                        a_r     <= operand_a;
                        a_sr    <= ld_a_sr;
                        r_sr    <= '0;
                        rot_pre <= ld_rot_pre;
                        limit   <= ld_limit;
                        cnt     <= '0;
                        state   <= S_RUN;
                    end
                end

                S_RUN: begin
                    a_sr <= a_sr_nxt;
                    r_sr <= r_sr_nxt;

                    if (cnt == limit)
                        state <= S_DONE;
                    else
                        cnt <= cnt + 1'b1;
                end

                S_DONE: state <= S_IDLE;

                default: state <= S_IDLE;

            endcase
        end
    end

endmodule
