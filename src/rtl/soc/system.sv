`timescale 1ns/1ps

// CPU instruction fetch and load/store are external bus masters.
// The memory subsystem owns instruction ROM and data BRAM.

module system (
    input logic clk,
    input logic rst,
    input logic run,

    output cpu_pkg::word_t pc,
    output logic retire_valid,
    output logic illegal_instr
);

    // ========================================================
    // CPU BUSES
    // ========================================================

    bus_pkg::bus_req_s ibus_req;
    bus_pkg::bus_rsp_s ibus_rsp;
    bus_pkg::bus_req_s dbus_req;
    bus_pkg::bus_rsp_s dbus_rsp;

    // ========================================================
    // LOCAL DATA MEMORY BUS
    // ========================================================

    bus_pkg::bus_req_s data_mem_req;
    bus_pkg::bus_rsp_s data_mem_rsp;

    // ========================================================
    // GPU BUS
    // ========================================================

    bus_pkg::bus_req_s gpu_mmio_req;
    bus_pkg::bus_rsp_s gpu_mmio_rsp;

    // ========================================================
    // CPU
    // ========================================================

    cpu u_cpu (
        .clk            (clk),
        .rst            (rst),
        .run            (run),

        .ibus_req        (ibus_req),
        .ibus_rsp        (ibus_rsp),
        .dbus_req        (dbus_req),
        .dbus_rsp        (dbus_rsp),

        .pc             (pc),
        .retire_valid   (retire_valid),
        .illegal_instr  (illegal_instr)
    );

    // ========================================================
    // DATA-BUS INTERCONNECT
    // ========================================================

    bus_interconnect u_bus_interconnect (
        .dbus_req         (dbus_req),
        .dbus_rsp         (dbus_rsp),

        .data_mem_req (data_mem_req),
        .data_mem_rsp (data_mem_rsp),

        .gpu_mmio_req         (gpu_mmio_req),
        .gpu_mmio_rsp         (gpu_mmio_rsp)
    );

    // ========================================================
    // MEMORY SUBSYSTEM
    // ========================================================

    memory_subsystem u_memory (
        .clk       (clk),
        .rst       (rst),

        .ibus_req (ibus_req),
        .ibus_rsp (ibus_rsp),
        .mem_req  (data_mem_req),
        .mem_rsp  (data_mem_rsp)
    );

    // ========================================================
    // GPU
    // ========================================================

    gpu u_gpu (
        .clk       (clk),
        .rst       (rst),

        .mmio_req (gpu_mmio_req),
        .mmio_rsp (gpu_mmio_rsp)
    );

endmodule
