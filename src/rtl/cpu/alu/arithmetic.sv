`timescale 1ns/1ps
// ============================================================
// ALU arithmetic sub-unit (bit-serial, multi-cycle)
//
// ADD/ADC/SUB/SBC/NEG/ABS are produced one bit per clock through a
// single 1-bit adder plus a carry flip-flop. MUL/MULH use an iterative
// shift-add loop and DIV/MOD a restoring loop, both built from narrow
// adders instead of parallel multipliers/dividers.
//
// Side-channel status:
//   carry    : unsigned carry out (ADD) / no borrow (SUB)
//   overflow : signed overflow; set when the true result is not
//              representable in cpu_pkg::WORD_WIDTH bits
//   div_zero : asserted whenever the divisor operand_b is zero
//
// The signed MIN/-1 division and modulo cases are special-cased to
// avoid the implementation-defined overflow of signed division.
// ============================================================

module arithmetic (
    input  logic clk,
    input  logic rst,
    input  logic start,

    input  cpu_pkg::word_t operand_a, operand_b,
    input  opcode_pkg::opcode_t op,
    input  logic carry_in,

    output cpu_pkg::word_t result,
    output logic carry,
    output logic overflow,
    output logic div_zero,
    output logic busy,
    output logic done
);

    import cpu_pkg::*;
    import opcode_pkg::*;
    import alu_pkg::*;

    // ------------------------------------------------------------
    // Operation classification
    // ------------------------------------------------------------
    logic is_addsub, is_adc, is_sbc, is_sub, is_neg, is_abs;
    logic is_mul, is_mulh, is_divop, is_div, is_signed_div;
    logic use_neg;

    always_comb begin
        is_addsub     = (op == ALU_ADD) || (op == ALU_ADC) ||
                        (op == ALU_SUB) || (op == ALU_SBC);
        is_adc        = (op == ALU_ADC);
        is_sbc        = (op == ALU_SBC);
        is_sub        = (op == ALU_SUB) || (op == ALU_SBC);
        is_neg        = (op == ALU_NEG);
        is_abs        = (op == ALU_ABS);
        is_mul        = (op == ALU_MUL) || (op == ALU_MULH);
        is_mulh       = (op == ALU_MULH);
        is_divop      = (op >= ALU_DIVU) && (op <= ALU_MODS);
        is_div        = (op == ALU_DIVU) || (op == ALU_DIVS);
        is_signed_div = (op == ALU_DIVS) || (op == ALU_MODS);
    end

    // ------------------------------------------------------------
    // Engine state
    // ------------------------------------------------------------
    alu_state_e state;

    logic [cpu_pkg::WORD_WIDTH-1:0] a_r, b_r;
    logic [cpu_pkg::WORD_WIDTH-1:0] a_sr, b_sr, r_sr;
    logic [SERIAL_WIDTH-1:0]        cnt;
    logic                           carry_ff;

    logic [2*cpu_pkg::WORD_WIDTH-1:0] macc, mcand;
    logic [cpu_pkg::WORD_WIDTH:0]     drem;
    logic [cpu_pkg::WORD_WIDTH-1:0]   dquo;

    logic [cpu_pkg::WORD_WIDTH-1:0] result_r;
    logic                           carry_r, ovf_r, dz_r;

    assign result   = result_r;
    assign carry    = carry_r;
    assign overflow = ovf_r;
    assign div_zero = dz_r;
    assign busy     = (state != S_IDLE);
    assign done     = (state == S_DONE);

    // ------------------------------------------------------------
    // Serialiser preload
    // ------------------------------------------------------------
    logic [cpu_pkg::WORD_WIDTH-1:0] op_a_abs, ld_a_sr, ld_b_sr;
    logic                           ld_carry_ff;

    assign op_a_abs = operand_a[cpu_pkg::WORD_WIDTH-1]
                      ? twos_neg(operand_a) : operand_a;

    always_comb begin
        // Restoring division consumes the dividend MSB-first.
        ld_a_sr = is_divop ? rev(is_signed_div ? op_a_abs : operand_a)
                           : operand_a;
        ld_b_sr = operand_b;
    end

    always_comb begin
        if (is_neg)             ld_carry_ff = 1'b1;
        else if (is_abs)        ld_carry_ff = operand_a[cpu_pkg::WORD_WIDTH-1];
        else if (is_sbc)        ld_carry_ff = carry_in;
        else if (op == ALU_SUB) ld_carry_ff = 1'b1;
        else if (is_adc)        ld_carry_ff = carry_in;
        else                    ld_carry_ff = 1'b0;
    end

    // ------------------------------------------------------------
    // Per-cycle 1-bit datapath
    // ------------------------------------------------------------
    logic a_bit, b_bit, x_bit, y_bit, sum_bit, cout_bit, add_out;

    assign a_bit = a_sr[0];
    assign b_bit = b_sr[0];
    assign use_neg = is_neg || (is_abs && a_r[cpu_pkg::WORD_WIDTH-1]);

    always_comb begin
        x_bit    = use_neg ? 1'b0 : a_bit;
        y_bit    = use_neg ? ~a_bit : (b_bit ^ is_sub);
        sum_bit  = x_bit ^ y_bit ^ carry_ff;
        cout_bit = (x_bit & y_bit) | (carry_ff & (x_bit ^ y_bit));
        add_out  = (is_abs && !a_r[cpu_pkg::WORD_WIDTH-1]) ? a_bit : sum_bit;
    end

    // ------------------------------------------------------------
    // Next-state values
    // ------------------------------------------------------------
    logic [cpu_pkg::WORD_WIDTH-1:0]   r_sr_nxt, a_sr_nxt, b_sr_nxt;
    logic [2*cpu_pkg::WORD_WIDTH-1:0] macc_nxt, mcand_nxt;
    logic [cpu_pkg::WORD_WIDTH:0]     drem_shifted, drem_nxt;
    logic [cpu_pkg::WORD_WIDTH-1:0]   dquo_nxt, div_b;
    logic                             div_ge;

    assign div_b = is_signed_div
                   ? (b_r[cpu_pkg::WORD_WIDTH-1] ? twos_neg(b_r) : b_r)
                   : b_r;
    assign drem_shifted = {drem[cpu_pkg::WORD_WIDTH-1:0], a_bit};
    assign div_ge       = (drem_shifted >= {1'b0, div_b});

    always_comb begin
        a_sr_nxt  = {1'b0, a_sr[cpu_pkg::WORD_WIDTH-1:1]};
        b_sr_nxt  = {1'b0, b_sr[cpu_pkg::WORD_WIDTH-1:1]};
        r_sr_nxt  = {add_out, r_sr[cpu_pkg::WORD_WIDTH-1:1]};

        // Multiply (shift-add).
        macc_nxt  = b_bit ? (macc + mcand) : macc;
        mcand_nxt = mcand << 1;

        // Restoring divide.
        drem_nxt = div_ge ? (drem_shifted - {1'b0, div_b}) : drem_shifted;
        dquo_nxt = div_ge ? {dquo[cpu_pkg::WORD_WIDTH-2:0], 1'b1}
                          : {dquo[cpu_pkg::WORD_WIDTH-2:0], 1'b0};
    end

    // ------------------------------------------------------------
    // Result / status finalisation
    // ------------------------------------------------------------
    logic [cpu_pkg::WORD_WIDTH-1:0] final_r;
    logic f_carry, f_ovf, f_dz;

    always_comb begin
        if (is_mul)
            final_r = is_mulh
                      ? macc_nxt[2*cpu_pkg::WORD_WIDTH-1:cpu_pkg::WORD_WIDTH]
                      : macc_nxt[cpu_pkg::WORD_WIDTH-1:0];
        else if (is_divop) begin
            if (b_r == '0)
                final_r = '0;
            else if (is_signed_div && (a_r == MSB_ONE) && (b_r == ALL_ONES))
                final_r = is_div ? MSB_ONE : '0;
            else if (is_signed_div) begin
                if (is_div)
                    final_r = (a_r[cpu_pkg::WORD_WIDTH-1] ^
                               b_r[cpu_pkg::WORD_WIDTH-1])
                              ? twos_neg(dquo_nxt) : dquo_nxt;
                else
                    final_r = a_r[cpu_pkg::WORD_WIDTH-1]
                              ? twos_neg(drem_nxt[cpu_pkg::WORD_WIDTH-1:0])
                              : drem_nxt[cpu_pkg::WORD_WIDTH-1:0];
            end else begin
                final_r = is_div ? dquo_nxt : drem_nxt[cpu_pkg::WORD_WIDTH-1:0];
            end
        end else begin
            final_r = r_sr_nxt;
        end
    end

    always_comb begin
        f_carry = 1'b0;
        f_ovf   = 1'b0;
        f_dz    = 1'b0;

        if (is_addsub) begin
            f_carry = cout_bit;
            if (is_sub)
                f_ovf = (a_r[cpu_pkg::WORD_WIDTH-1] ^ b_r[cpu_pkg::WORD_WIDTH-1]) &
                        (a_r[cpu_pkg::WORD_WIDTH-1] ^ final_r[cpu_pkg::WORD_WIDTH-1]);
            else
                f_ovf = ~(a_r[cpu_pkg::WORD_WIDTH-1] ^ b_r[cpu_pkg::WORD_WIDTH-1]) &
                         (a_r[cpu_pkg::WORD_WIDTH-1] ^ final_r[cpu_pkg::WORD_WIDTH-1]);
        end else if (is_neg) begin
            f_carry = (a_r == '0);
            f_ovf   = (a_r == MSB_ONE);
        end else if (is_abs) begin
            f_ovf = (a_r == MSB_ONE);
        end else if (is_divop) begin
            f_dz = (b_r == '0);
            if (is_signed_div && (a_r == MSB_ONE) && (b_r == ALL_ONES))
                f_ovf = is_div;
        end
    end

    // ------------------------------------------------------------
    // Sequencer: every arithmetic op is cpu_pkg::WORD_WIDTH cycles
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= S_IDLE;
            cnt      <= '0;
            a_r      <= '0;
            b_r      <= '0;
            a_sr     <= '0;
            b_sr     <= '0;
            r_sr     <= '0;
            carry_ff <= 1'b0;
            macc     <= '0;
            mcand    <= '0;
            drem     <= '0;
            dquo     <= '0;
            result_r <= '0;
            carry_r  <= 1'b0;
            ovf_r    <= 1'b0;
            dz_r     <= 1'b0;
        end else begin
            case (state)

                S_IDLE: begin
                    if (start) begin
                        a_r      <= operand_a;
                        b_r      <= operand_b;
                        a_sr     <= ld_a_sr;
                        b_sr     <= ld_b_sr;
                        r_sr     <= '0;
                        carry_ff <= ld_carry_ff;
                        macc     <= '0;
                        mcand    <= {{cpu_pkg::WORD_WIDTH{1'b0}}, operand_a};
                        drem     <= '0;
                        dquo     <= '0;
                        cnt      <= '0;
                        state    <= S_RUN;
                    end
                end

                S_RUN: begin
                    a_sr     <= a_sr_nxt;
                    b_sr     <= b_sr_nxt;
                    r_sr     <= r_sr_nxt;
                    carry_ff <= cout_bit;

                    if (is_mul) begin
                        macc  <= macc_nxt;
                        mcand <= mcand_nxt;
                    end
                    if (is_divop) begin
                        drem <= drem_nxt;
                        dquo <= dquo_nxt;
                    end

                    if (cnt == cpu_pkg::WORD_WIDTH - 1) begin
                        result_r <= final_r;
                        carry_r  <= f_carry;
                        ovf_r    <= f_ovf;
                        dz_r     <= f_dz;
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
