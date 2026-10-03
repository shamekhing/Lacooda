`timescale 1ns/1ps
// ============================================================
// ALU comparison sub-unit
//
// Equality and ordered comparisons. Each produces a 1-bit boolean
// zero-extended to cpu_pkg::WORD_WIDTH bits (1 = true, 0 = false). The *_U
// variants compare unsigned; the *_S variants compare signed
// (two's complement).
// ============================================================

module comparator (
    input  cpu_pkg::word_t operand_a, operand_b,
    input  opcode_pkg::opcode_t op,

    output cpu_pkg::word_t result
);

    import opcode_pkg::*;

    always_comb begin
        result = '0;

        case (op)

            ALU_EQ:
                result = (operand_a == operand_b);

            ALU_NE:
                result = (operand_a != operand_b);

            // Unsigned comparisons
            ALU_LTU:
                result = (operand_a < operand_b);

            ALU_LEU:
                result = (operand_a <= operand_b);

            ALU_GTU:
                result = (operand_a > operand_b);

            ALU_GEU:
                result = (operand_a >= operand_b);

            // Signed comparisons
            ALU_LTS:
                result = ($signed(operand_a) < $signed(operand_b));

            ALU_LES:
                result = ($signed(operand_a) <= $signed(operand_b));

            ALU_GTS:
                result = ($signed(operand_a) > $signed(operand_b));

            ALU_GES:
                result = ($signed(operand_a) >= $signed(operand_b));

            default:
                result = '0;

        endcase
    end

endmodule
