`timescale 1ns/1ps
// ============================================================
// ALU bitwise-logic sub-unit
//
// Pure bitwise operations (no flags): AND/OR/XOR/NOT/NAND/NOR/
// XNOR, plus the two operand pass-throughs used to implement
// MOV (PASS_A) and MOVI (PASS_B).
// ============================================================

module logic_unit (
    input  cpu_pkg::word_t operand_a, operand_b,
    input  opcode_pkg::opcode_t op,

    output cpu_pkg::word_t result
);

    import opcode_pkg::*;

    always_comb begin
        result = '0;

        case (op)
            ALU_AND:    result = operand_a & operand_b;
            ALU_OR:     result = operand_a | operand_b;
            ALU_XOR:    result = operand_a ^ operand_b;
            ALU_NOT:    result = ~operand_a;
            ALU_NAND:   result = ~(operand_a & operand_b);
            ALU_NOR:    result = ~(operand_a | operand_b);
            ALU_XNOR:   result = ~(operand_a ^ operand_b);
            ALU_PASS_A: result = operand_a;
            ALU_PASS_B: result = operand_b;

            default: result = '0;
        endcase
    end

endmodule
