`timescale 1ns/1ps
// ============================================================
// Datapath — Stage 7
//
// Wires the register file, operand-B multiplexer, ALU, LOAD
// writeback multiplexer and status register together.
//
// Normal ALU instruction:
//   register(s) -> ALU -> register writeback
//
// LOAD:
//   RS1 + signed immediate -> effective address
//   memory_read_data       -> RD writeback
//
// STORE:
//   RS1 + signed immediate -> effective address
//   raw RS2 value          -> store_data
//
// The raw second register-file output is kept separate from operand_b
// because STORE needs RS2 as write data while the ALU simultaneously
// needs the immediate offset as operand B.
// ============================================================

module datapath #(
    parameter int REG_FILE_WIDTH = cpu_pkg::REG_FILE_WIDTH,
    parameter int REG_FILE_ADDR_WIDTH = cpu_pkg::REG_FILE_ADDR_WIDTH
) (
    input logic clk,
    input logic rst,

    // Register addresses
    input logic [REG_FILE_ADDR_WIDTH-1:0] rs1,
    input logic [REG_FILE_ADDR_WIDTH-1:0] rs2,
    input logic [REG_FILE_ADDR_WIDTH-1:0] rd,

    // ALU control
    input opcode_pkg::opcode_t alu_op,
    input logic carry_in,

    // Immediate operand
    input logic [REG_FILE_WIDTH-1:0] immediate,
    input logic use_immediate,

    // Write controls
    input logic register_write_enable,
    input logic flags_write_enable,

    // Stage 7 LOAD writeback input/control
    input cpu_pkg::data_memory_t memory_read_data,
    input logic writeback_from_memory,

    // Datapath outputs
    output logic [REG_FILE_WIDTH-1:0] operand_a,
    output logic [REG_FILE_WIDTH-1:0] operand_b,
    output logic [REG_FILE_WIDTH-1:0] store_data,
    output logic [REG_FILE_WIDTH-1:0] result,
    output logic valid,

    // Flags
    output alu_pkg::flags_t alu_flags,
    output alu_pkg::flags_t status_flags
);

    logic [REG_FILE_WIDTH-1:0] register_b;
    cpu_pkg::reg_t writeback_data;

    logic register_write;
    logic flags_write;

    // =========================================================
    // WRITE ENABLE CONTROL
    // =========================================================

    assign register_write =
        register_write_enable && valid && !rst;

    assign flags_write =
        flags_write_enable && valid && !rst;

    // =========================================================
    // REGISTER FILE
    // =========================================================

    register_file #(
        .REG_FILE_WIDTH(REG_FILE_WIDTH),
        .REG_FILE_ADDR_WIDTH(REG_FILE_ADDR_WIDTH)
    ) u_register_file (
        .clk(clk),
        .rst(rst),

        .read_addr_a(rs1),
        .read_data_a(operand_a),

        .read_addr_b(rs2),
        .read_data_b(register_b),

        .write_enable(register_write),
        .write_addr(rd),
        .write_data(writeback_data)
    );

    // STORE always needs the unmodified value read from RS2.
    assign store_data = register_b;

    // =========================================================
    // OPERAND B MULTIPLEXER
    // =========================================================

    assign operand_b =
        use_immediate ? immediate : register_b;

    // =========================================================
    // ALU
    // =========================================================

    alu #(
        .WIDTH(REG_FILE_WIDTH)
    ) u_alu (
        .A(operand_a),
        .B(operand_b),

        .op(alu_op),
        .carry_in(carry_in),

        .result(result),
        .flags(alu_flags),
        .valid(valid)
    );

    // =========================================================
    // WRITEBACK MULTIPLEXER
    // =========================================================
    // Normal ALU instructions write the ALU result. LOAD writes the
    // combinational data-memory read value instead. The effective
    // address remains visible on result for LOAD/STORE.
    assign writeback_data =
        writeback_from_memory ? memory_read_data : result;

    // =========================================================
    // STATUS REGISTER
    // =========================================================

    status_register u_status_register (
        .clk(clk),
        .rst(rst),

        .write_enable(flags_write),
        .flags_in(alu_flags),
        .flags_out(status_flags)
    );

endmodule
