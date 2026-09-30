`timescale 1ns/1ps

// ============================================================
// LACOODA minimal SoC wrapper
//
// cpu.sv is the finished CPU boundary. This module is intentionally outside
// the CPU and supplies the smallest system needed to run programs:
//
//      CPU I-BUS  -> local instruction memory
//      CPU D-BUS  -> bus interconnect -> local data memory
//
// Future DDR3/MMIO/video/peripheral slaves belong here or below rtl/bus/;
// they do not require changing the CPU's I-BUS/D-BUS contract.
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

    // --------------------------------------------------------
    // CPU instruction bus.
    // --------------------------------------------------------
    logic ibus_valid;
    logic ibus_ready;
    cpu_pkg::data_t ibus_address;
    cpu_pkg::instruction_t ibus_read_data;

    // --------------------------------------------------------
    // CPU data-bus master side.
    // --------------------------------------------------------
    logic dbus_valid;
    logic dbus_write;
    logic dbus_ready;
    cpu_pkg::data_t dbus_address;
    cpu_pkg::data_t dbus_write_data;
    cpu_pkg::data_t dbus_read_data;

    // --------------------------------------------------------
    // Interconnect -> local data-memory slave side.
    // --------------------------------------------------------
    logic data_memory_valid;
    logic data_memory_write;
    logic data_memory_ready;
    cpu_pkg::data_t data_memory_address;
    cpu_pkg::data_t data_memory_write_data;
    cpu_pkg::data_t data_memory_read_data;

    cpu u_cpu (
        .clk                 (clk),
        .rst                 (rst),
        .run                 (run),

        .ibus_valid          (ibus_valid),
        .ibus_address        (ibus_address),
        .ibus_ready          (ibus_ready),
        .ibus_read_data      (ibus_read_data),

        .dbus_valid          (dbus_valid),
        .dbus_write          (dbus_write),
        .dbus_address        (dbus_address),
        .dbus_write_data     (dbus_write_data),
        .dbus_ready          (dbus_ready),
        .dbus_read_data      (dbus_read_data),

        .pc                  (pc),
        .instruction         (instruction),
        .execution_valid     (execution_valid),
        .illegal_instruction (illegal_instruction),
        .result              (result)
    );

    instruction_memory u_imem (
        .bus_valid (ibus_valid),
        .address   (ibus_address),
        .bus_ready (ibus_ready),
        .read_data (ibus_read_data)
    );

    bus_interconnect u_bus (
        .master_valid          (dbus_valid),
        .master_write          (dbus_write),
        .master_address        (dbus_address),
        .master_write_data     (dbus_write_data),
        .master_ready          (dbus_ready),
        .master_read_data      (dbus_read_data),

        .data_memory_valid     (data_memory_valid),
        .data_memory_write     (data_memory_write),
        .data_memory_address   (data_memory_address),
        .data_memory_write_data(data_memory_write_data),
        .data_memory_ready     (data_memory_ready),
        .data_memory_read_data (data_memory_read_data)
    );

    data_memory u_dmem (
        .clk        (clk),
        .bus_valid  (data_memory_valid),
        .bus_write  (data_memory_write),
        .address    (data_memory_address),
        .write_data (data_memory_write_data),
        .bus_ready  (data_memory_ready),
        .read_data  (data_memory_read_data)
    );

endmodule
