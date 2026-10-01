`timescale 1ns/1ps
// ============================================================
// ALU shift / rotate sub-unit
//
// SHL, SHR, arithmetic right shift (SAR) and the ROL/ROR
// rotations. The rotate amount is reduced modulo WIDTH, including
// byte-scaled widths that are not powers of two.
// ============================================================

module shifter #(
    parameter int WIDTH = cpu_pkg::REG_FILE_WIDTH
)(
    input  logic [WIDTH-1:0] A, B,
    input  opcode_pkg::opcode_t op,

    output logic [WIDTH-1:0] result
);

    import opcode_pkg::*;

    localparam int SHIFT_BITS = $clog2(WIDTH);

    logic [SHIFT_BITS-1:0] amount;

    // Rotations use the full shift operand modulo WIDTH.
    assign amount = SHIFT_BITS'(B % WIDTH);

    always_comb begin
        result = '0;

        case (op)

            ALU_SHL:
                result = A << B;

            ALU_SHR:
                result = A >> B;

            ALU_SAR:
                result = $signed(A) >>> B;

            ALU_ROL:
                result = (A << amount) |
                         (A >> (WIDTH - amount));

            ALU_ROR:
                result = (A >> amount) |
                         (A << (WIDTH - amount));

            default:
                result = '0;

        endcase
    end

endmodule
