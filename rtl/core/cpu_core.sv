
`timescale 1ns/1ps

// ============================================================
// LACOODA CPU core — Stage 4 integration
//
// Connects the existing decoder to the existing datapath.
//
// An instruction executes on a rising clock edge when:
//   instruction_enable && instruction_valid && alu_valid
//
// No PC, instruction memory, or pipeline is implemented here.
// ============================================================

module cpu_core (
    input  logic clk,
    input  logic rst,

    input  logic instruction_enable,
    input  cpu_pkg::instruction_t instruction,

    // Kept external to preserve the existing datapath interface.
    input  logic carry_in,

    output logic instruction_valid,
    output logic illegal_instruction,
    output logic execution_valid,

    output cpu_pkg::data_t operand_a,
    output cpu_pkg::data_t operand_b,
    output cpu_pkg::data_t result,

    output alu_pkg::flags_t alu_flags,
    output alu_pkg::flags_t status_flags
);

    cpu_pkg::reg_addr_t rs1;
    cpu_pkg::reg_addr_t rs2;
    cpu_pkg::reg_addr_t rd;

    alu_pkg::opcode_t alu_op;

    cpu_pkg::data_t immediate;

    logic use_immediate;
    logic register_write_enable;
    logic flags_write_enable;
    logic alu_valid;

    logic effective_register_write;
    logic effective_flags_write;

    // --------------------------------------------------------
    // INSTRUCTION DECODER
    // --------------------------------------------------------

    decoder u_decoder (
        .instruction(instruction),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .alu_op(alu_op),
        .immediate(immediate),
        .use_immediate(use_immediate),

        .register_write_enable(register_write_enable),
        .flags_write_enable(flags_write_enable),

        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction)
    );

    // --------------------------------------------------------
    // EXECUTION ENABLE
    // --------------------------------------------------------

    assign effective_register_write =
        instruction_enable &&
        instruction_valid &&
        register_write_enable;

    assign effective_flags_write =
        instruction_enable &&
        instruction_valid &&
        flags_write_enable;

    // --------------------------------------------------------
    // EXISTING DATAPATH
    // --------------------------------------------------------

    datapath u_datapath (
        .clk(clk),
        .rst(rst),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .alu_op(alu_op),
        .carry_in(carry_in),

        .immediate(immediate),
        .use_immediate(use_immediate),

        .register_write_enable(effective_register_write),
        .flags_write_enable(effective_flags_write),

        .operand_a(operand_a),
        .operand_b(operand_b),
        .result(result),
        .valid(alu_valid),

        .alu_flags(alu_flags),
        .status_flags(status_flags)
    );

    // Valid combinational execution. Architectural state changes
    // only on a rising clock edge.
    assign execution_valid =
        instruction_enable &&
        instruction_valid &&
        alu_valid &&
        !rst;

endmodule
