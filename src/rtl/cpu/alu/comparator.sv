`timescale 1ns/1ps
// ============================================================
// ALU comparison sub-unit (bit-serial, multi-cycle)
//
// Equality and ordered comparisons plus the MIN/MAX operations, all
// derived from a single MSB-first comparison: the first differing bit
// decides. Signed variants flip the sign bit and compare unsigned.
// The comparator outputs a 1-bit boolean (zero-extended to the word)
// for the comparisons and the selected operand for MIN/MAX, so no
// separate compare path is needed in the arithmetic unit.
// ============================================================

module comparator (
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

    localparam int COUNTER_WIDTH = $clog2(cpu_pkg::WORD_WIDTH);

    localparam logic [cpu_pkg::WORD_WIDTH-1:0] MSB_ONE =
        {1'b1, {(cpu_pkg::WORD_WIDTH-1){1'b0}}};

    logic is_signed, is_minmax, is_min;

    always_comb begin
        is_minmax = (op >= ALU_MINU) && (op <= ALU_MAXS);
        is_signed = ((op >= ALU_LTS) && (op <= ALU_GES)) ||
                    ((op >= ALU_MINS) && (op <= ALU_MAXS));
        is_min    = (op == ALU_MINU) || (op == ALU_MINS);
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

    logic [cpu_pkg::WORD_WIDTH-1:0] a_r, b_r;
    logic [cpu_pkg::WORD_WIDTH-1:0] a_sr, b_sr;
    logic [COUNTER_WIDTH-1:0]       cnt;

    logic cmp_eq, cmp_gt, cmp_lt;
    logic [cpu_pkg::WORD_WIDTH-1:0] result_r;

    // Preload: MSB-first, sign bit flipped for signed comparisons.
    logic [cpu_pkg::WORD_WIDTH-1:0] cmp_a, cmp_b;
    assign cmp_a = is_signed ? (operand_a ^ MSB_ONE) : operand_a;
    assign cmp_b = is_signed ? (operand_b ^ MSB_ONE) : operand_b;

    // Per-cycle comparison state.
    logic a_bit, b_bit;
    logic cmp_eq_nxt, cmp_gt_nxt, cmp_lt_nxt;

    assign a_bit = a_sr[0];
    assign b_bit = b_sr[0];

    always_comb begin
        cmp_eq_nxt = cmp_eq;
        cmp_gt_nxt = cmp_gt;
        cmp_lt_nxt = cmp_lt;

        if (cmp_eq) begin
            if (a_bit & ~b_bit) begin
                cmp_gt_nxt = 1'b1;
                cmp_eq_nxt = 1'b0;
            end else if (~a_bit & b_bit) begin
                cmp_lt_nxt = 1'b1;
                cmp_eq_nxt = 1'b0;
            end
        end
    end

    // Result finalisation.
    logic [cpu_pkg::WORD_WIDTH-1:0] final_r;

    always_comb begin
        if (is_minmax) begin
            if (is_min)
                final_r = cmp_lt_nxt ? a_r : b_r;
            else
                final_r = cmp_gt_nxt ? a_r : b_r;
        end else begin
            case (op)
                ALU_NE:           final_r = {{(cpu_pkg::WORD_WIDTH-1){1'b0}}, ~cmp_eq_nxt};
                ALU_LTU, ALU_LTS: final_r = {{(cpu_pkg::WORD_WIDTH-1){1'b0}},  cmp_lt_nxt};
                ALU_LEU, ALU_LES: final_r = {{(cpu_pkg::WORD_WIDTH-1){1'b0}},
                                             (cmp_lt_nxt | cmp_eq_nxt)};
                ALU_GTU, ALU_GTS: final_r = {{(cpu_pkg::WORD_WIDTH-1){1'b0}},  cmp_gt_nxt};
                ALU_GEU, ALU_GES: final_r = {{(cpu_pkg::WORD_WIDTH-1){1'b0}},
                                             (cmp_gt_nxt | cmp_eq_nxt)};
                default:          final_r = {{(cpu_pkg::WORD_WIDTH-1){1'b0}},  cmp_eq_nxt};
            endcase
        end
    end

    assign result = result_r;
    assign busy   = (state != S_IDLE);
    assign done   = (state == S_DONE);

    // Sequencer: MSB-first, exactly cpu_pkg::WORD_WIDTH cycles.
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= S_IDLE;
            cnt      <= '0;
            a_r      <= '0;
            b_r      <= '0;
            a_sr     <= '0;
            b_sr     <= '0;
            cmp_eq   <= 1'b1;
            cmp_gt   <= 1'b0;
            cmp_lt   <= 1'b0;
            result_r <= '0;
        end else begin
            case (state)

                S_IDLE: begin
                    if (start) begin
                        a_r    <= operand_a;
                        b_r    <= operand_b;
                        a_sr   <= rev(cmp_a);
                        b_sr   <= rev(cmp_b);
                        cmp_eq <= 1'b1;
                        cmp_gt <= 1'b0;
                        cmp_lt <= 1'b0;
                        cnt    <= '0;
                        state  <= S_RUN;
                    end
                end

                S_RUN: begin
                    a_sr   <= {1'b0, a_sr[cpu_pkg::WORD_WIDTH-1:1]};
                    b_sr   <= {1'b0, b_sr[cpu_pkg::WORD_WIDTH-1:1]};
                    cmp_eq <= cmp_eq_nxt;
                    cmp_gt <= cmp_gt_nxt;
                    cmp_lt <= cmp_lt_nxt;

                    if (cnt == cpu_pkg::WORD_WIDTH - 1) begin
                        result_r <= final_r;
                        state    <= S_DONE;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end

                S_DONE: state <= S_IDLE;

                default: state <= S_IDLE;

            endcase
        end
    end

endmodule
