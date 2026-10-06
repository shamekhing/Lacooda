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

    output cpu_pkg::word_t pc,
    output cpu_pkg::instruction_t instruction,
    output logic retire_valid,
    output logic illegal_instr,
    output cpu_pkg::word_t alu_result
);

    // CPU instruction bus.
    bus_pkg::bus_req_s instr_req;
    bus_pkg::bus_rsp_s instr_rsp;

    // CPU data-bus master side.
    bus_pkg::bus_req_s data_req;
    bus_pkg::bus_rsp_s data_rsp;

    // Interconnect -> local data-memory slave side.
    bus_pkg::bus_req_s  slave_req;
    bus_pkg::bus_rsp_s  slave_rsp;

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

    instruction_memory u_instruction_memory (
        .slave_req (instr_req),
        .slave_rsp (instr_rsp)
    );

    bus_interconnect u_bus_interconnect (
        .d_req     (data_req),
        .d_rsp     (data_rsp),
        .slave_req (slave_req),
        .slave_rsp (slave_rsp)
    );

    data_memory u_data_memory (
        .clk       (clk),
        .slave_req (slave_req),
        .slave_rsp (slave_rsp)
    );

endmodule
