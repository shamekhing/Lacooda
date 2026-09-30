`timescale 1ns/1ps

// ============================================================
// LACOODA CPU core — Stage 7 integration
//
// Stage 6 added control flow.
// Stage 7 adds LOAD/STORE and exposes a simple fixed-latency data
// memory interface to cpu_system.
//
// This is intentionally NOT the later valid/ready system bus. Stage 7
// assumes a combinational memory read and a synchronous memory write.
// ============================================================

module cpu_core (
    input  logic clk,
    input  logic rst,

    input  logic instruction_enable,
    input  cpu_pkg::instruction_t instruction,

    // Kept external to preserve the existing datapath interface.
    input  logic carry_in,

    // Stage 7 data-memory response.
    input  cpu_pkg::data_t memory_read_data,

    output logic instruction_valid,
    output logic illegal_instruction,
    output logic execution_valid,

    // Stage 6 control-flow result returned to cpu_system/fetch.
    output logic redirect,
    output cpu_pkg::data_t redirect_target,

    // Stage 7 data-memory request.
    output logic memory_read_enable,
    output logic memory_write_enable,
    output cpu_pkg::data_t memory_address,
    output cpu_pkg::data_t memory_write_data,

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

    // Stage 7 decoded memory controls.
    logic decoded_memory_read_enable;
    logic decoded_memory_write_enable;
    cpu_pkg::data_t store_data;

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

        .memory_read_enable(decoded_memory_read_enable),
        .memory_write_enable(decoded_memory_write_enable),

        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction)
    );

    // --------------------------------------------------------
    // EXECUTION ENABLES
    // --------------------------------------------------------
    assign effective_register_write =
        instruction_enable &&
        instruction_valid &&
        register_write_enable;

    assign effective_flags_write =
        instruction_enable &&
        instruction_valid &&
        flags_write_enable;

    // Memory side effects are gated exactly like architectural writes.
    assign memory_read_enable =
        instruction_enable &&
        instruction_valid &&
        decoded_memory_read_enable &&
        !rst;

    assign memory_write_enable =
        instruction_enable &&
        instruction_valid &&
        decoded_memory_write_enable &&
        !rst;

    // --------------------------------------------------------
    // DATAPATH
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

        .memory_read_data(memory_read_data),
        .writeback_from_memory(memory_read_enable),

        .operand_a(operand_a),
        .operand_b(operand_b),
        .store_data(store_data),
        .result(result),
        .valid(alu_valid),

        .alu_flags(alu_flags),
        .status_flags(status_flags)
    );

    // For LOAD/STORE the ALU result is the effective byte address.
    assign memory_address = result;
    assign memory_write_data = store_data;

    // --------------------------------------------------------
    // STAGE 6 BRANCH UNIT
    // --------------------------------------------------------
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

    // Branches do not require an ALU result. ALU and memory instructions
    // use a valid ALU operation; LOAD/STORE use ALU_ADD for addressing.
    assign execution_valid =
        instruction_enable &&
        instruction_valid &&
        !rst &&
        (branch_enable || alu_valid);

endmodule
