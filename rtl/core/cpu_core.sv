`timescale 1ns/1ps

// ============================================================
// LACOODA CPU core — Stage 6 integration
//
// Stage 4 connected decoder + datapath.
// Stage 6 adds the branch unit and exports redirect/redirect_target
// to the system-level program counter.
//
// ALU instruction:
//   decoder -> datapath/ALU -> optional register/status write
//
// Branch instruction:
//   decoder -> register-file operands -> branch unit -> PC redirect
//
// Architectural state changes still occur only on rising clock edges.
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

    // Stage 6 control-flow result returned to cpu_system/fetch.
    output logic redirect,
    output cpu_pkg::data_t redirect_target,

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

    // Stage 6 decoded branch controls.
    logic branch_enable;
    cpu_pkg::branch_condition_t branch_condition;
    cpu_pkg::data_t branch_target;

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

        .branch_enable(branch_enable),
        .branch_condition(branch_condition),
        .branch_target(branch_target),

        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction)
    );

    // --------------------------------------------------------
    // EXECUTION ENABLES
    // --------------------------------------------------------
    // Invalid/disabled instructions are prevented from modifying
    // architectural register or status state.
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
    // The datapath remains active combinationally for branches too.
    // That is useful because operand_a and operand_b expose the values
    // read from RS1/RS2. Branch instructions have write enables = 0,
    // so the ALU result cannot alter architectural state.
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

    // --------------------------------------------------------
    // STAGE 6 BRANCH UNIT
    // --------------------------------------------------------
    // A valid enabled branch may request a redirect. The branch unit
    // itself is combinational; program_counter commits the new PC on
    // the rising edge.
    branch_unit u_branch (
        .enable(
            instruction_enable &&
            instruction_valid &&
            branch_enable &&
            !rst
        ),
        .condition(branch_condition),
        .lhs(operand_a),
        .rhs(operand_b),
        .target(branch_target),
        .redirect(redirect),
        .redirect_target(redirect_target)
    );

    // An enabled valid branch is a valid execution even though it is
    // not an ALU operation. Normal ALU instructions still require the
    // ALU to report valid.
    assign execution_valid =
        instruction_enable &&
        instruction_valid &&
        !rst &&
        (branch_enable || alu_valid);

endmodule
