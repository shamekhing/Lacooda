`timescale 1ns/1ps

// ============================================================
// LACOODA minimal SoC wrapper
//
// cpu.sv remains the CPU boundary.
//
// System structure after GPU Stage 1:
//
//      CPU (including instruction_memory)
//
//      CPU D-BUS
//          |
//          v
//      bus_interconnect
//          |
//          +-----------------> cpu_memory
//          |
//          +-----------------> gpu
//
// The CPU's data bus reaches the SoC interconnect, which selects
// cpu_memory or the GPU.
// ============================================================

module system (
    input logic clk,
    input logic rst,
    input logic run,

    output cpu_pkg::word_t pc,
    output logic retire_valid,
    output logic illegal_instr
);

    // ========================================================
    // CPU DATA BUS
    // ========================================================

    bus_pkg::bus_req_s cpu_req;
    bus_pkg::bus_rsp_s cpu_rsp;

    // ========================================================
    // LOCAL DATA MEMORY BUS
    // ========================================================

    bus_pkg::bus_req_s cpu_memory_req;
    bus_pkg::bus_rsp_s cpu_memory_rsp;

    // ========================================================
    // GPU BUS
    // ========================================================

    bus_pkg::bus_req_s gpu_req;
    bus_pkg::bus_rsp_s gpu_rsp;

    // ========================================================
    // CPU
    // ========================================================

    cpu u_cpu (
        .clk            (clk),
        .rst            (rst),
        .run            (run),

        .cpu_req        (cpu_req),
        .cpu_rsp        (cpu_rsp),

        .pc             (pc),
        .retire_valid   (retire_valid),
        .illegal_instr  (illegal_instr)
    );

    // ========================================================
    // DATA-BUS INTERCONNECT
    // ========================================================

    bus_interconnect u_bus_interconnect (
        .cpu_req         (cpu_req),
        .cpu_rsp         (cpu_rsp),

        .cpu_memory_req (cpu_memory_req),
        .cpu_memory_rsp (cpu_memory_rsp),

        .gpu_req         (gpu_req),
        .gpu_rsp         (gpu_rsp)
    );

    // ========================================================
    // LOCAL DATA MEMORY
    // ========================================================

    cpu_memory u_cpu_memory (
        .clk       (clk),
        .rst       (rst),

        .dbus_req (cpu_memory_req),
        .dbus_rsp (cpu_memory_rsp)
    );

    // ========================================================
    // GPU
    // ========================================================

    gpu u_gpu (
        .clk       (clk),
        .rst       (rst),

        .ibus_req (gpu_req),
        .ibus_rsp (gpu_rsp)
    );

endmodule
