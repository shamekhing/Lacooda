`timescale 1ns/1ps

// ============================================================
// LACOODA CPU system — Stage 7
//
// Connects:
//   instruction fetch <-> cpu_core control flow
//   cpu_core          <-> simple Stage-7 data memory
//
// The Stage-7 data memory has combinational reads and synchronous
// writes. A later bus substage can replace this fixed-latency connection
// with a valid/ready interface without changing LOAD/STORE semantics.
// ============================================================

module cpu_system (
    input logic clk,
    input logic rst,
    input logic run,

    output cpu_pkg::data_t pc,
    output cpu_pkg::instruction_t instruction,

    output logic execution_valid,
    output logic illegal_instruction,

    output cpu_pkg::data_t result
);

    logic instruction_valid;
    logic fetch_enable;

    cpu_pkg::data_t operand_a;
    cpu_pkg::data_t operand_b;

    alu_pkg::flags_t alu_flags;
    alu_pkg::flags_t status_flags;

    // Stage 6 feedback from cpu_core to instruction_fetch/PC.
    logic redirect;
    cpu_pkg::data_t redirect_target;

    // Stage 7 CPU <-> local data-memory signals.
    logic memory_read_enable;
    logic memory_write_enable;
    cpu_pkg::data_t memory_address;
    cpu_pkg::data_t memory_write_data;
    cpu_pkg::data_t memory_read_data;

    // run=0 freezes the PC and prevents instruction execution.
    assign fetch_enable = run && !rst;

    instruction_fetch u_fetch (
        .clk         (clk),
        .rst         (rst),
        .enable      (fetch_enable),
        .redirect    (redirect),
        .target      (redirect_target),
        .pc          (pc),
        .instruction (instruction)
    );

    cpu_core u_core (
        .clk                 (clk),
        .rst                 (rst),

        .instruction_enable  (fetch_enable),
        .instruction         (instruction),

        // ADC/SBC receive a fixed carry input here, not the saved status C flag.
        .carry_in            (1'b0),

        .memory_read_data    (memory_read_data),

        .instruction_valid   (instruction_valid),
        .illegal_instruction (illegal_instruction),
        .execution_valid     (execution_valid),

        .redirect            (redirect),
        .redirect_target     (redirect_target),

        .memory_read_enable  (memory_read_enable),
        .memory_write_enable (memory_write_enable),
        .memory_address      (memory_address),
        .memory_write_data   (memory_write_data),

        .operand_a           (operand_a),
        .operand_b           (operand_b),
        .result              (result),

        .alu_flags           (alu_flags),
        .status_flags        (status_flags)
    );

    data_memory u_dmem (
        .clk          (clk),
        .read_enable  (memory_read_enable),
        .write_enable (memory_write_enable),
        .address      (memory_address),
        .write_data   (memory_write_data),
        .read_data    (memory_read_data)
    );

endmodule
