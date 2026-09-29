`timescale 1ns/1ps
module comparator #(
    parameter int WIDTH = cpu_pkg::DATA_WIDTH
)(
    input  logic [WIDTH-1:0] A, B,
    input  alu_pkg::opcode_t op,

    output logic [WIDTH-1:0] result
);

    import alu_pkg::*;

    always_comb begin
        result = '0;

        case (op)

            ALU_EQ:
                result = (A == B);

            ALU_NE:
                result = (A != B);

            // Unsigned comparisons
            ALU_LTU:
                result = (A < B);

            ALU_LEU:
                result = (A <= B);

            ALU_GTU:
                result = (A > B);

            ALU_GEU:
                result = (A >= B);

            // Signed comparisons
            ALU_LTS:
                result = ($signed(A) < $signed(B));

            ALU_LES:
                result = ($signed(A) <= $signed(B));

            ALU_GTS:
                result = ($signed(A) > $signed(B));

            ALU_GES:
                result = ($signed(A) >= $signed(B));

            default:
                result = '0;

        endcase
    end

endmodule
