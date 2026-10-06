`timescale 1ns/1ps

// ============================================================
// LACOODA branch unit — Stage 6
//
// Pure combinational control-flow unit. It compares the two source
// operands according to the condition selected by the cpu_decoder.
//
// If the condition is true and enable is asserted:
//      redirect = 1
//      redirect_target = target
//
// The program counter then loads redirect_target on the next rising
// clock edge. If redirect is 0, the existing program_counter advances
// normally by WORD_BYTES.
//
// Signed and unsigned comparisons are intentionally separate.
// ============================================================

module branch_unit (
    input  logic                       enable,
    input  opcode_pkg::opcode_t        opcode,
    input  cpu_pkg::word_t             operand_a,
    input  cpu_pkg::word_t             operand_b,
    input  cpu_pkg::word_t             target,

    output logic                       redirect,
    output cpu_pkg::word_t             redirect_target
);

    import opcode_pkg::*;

    always_comb begin
        // Safe defaults: no branch. The target is still forwarded so
        // it remains visible in simulation even when the branch is not
        // taken.
        redirect        = 1'b0;
        redirect_target = target;

        if (enable) begin
            case (opcode)
                CTRL_JMP:  redirect = 1'b1;
                CTRL_BEQ:  redirect = (operand_a == operand_b);
                CTRL_BNE:  redirect = (operand_a != operand_b);
                CTRL_BLT:  redirect = ($signed(operand_a) <  $signed(operand_b));
                CTRL_BGE:  redirect = ($signed(operand_a) >= $signed(operand_b));
                CTRL_BLTU: redirect = (operand_a <  operand_b);
                CTRL_BGEU: redirect = (operand_a >= operand_b);
                default:   redirect = 1'b0;
            endcase
        end
    end

endmodule
