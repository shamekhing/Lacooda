`timescale 1ns/1ps

// ============================================================
// LACOODA CPU wrapper
//
// This module is the closed CPU boundary after Stage 7.
// It contains:
//   - program counter
//   - instruction memory / instruction fetch
//   - decoder
//   - register file
//   - ALU/datapath
//   - status register
//   - branch unit
//   - LOAD/STORE bus transaction handling
//
// Everything beyond the data-bus ports belongs to the surrounding SoC.
//
// Data-bus handshake:
//   1. CPU asserts bus_valid with address/control/data.
//   2. CPU keeps that request stable while bus_ready is low.
//   3. Transfer completes on a clock edge where bus_valid && bus_ready.
//   4. For LOAD, bus_read_data is written to RD on that edge.
//   5. While waiting, the PC is held on the memory instruction.
//
// bus_write:
//   0 = read / LOAD
//   1 = write / STORE
// ============================================================

module cpu (
    input logic clk,
    input logic rst,
    input logic run,

    // --------------------------------------------------------
    // External data-bus master interface.
    // --------------------------------------------------------
    output logic bus_valid,
    output logic bus_write,
    output cpu_pkg::data_t bus_address,
    output cpu_pkg::data_t bus_write_data,
    input  logic bus_ready,
    input  cpu_pkg::data_t bus_read_data,

    // Existing observation outputs retained for simulation/debug.
    output cpu_pkg::data_t pc,
    output cpu_pkg::instruction_t instruction,
    output logic execution_valid,
    output logic illegal_instruction,
    output cpu_pkg::data_t result
);

    logic instruction_valid;
    logic core_enable;
    logic fetch_enable;
    logic memory_waiting;

    cpu_pkg::data_t operand_a;
    cpu_pkg::data_t operand_b;

    alu_pkg::flags_t alu_flags;
    alu_pkg::flags_t status_flags;

    logic redirect;
    cpu_pkg::data_t redirect_target;

    // Remember an outstanding transaction so an external pause request cannot
    // abandon a bus transfer after valid has been presented without ready.
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            memory_waiting <= 1'b0;
        else if (bus_valid && bus_ready)
            memory_waiting <= 1'b0;
        else if (bus_valid && !bus_ready)
            memory_waiting <= 1'b1;
    end

    // run starts/continues ordinary execution. Once a memory transaction is
    // waiting, the core stays enabled until that transaction completes even if
    // run is deasserted, preserving the valid/ready master guarantee.
    assign core_enable = (run || memory_waiting) && !rst;

    // Normal instructions advance only while run is asserted. A memory
    // transaction advances the PC exactly on its accepting handshake, even if
    // run was deasserted while that already-issued transaction was waiting.
    // This prevents a completed STORE/LOAD from being replayed after resume.
    assign fetch_enable =
        !rst &&
        ((run && !bus_valid) || (bus_valid && bus_ready));

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

        .instruction_enable  (core_enable),
        .instruction         (instruction),

        // ADC/SBC retain the existing fixed carry input behavior.
        .carry_in            (1'b0),

        .bus_ready           (bus_ready),
        .bus_read_data       (bus_read_data),

        .instruction_valid   (instruction_valid),
        .illegal_instruction (illegal_instruction),
        .execution_valid     (execution_valid),

        .redirect            (redirect),
        .redirect_target     (redirect_target),

        .bus_valid           (bus_valid),
        .bus_write           (bus_write),
        .bus_address         (bus_address),
        .bus_write_data      (bus_write_data),

        .operand_a           (operand_a),
        .operand_b           (operand_b),
        .result              (result),

        .alu_flags           (alu_flags),
        .status_flags        (status_flags)
    );

endmodule
