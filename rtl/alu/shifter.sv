`timescale 1ns/1ps
// ============================================================
// ALU shift / rotate sub-unit
//
// SHL, SHR, arithmetic right shift (SAR) and the ROL/ROR
// rotations. The rotate amount is reduced modulo WIDTH, which the
// "shift by WIDTH - amount" trick below relies on; WIDTH must be a
// power of two (the default 64 satisfies this).
// ============================================================

module shifter #(
    parameter int WIDTH = cpu_pkg::DATA_WIDTH
)(
    input  logic [WIDTH-1:0] A, B,
    input  alu_pkg::opcode_t op,

    output logic [WIDTH-1:0] result
);

    import alu_pkg::*;

    localparam int SHIFT_BITS = $clog2(WIDTH);

    logic [SHIFT_BITS-1:0] amount;

    // Rotations use the shift amount modulo WIDTH.
    // WIDTH must be a power of two.
    assign amount = B[SHIFT_BITS-1:0];

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
