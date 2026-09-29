
module logic_unit #(
    parameter int WIDTH = 64
)(
    input  logic [WIDTH-1:0] A, B,
    input  logic [5:0] op,

    output logic [WIDTH-1:0] result
);

    import opcode_pkg::*;

    always_comb begin
        result = '0;

        case (op)
            ALU_AND:    result = A & B;
            ALU_OR:     result = A | B;
            ALU_XOR:    result = A ^ B;
            ALU_NOT:    result = ~A;
            ALU_NAND:   result = ~(A & B);
            ALU_NOR:    result = ~(A | B);
            ALU_XNOR:   result = ~(A ^ B);
            ALU_PASS_A: result = A;
            ALU_PASS_B: result = B;

            default: result = '0;
        endcase
    end

endmodule
