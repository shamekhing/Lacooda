`timescale 1ns/1ps
// ============================================================
// cpu_datapath — Stage 7
//
// Wires the register file, operand-B multiplexer, ALU, LOAD
// writeback multiplexer and status register together. Every word
// is the global word (cpu_pkg::WORD_WIDTH).
//
// Normal ALU instruction:
//   register(s) -> ALU -> register writeback
//
// LOAD:
//   RS1 + imm_operand word   -> effective address
//   dmem_rdata       -> RD writeback
//
// STORE:
//   RS1 + imm_operand word   -> effective address
//   raw RS2 value          -> store_data
//
// The raw second register-file output is kept separate from operand_b
// because STORE needs RS2 as write data while the ALU simultaneously
// needs the imm_operand as operand B.
// ============================================================

module cpu_datapath (
    input logic clk,
    input logic rst,

    // Register addresses
    input cpu_pkg::reg_addr_t rs1,
    input cpu_pkg::reg_addr_t rs2,
    input cpu_pkg::reg_addr_t rd,

    // ALU control
    input opcode_pkg::opcode_t alu_op,
    input logic carry_in,
    input logic alu_start,

    // Immediate operand (the word that followed the instruction)
    input cpu_pkg::word_t imm_operand,
    input logic imm_sel,

    // Write controls
    input logic register_write_enable,
    input logic flags_write_enable,

    // LOAD writeback input/control
    input cpu_pkg::word_t dmem_rdata,
    input logic writeback_from_mem,

    // cpu_datapath outputs
    output cpu_pkg::word_t operand_a,
    output cpu_pkg::word_t operand_b,
    output cpu_pkg::word_t store_data,
    output cpu_pkg::word_t alu_result,
    output logic alu_valid,
    output logic alu_busy,
    output logic alu_done,

    // Flags
    output cpu_pkg::flags_s flags,
    output cpu_pkg::status_t status
);
    cpu_pkg::word_t rs2_data;
    cpu_pkg::word_t writeback_data;

    logic register_wen;
    logic flags_wen;

    // =========================================================
    // WRITE ENABLE CONTROL
    // =========================================================
    // The core asserts these for exactly the cycle on which an
    // instruction completes, so the multi-cycle ALU cannot disturb
    // the register file until its result is final. An unrecognised
    // encoding (alu_valid low) can never write.
    assign register_wen =
        register_write_enable && alu_valid && !rst;

    assign flags_wen =
        flags_write_enable && alu_valid && !rst;

    // =========================================================
    // REGISTER FILE
    // =========================================================

    cpu_register u_cpu_register (
        .clk(clk),
        .rst(rst),

        .rs1_addr(rs1),
        .rs1_data(operand_a),

        .rs2_addr(rs2),
        .rs2_data(rs2_data),

        .write_enable(register_wen),
        .write_addr(rd),
        .write_data(writeback_data)
    );

    // STORE always needs the unmodified value read from RS2.
    assign store_data = rs2_data;

    // =========================================================
    // OPERAND B MULTIPLEXER
    // =========================================================

    assign operand_b =
        imm_sel ? imm_operand : rs2_data;

    // =========================================================
    // ALU
    // =========================================================

    alu u_alu (
        .clk(clk),
        .rst(rst),

        .start(alu_start),

        .operand_a(operand_a),
        .operand_b(operand_b),

        .op(alu_op),
        .carry_in(carry_in),

        .result(alu_result),
        .flags(flags),
        .valid(alu_valid),
        .busy(alu_busy),
        .done(alu_done)
    );

    // =========================================================
    // WRITEBACK MULTIPLEXER
    // =========================================================
    // Normal ALU instructions write the ALU alu_result. LOAD writes the
    // combinational data-memory read value instead. The effective
    // address remains visible on alu_result for LOAD/STORE.
    assign writeback_data =
        writeback_from_mem ? dmem_rdata : alu_result;

    // =========================================================
    // STATUS REGISTER
    // =========================================================

    status_register u_status_register (
        .clk(clk),
        .rst(rst),

        .write_enable(flags_wen),
        .flags_in(flags),
        .status(status)
    );

endmodule
