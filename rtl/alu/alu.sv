
module alu #(
    parameter int WIDTH = 64
)(
    input  logic [WIDTH-1:0] A, B,
    input  logic [5:0] op,
    input  logic carry_in,

    output logic [WIDTH-1:0] result,
    output flags_pkg::flags_t flags,
    output logic valid
);

    import opcode_pkg::*;

    logic [WIDTH-1:0] arithmetic_result;
    logic [WIDTH-1:0] logic_result;
    logic [WIDTH-1:0] shift_result;
    logic [WIDTH-1:0] compare_result;

    logic arithmetic_carry;
    logic arithmetic_overflow;
    logic arithmetic_div_zero;

    logic carry_internal;
    logic overflow_internal;
    logic div_zero_internal;

    arithmetic #(.WIDTH(WIDTH)) u_arithmetic (
        .A(A),
        .B(B),
        .op(op),
        .carry_in(carry_in),
        .result(arithmetic_result),
        .carry(arithmetic_carry),
        .overflow(arithmetic_overflow),
        .div_zero(arithmetic_div_zero)
    );

    logic_unit #(.WIDTH(WIDTH)) u_logic (
        .A(A),
        .B(B),
        .op(op),
        .result(logic_result)
    );

    shifter #(.WIDTH(WIDTH)) u_shifter (
        .A(A),
        .B(B),
        .op(op),
        .result(shift_result)
    );

    comparator #(.WIDTH(WIDTH)) u_comparator (
        .A(A),
        .B(B),
        .op(op),
        .result(compare_result)
    );

    always_comb begin

        result = '0;
        valid  = 1'b1;

        carry_internal    = 1'b0;
        overflow_internal = 1'b0;
        div_zero_internal = 1'b0;

        case (op)

            ALU_ADD, ALU_ADC,
            ALU_SUB, ALU_SBC,
            ALU_MUL, ALU_MULH,
            ALU_DIVU, ALU_MODU,
            ALU_DIVS, ALU_MODS,
            ALU_NEG, ALU_ABS,
            ALU_MINU, ALU_MAXU,
            ALU_MINS, ALU_MAXS: begin

                result = arithmetic_result;

                carry_internal    = arithmetic_carry;
                overflow_internal = arithmetic_overflow;
                div_zero_internal = arithmetic_div_zero;
            end

            ALU_AND, ALU_OR, ALU_XOR,
            ALU_NOT, ALU_NAND, ALU_NOR,
            ALU_XNOR, ALU_PASS_A, ALU_PASS_B: begin

                result = logic_result;
            end

            ALU_SHL, ALU_SHR, ALU_SAR,
            ALU_ROL, ALU_ROR: begin

                result = shift_result;
            end

            ALU_EQ, ALU_NE,
            ALU_LTU, ALU_LEU,
            ALU_GTU, ALU_GEU,
            ALU_LTS, ALU_LES,
            ALU_GTS, ALU_GES: begin

                result = compare_result;
            end

            default: begin
                result = '0;
                valid  = 1'b0;
            end

        endcase
    end

    always_comb begin
        flags = '0;

        if (valid) begin
            flags.Z  = (result == '0);
            flags.N  = result[WIDTH-1];
            flags.C  = carry_internal;
            flags.V  = overflow_internal;
            flags.DZ = div_zero_internal;
        end
    end

endmodule
