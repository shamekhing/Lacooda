`timescale 1ns/1ps
// ============================================================
// ALU arithmetic sub-unit
//
// Handles ADD/ADC/SUB/SBC, MUL/MULH, unsigned and signed
// DIV/MOD, NEG, ABS and the signed/unsigned MIN/MAX operations.
//
// Side-channel status:
//   carry    : unsigned carry out (ADD) / no-borrow (SUB)
//   overflow : signed overflow; set when the true result is not
//              representable in WIDTH bits
//   div_zero : asserted whenever the divisor B is zero
//
// The signed MIN/-1 division and modulo cases are special-cased to
// avoid the implementation-defined overflow of signed division.
// ============================================================

module arithmetic #(
    parameter int WIDTH = cpu_pkg::DATA_WIDTH
)(
    input  logic [WIDTH-1:0] A, B,
    input  alu_pkg::opcode_t op,
    input  logic carry_in,

    output logic [WIDTH-1:0] result,
    output logic carry,
    output logic overflow,
    output logic div_zero
);

    import alu_pkg::*;

    logic [WIDTH:0] temp;
    logic [2*WIDTH-1:0] product;

    logic signed [WIDTH-1:0] signed_a;
    logic signed [WIDTH-1:0] signed_b;

    logic [WIDTH-1:0] min_signed;

    logic [WIDTH-1:0] rhs;

    assign signed_a = $signed(A);
    assign signed_b = $signed(B);

    assign min_signed = {1'b1, {(WIDTH-1){1'b0}}};

    always_comb begin
        result   = '0;
        carry    = 1'b0;
        overflow = 1'b0;
        div_zero = 1'b0;

        temp    = '0;
        product = '0;
        rhs     = '0;

        case (op)

            ALU_ADD, ALU_ADC: begin
                temp = {1'b0, A} + {1'b0, B}
                     + ((op == ALU_ADC) ? carry_in : 1'b0);

                result = temp[WIDTH-1:0];
                carry  = temp[WIDTH];

                overflow =
                    (~(A[WIDTH-1] ^ B[WIDTH-1])) &
                    (A[WIDTH-1] ^ result[WIDTH-1]);
            end

            ALU_SUB, ALU_SBC: begin
                rhs = B + ((op == ALU_SBC) ? !carry_in : 1'b0);

                temp = {1'b0, A} - {1'b0, B}
                     - ((op == ALU_SBC) ? !carry_in : 1'b0);

                result = temp[WIDTH-1:0];

                // No unsigned borrow
                carry = ~temp[WIDTH];

                overflow =
                    (A[WIDTH-1] ^ B[WIDTH-1]) &
                    (A[WIDTH-1] ^ result[WIDTH-1]);
            end

            ALU_MUL: begin
                product = A * B;
                result  = product[WIDTH-1:0];
            end

            ALU_MULH: begin
                product = A * B;
                result  = product[2*WIDTH-1:WIDTH];
            end

            ALU_DIVU: begin
                if (B == '0)
                    div_zero = 1'b1;
                else
                    result = A / B;
            end

            ALU_MODU: begin
                if (B == '0)
                    div_zero = 1'b1;
                else
                    result = A % B;
            end

            ALU_DIVS: begin
                if (B == '0) begin
                    div_zero = 1'b1;
                end else if (
                    A == min_signed &&
                    B == {WIDTH{1'b1}}
                ) begin
                    result   = min_signed;
                    overflow = 1'b1;
                end else begin
                    result = signed_a / signed_b;
                end
            end

            ALU_MODS: begin
                if (B == '0) begin
                    div_zero = 1'b1;
                end else if (
                    A == min_signed &&
                    B == {WIDTH{1'b1}}
                ) begin
                    result = '0;
                end else begin
                    result = signed_a % signed_b;
                end
            end

            ALU_NEG: begin
                result = -A;
                carry  = (A == '0);
                overflow = (A == min_signed);
            end

            ALU_ABS: begin
                result = A[WIDTH-1] ? -A : A;
                overflow = (A == min_signed);
            end

            ALU_MINU: result = (A < B) ? A : B;
            ALU_MAXU: result = (A > B) ? A : B;

            ALU_MINS:
                result = (signed_a < signed_b) ? A : B;

            ALU_MAXS:
                result = (signed_a > signed_b) ? A : B;

            default: result = '0;

        endcase
    end

endmodule
