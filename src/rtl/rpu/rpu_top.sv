`timescale 1ns/1ps

// ============================================================
// LACOODA ROUTING PROCESSING UNIT — TOP — STAGE 5
// ============================================================
//
// SoC-facing named wrapper around the fixed 4 x 4 crossbar.
//
// MASTERS
//
//   cpu_instr : CPU instruction fetch
//   cpu       : CPU data / MMIO
//   gpu   : GPU memory master
//   tpu   : TPU memory master
//
// SLAVES
//
//   rom      : instruction ROM
//   ram      : internal data RAM
//   gpu_mmio : GPU register block (slave interface)
//   ddr3     : native DDR3 bridge
//
// The GPU's MMIO slave interface and its memory master interface
// are deliberately separate ports. They serve different roles
// and must not be merged.
//
// All routing policy is in rpu_pkg.sv. This wrapper only maps
// named SoC ports to the crossbar's numbered ports.
// ============================================================

module rpu_top (

    input logic clk,
    input logic rst,

    // --------------------------------------------------------
    // MASTERS
    // --------------------------------------------------------

    input  bus_pkg::bus_req_s cpu_instr_bus_req,
    output bus_pkg::bus_rsp_s cpu_instr_bus_rsp,

    input  bus_pkg::bus_req_s cpu_bus_req,
    output bus_pkg::bus_rsp_s cpu_bus_rsp,

    input  bus_pkg::bus_req_s gpu_bus_req,
    output bus_pkg::bus_rsp_s gpu_bus_rsp,

    input  bus_pkg::bus_req_s tpu_bus_req,
    output bus_pkg::bus_rsp_s tpu_bus_rsp,

    // --------------------------------------------------------
    // SLAVES
    // --------------------------------------------------------

    output bus_pkg::bus_req_s rom_bus_req,
    input  bus_pkg::bus_rsp_s rom_bus_rsp,

    output bus_pkg::bus_req_s ram_bus_req,
    input  bus_pkg::bus_rsp_s ram_bus_rsp,

    output bus_pkg::bus_req_s gpu_mmio_bus_req,
    input  bus_pkg::bus_rsp_s gpu_mmio_bus_rsp,

    output bus_pkg::bus_req_s ddr3_bus_req,
    input  bus_pkg::bus_rsp_s ddr3_bus_rsp

);

    rpu_crossbar u_crossbar (

        .clk(clk),
        .rst(rst),

        .m0_req(cpu_instr_bus_req),
        .m0_rsp(cpu_instr_bus_rsp),

        .m1_req(cpu_bus_req),
        .m1_rsp(cpu_bus_rsp),

        .m2_req(gpu_bus_req),
        .m2_rsp(gpu_bus_rsp),

        .m3_req(tpu_bus_req),
        .m3_rsp(tpu_bus_rsp),

        .s0_req(rom_bus_req),
        .s0_rsp(rom_bus_rsp),

        .s1_req(ram_bus_req),
        .s1_rsp(ram_bus_rsp),

        .s2_req(gpu_mmio_bus_req),
        .s2_rsp(gpu_mmio_bus_rsp),

        .s3_req(ddr3_bus_req),
        .s3_rsp(ddr3_bus_rsp),

        .master_pending(),
        .slave_active()

    );

endmodule
