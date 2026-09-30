`timescale 1ns/1ps

// ============================================================
// LACOODA minimal system wrapper
//
// cpu.sv is now the CPU boundary. This module is deliberately outside
// that boundary and represents the smallest possible SoC around it:
//
//      CPU bus master <-> local data-memory bus slave
//
// Future address decoding, DDR3, MMIO, GPU, timers, input devices, etc.
// belong on this side of the CPU bus and can replace/extend this wrapper
// without changing the CPU's LOAD/STORE semantics.
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

    // CPU data-bus master signals.
    logic bus_valid;
    logic bus_write;
    logic bus_ready;
    cpu_pkg::data_t bus_address;
    cpu_pkg::data_t bus_write_data;
    cpu_pkg::data_t bus_read_data;

    cpu u_cpu (
        .clk                 (clk),
        .rst                 (rst),
        .run                 (run),

        .bus_valid           (bus_valid),
        .bus_write           (bus_write),
        .bus_address         (bus_address),
        .bus_write_data      (bus_write_data),
        .bus_ready           (bus_ready),
        .bus_read_data       (bus_read_data),

        .pc                  (pc),
        .instruction         (instruction),
        .execution_valid     (execution_valid),
        .illegal_instruction (illegal_instruction),
        .result              (result)
    );

    data_memory u_dmem (
        .clk       (clk),
        .bus_valid (bus_valid),
        .bus_write (bus_write),
        .address   (bus_address),
        .write_data(bus_write_data),
        .bus_ready (bus_ready),
        .read_data (bus_read_data)
    );

endmodule
