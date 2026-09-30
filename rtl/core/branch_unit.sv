`timescale 1ns/1ps

// ============================================================
// LACOODA branch unit — Stage 6
//
// Pure combinational control-flow unit. It compares the two source
// operands according to the condition selected by the decoder.
//
// If the condition is true and enable is asserted:
//      redirect = 1
//      redirect_target = target
//
// The program counter then loads redirect_target on the next rising
// clock edge. If redirect is 0, the existing program_counter advances
// normally by INSTRUCTION_BYTES.
//
// Signed and unsigned comparisons are intentionally separate.
// ============================================================

module branch_unit (
    input  logic                       enable,
    input  cpu_pkg::branch_condition_t condition,
    input  cpu_pkg::data_t             lhs,
    input  cpu_pkg::data_t             rhs,
    input  cpu_pkg::data_t             target,

    output logic                       redirect,
    output cpu_pkg::data_t             redirect_target
);

    import cpu_pkg::*;

    always_comb begin
        // Safe defaults: no branch. The target is still forwarded so
        // it remains visible in simulation even when the branch is not
        // taken.
        redirect        = 1'b0;
        redirect_target = target;

        if (enable) begin
            case (condition)
                BR_ALWAYS: redirect = 1'b1;
                BR_EQ:     redirect = (lhs == rhs);
                BR_NE:     redirect = (lhs != rhs);
                BR_LT:     redirect = ($signed(lhs) <  $signed(rhs));
                BR_GE:     redirect = ($signed(lhs) >= $signed(rhs));
                BR_LTU:    redirect = (lhs <  rhs);
                BR_GEU:    redirect = (lhs >= rhs);
                default:   redirect = 1'b0;
            endcase
        end
    end

endmodule
