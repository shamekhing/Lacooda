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
//              representable in cpu_pkg::WORD_WIDTH bits
//   div_zero : asserted whenever the divisor operand_b is zero
//
// The signed MIN/-1 division and modulo cases are special-cased to
// avoid the implementation-defined overflow of signed division.
// ============================================================

module arithmetic (
    input  cpu_pkg::word_t operand_a, operand_b,
    input  opcode_pkg::opcode_t op,
    input  logic carry_in,

    output cpu_pkg::word_t result,
    output logic carry,
    output logic overflow,
    output logic div_zero
);

    import opcode_pkg::*;

    // One extra bit preserves carry/borrow; a double-width product supports MULH.
    logic [cpu_pkg::WORD_WIDTH:0] add_ext;
    logic [2*cpu_pkg::WORD_WIDTH-1:0] product;

    logic signed [cpu_pkg::WORD_WIDTH-1:0] signed_a;
    logic signed [cpu_pkg::WORD_WIDTH-1:0] signed_b;

    cpu_pkg::word_t min_signed;

    cpu_pkg::word_t rhs;

    assign signed_a = $signed(operand_a);
    assign signed_b = $signed(operand_b);

    assign min_signed = {1'b1, {(cpu_pkg::WORD_WIDTH-1){1'b0}}};

    always_comb begin
        result   = '0;
        carry    = 1'b0;
        overflow = 1'b0;
        div_zero = 1'b0;

        add_ext    = '0;
        product = '0;
        rhs     = '0;

        case (op)

            ALU_ADD, ALU_ADC: begin
                add_ext = {1'b0, operand_a} + {1'b0, operand_b}
                     + ((op == ALU_ADC) ? carry_in : 1'b0);

                result = add_ext[cpu_pkg::WORD_WIDTH-1:0];
                carry  = add_ext[cpu_pkg::WORD_WIDTH];

                overflow =
                    (~(operand_a[cpu_pkg::WORD_WIDTH-1] ^ operand_b[cpu_pkg::WORD_WIDTH-1])) &
                    (operand_a[cpu_pkg::WORD_WIDTH-1] ^ result[cpu_pkg::WORD_WIDTH-1]);
            end

            ALU_SUB, ALU_SBC: begin
                // C means no borrow: SBC subtracts an extra one when carry_in is zero.
                rhs = operand_b + ((op == ALU_SBC) ? !carry_in : 1'b0);

                add_ext = {1'b0, operand_a} - {1'b0, operand_b}
                     - ((op == ALU_SBC) ? !carry_in : 1'b0);

                result = add_ext[cpu_pkg::WORD_WIDTH-1:0];

                // No unsigned borrow
                carry = ~add_ext[cpu_pkg::WORD_WIDTH];

                overflow =
                    (operand_a[cpu_pkg::WORD_WIDTH-1] ^ operand_b[cpu_pkg::WORD_WIDTH-1]) &
                    (operand_a[cpu_pkg::WORD_WIDTH-1] ^ result[cpu_pkg::WORD_WIDTH-1]);
            end

            ALU_MUL: begin
                product = operand_a * operand_b;
                result  = product[cpu_pkg::WORD_WIDTH-1:0];
            end

            ALU_MULH: begin
                product = operand_a * operand_b;
                result  = product[2*cpu_pkg::WORD_WIDTH-1:cpu_pkg::WORD_WIDTH];
            end

            // Division/modulo by zero leave the default result of zero and raise DZ.
            ALU_DIVU: begin
                if (operand_b == '0)
                    div_zero = 1'b1;
                else
                    result = operand_a / operand_b;
            end

            ALU_MODU: begin
                if (operand_b == '0)
                    div_zero = 1'b1;
                else
                    result = operand_a % operand_b;
            end

            ALU_DIVS: begin
                if (operand_b == '0) begin
                    div_zero = 1'b1;
                end else if (
                    operand_a == min_signed &&
                    operand_b == {cpu_pkg::WORD_WIDTH{1'b1}}
                ) begin
                    result   = min_signed;
                    overflow = 1'b1;
                end else begin
                    result = signed_a / signed_b;
                end
            end

            ALU_MODS: begin
                if (operand_b == '0) begin
                    div_zero = 1'b1;
                end else if (
                    operand_a == min_signed &&
                    operand_b == {cpu_pkg::WORD_WIDTH{1'b1}}
                ) begin
                    result = '0;
                end else begin
                    result = signed_a % signed_b;
                end
            end

            // The most-negative signed value has no positive cpu_pkg::WORD_WIDTH-bit counterpart.
            // NEG and ABS retain that bit pattern and report signed overflow.
            ALU_NEG: begin
                result = -operand_a;
                carry  = (operand_a == '0);
                overflow = (operand_a == min_signed);
            end

            ALU_ABS: begin
                result = operand_a[cpu_pkg::WORD_WIDTH-1] ? -operand_a : operand_a;
                overflow = (operand_a == min_signed);
            end

            ALU_MINU: result = (operand_a < operand_b) ? operand_a : operand_b;
            ALU_MAXU: result = (operand_a > operand_b) ? operand_a : operand_b;

            ALU_MINS:
                result = (signed_a < signed_b) ? operand_a : operand_b;

            ALU_MAXS:
                result = (signed_a > signed_b) ? operand_a : operand_b;

            default: result = '0;

        endcase
    end

endmodule
