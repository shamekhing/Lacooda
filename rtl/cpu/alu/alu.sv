`timescale 1ns/1ps
// ============================================================
// ALU top level
//
// Combinational ALU. All four functional sub-units evaluate in
// parallel and the result multiplexer selects the one named by
// `op`. Status flags are then derived centrally from the selected
// result plus the arithmetic sub-unit's carry/overflow/div-zero.
//
// Ports:
//   A, B     : WIDTH-bit operands (B is also the shift amount)
//   op       : opcode_pkg::opcode_t, valid ALU encodings are 0x00..0x27
//   carry_in : carry/borrow input for ADC / SBC
//   result   : selected WIDTH-bit result
//   flags    : alu_pkg::flags_t (Z/N/C/V/DZ)
//   valid    : low for an unrecognised opcode, high otherwise
//
// An unrecognised opcode forces result = 0 and flags = 0 so that
// downstream write enables (gated by `valid`) stay inactive.
// ============================================================

module alu #(
    parameter int WIDTH = cpu_pkg::REG_FILE_WIDTH
)(
    input  logic [WIDTH-1:0] A, B,
    input  opcode_pkg::opcode_t op,
    input  logic carry_in,

    output logic [WIDTH-1:0] result,
    output alu_pkg::flags_t flags,
    output logic valid
);

    import alu_pkg::*;
    import opcode_pkg::*;

    // Result produced by each functional sub-unit.
    logic [WIDTH-1:0] arithmetic_result;
    logic [WIDTH-1:0] logic_result;
    logic [WIDTH-1:0] shift_result;
    logic [WIDTH-1:0] compare_result;

    // Arithmetic-only side-channel status.
    logic arithmetic_carry;
    logic arithmetic_overflow;
    logic arithmetic_div_zero;

    // Status selected alongside the active result (C / V / DZ).
    logic carry_internal;
    logic overflow_internal;
    logic div_zero_internal;

    // Arithmetic: ADD/ADC/SUB/SBC/MUL/MULH/DIV/MOD/NEG/ABS/MIN/MAX.
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

    // Bitwise logic: AND/OR/XOR/NOT/NAND/NOR/XNOR/PASS_A/PASS_B.
    logic_unit #(.WIDTH(WIDTH)) u_logic_unit (
        .A(A),
        .B(B),
        .op(op),
        .result(logic_result)
    );

    // Shifts and rotations: SHL/SHR/SAR/ROL/ROR.
    shifter #(.WIDTH(WIDTH)) u_shifter (
        .A(A),
        .B(B),
        .op(op),
        .result(shift_result)
    );

    // Comparisons: EQ/NE/LT/LE/GT/GE (signed and unsigned).
    comparator #(.WIDTH(WIDTH)) u_comparator (
        .A(A),
        .B(B),
        .op(op),
        .result(compare_result)
    );

    // Result multiplexer and validity check.
    always_comb begin

        // Defaults: zero result, opcode assumed valid.
        result = '0;
        valid  = 1'b1;

        carry_internal    = 1'b0;
        overflow_internal = 1'b0;
        div_zero_internal = 1'b0;

        case (op)

            // Arithmetic group.
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

            // Bitwise-logic group.
            ALU_AND, ALU_OR, ALU_XOR,
            ALU_NOT, ALU_NAND, ALU_NOR,
            ALU_XNOR, ALU_PASS_A, ALU_PASS_B: begin

                result = logic_result;
            end

            // Shift / rotate group.
            ALU_SHL, ALU_SHR, ALU_SAR,
            ALU_ROL, ALU_ROR: begin

                result = shift_result;
            end

            // Comparison group.
            ALU_EQ, ALU_NE,
            ALU_LTU, ALU_LEU,
            ALU_GTU, ALU_GEU,
            ALU_LTS, ALU_LES,
            ALU_GTS, ALU_GES: begin

                result = compare_result;
            end

            // Unrecognised encoding: null the result, flag invalid.
            default: begin
                result = '0;
                valid  = 1'b0;
            end

        endcase
    end

    // Flags describe whichever result the multiplexer selected.
    always_comb begin
        // An invalid opcode leaves every flag cleared.
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
