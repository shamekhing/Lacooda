`timescale 1ns/1ps
// ============================================================
// ALU shift / rotate sub-unit
//
// SHL, SHR, arithmetic right shift (SAR) and the ROL/ROR
// rotations. The rotate shift_amount is reduced modulo cpu_pkg::WORD_WIDTH, including
// byte-scaled widths that are not powers of two.
// ============================================================

module shifter (
    input  cpu_pkg::word_t operand_a, operand_b,
    input  opcode_pkg::opcode_t op,

    output cpu_pkg::word_t result
);

    import opcode_pkg::*;

    localparam int SHIFT_WIDTH = $clog2(cpu_pkg::WORD_WIDTH);

    logic [SHIFT_WIDTH-1:0] shift_amount;

    // Rotations use the full shift operand modulo cpu_pkg::WORD_WIDTH.
    assign shift_amount = SHIFT_WIDTH'(operand_b % cpu_pkg::WORD_WIDTH);

    always_comb begin
        result = '0;

        case (op)

            ALU_SHL:
                result = operand_a << operand_b;

            ALU_SHR:
                result = operand_a >> operand_b;

            ALU_SAR:
                result = $signed(operand_a) >>> operand_b;

            ALU_ROL:
                result = (operand_a << shift_amount) |
                         (operand_a >> (cpu_pkg::WORD_WIDTH - shift_amount));

            ALU_ROR:
                result = (operand_a >> shift_amount) |
                         (operand_a << (cpu_pkg::WORD_WIDTH - shift_amount));

            default:
                result = '0;

        endcase
    end

endmodule
