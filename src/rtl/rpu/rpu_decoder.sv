`timescale 1ns/1ps

// ============================================================
// LACOODA RPU ADDRESS DECODER — STAGE 5
// ============================================================
//
// One combinational decoder instance covers all four masters.
// Keeping the four decodes in a single instance avoids the
// Icarus 12 issue documented in README.md, where package
// functions called from always_comb in several instances can
// be mis-scheduled.
//
// The policy itself lives in rpu_pkg::rpu_decode.
// ============================================================

module rpu_decoder (

    input  cpu_pkg::word_t cpu_i_addr,
    input  cpu_pkg::word_t cpu_d_addr,
    input  cpu_pkg::word_t gpu_addr,
    input  cpu_pkg::word_t tpu_addr,

    output rpu_pkg::rpu_route_s cpu_i_route,
    output rpu_pkg::rpu_route_s cpu_d_route,
    output rpu_pkg::rpu_route_s gpu_route,
    output rpu_pkg::rpu_route_s tpu_route

);

    always_comb begin

        cpu_i_route = rpu_pkg::rpu_decode(
            rpu_pkg::RPU_M_CPU_I,
            cpu_i_addr
        );

        cpu_d_route = rpu_pkg::rpu_decode(
            rpu_pkg::RPU_M_CPU_D,
            cpu_d_addr
        );

        gpu_route = rpu_pkg::rpu_decode(
            rpu_pkg::RPU_M_GPU,
            gpu_addr
        );

        tpu_route = rpu_pkg::rpu_decode(
            rpu_pkg::RPU_M_TPU,
            tpu_addr
        );

    end

endmodule
