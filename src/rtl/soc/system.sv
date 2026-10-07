`timescale 1ns/1ps

// ============================================================
// LACOODA minimal SoC wrapper
//
// cpu.sv remains the CPU boundary.
//
// System structure after GPU Stage 1:
//
//      CPU I-BUS
//          |
//          +-----------------> instruction_memory
//
//      CPU D-BUS
//          |
//          v
//      bus_interconnect
//          |
//          +-----------------> data_memory
//          |
//          +-----------------> gpu
//
// The CPU still sees only its generic I-BUS and D-BUS.
// Device selection belongs to the SoC/interconnect rather than
// the processor core.
// ============================================================

module system (
    input logic clk,
    input logic rst,
    input logic run,

    output cpu_pkg::word_t pc,
    output cpu_pkg::instruction_t instruction,
    output logic retire_valid,
    output logic illegal_instr,
    output cpu_pkg::word_t alu_result
);

    // ========================================================
    // CPU INSTRUCTION BUS
    // ========================================================

    bus_pkg::bus_req_s instr_req;
    bus_pkg::bus_rsp_s instr_rsp;

    // ========================================================
    // CPU DATA BUS
    // ========================================================

    bus_pkg::bus_req_s data_req;
    bus_pkg::bus_rsp_s data_rsp;

    // ========================================================
    // LOCAL DATA MEMORY BUS
    // ========================================================

    bus_pkg::bus_req_s data_memory_req;
    bus_pkg::bus_rsp_s data_memory_rsp;

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

        .instr_req      (instr_req),
        .instr_rsp      (instr_rsp),

        .data_req       (data_req),
        .data_rsp       (data_rsp),

        .pc             (pc),
        .instruction    (instruction),
        .retire_valid   (retire_valid),
        .illegal_instr  (illegal_instr),
        .alu_result     (alu_result)
    );

   
    // ========================================================
    // DATA-BUS INTERCONNECT
    // ========================================================

    bus_interconnect u_bus_interconnect (
        .d_req           (data_req),
        .d_rsp           (data_rsp),

        .data_memory_req (data_memory_req),
        .data_memory_rsp (data_memory_rsp),

        .gpu_req         (gpu_req),
        .gpu_rsp         (gpu_rsp)
    );

    // ========================================================
    // LOCAL DATA MEMORY
    // ========================================================

    data_memory u_data_memory (
        .clk       (clk),

        .ibus_req (data_memory_req),
        .ibus_rsp (data_memory_rsp)
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