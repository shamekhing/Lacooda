`timescale 1ns/1ps

// ============================================================
// LACOODA SYSTEM — STAGE 4
// ============================================================
//
// SYSTEM ARCHITECTURE
//
//                    CPU
//                     |
//                     | CPU data bus
//                     v
//                +----------+
// GPU master --->|          |
// TPU master --->| Arbiter  |
//                |          |
//                +-----+----+
//                      |
//                      v
//                Bus Interconnect
//                      |
//          +-----------+-----------+
//          |           |           |
//          v           v           v
//      Data RAM     GPU MMIO   DDR3 Bridge
//                                  |
//                                  v
//                            DDR3 Backend
//
// The CPU instruction bus remains independent.
//
// GPU MMIO is a slave, whereas the future GPU memory
// interface is a master.
//
// Those interfaces must not be confused.
//
// The same distinction applies to the TPU:
//
//   TPU MMIO registers are future bus slaves.
//   TPU memory requests are future bus-master traffic.
//
// The arbiter forwards only one master's request at a time.
//
// Stage 4 does not implement GPU/TPU execution engines,
// DMA, DDR3 physical signaling, or cache coherency.
// ============================================================

module system (

    // ========================================================
    // CLOCK AND CONTROL
    // ========================================================

    input logic clk,
    input logic rst,
    input logic run,

    // ========================================================
    // CPU STATUS
    // ========================================================

    output logic retire_valid,
    output logic illegal_instr,
    output logic cpu_fault,

    // ========================================================
    // GPU MEMORY MASTER
    // ========================================================
    //
    // GPU-generated memory transactions.
    //
    // This is separate from the GPU MMIO slave interface.
    //
    // An external or future internal GPU engine may present
    // requests using this native bus connection.
    // ========================================================

    input  bus_pkg::bus_req_s gpu_bus_req,
    output bus_pkg::bus_rsp_s gpu_bus_rsp,

    // ========================================================
    // TPU MEMORY MASTER
    // ========================================================

    input  bus_pkg::bus_req_s tpu_bus_req,
    output bus_pkg::bus_rsp_s tpu_bus_rsp,

    // ========================================================
    // DDR3 BACKEND
    // ========================================================
    //
    // Interface to the Stage 3 DDR3 bridge backend.
    //
    // The backend must share this module's clock domain.
    //
    // A generated Gowin DDR3 controller requires a separate
    // controller-specific adapter.
    // ========================================================

    input logic ddr3_backend_ready,

    output bus_pkg::bus_req_s ddr3_backend_bus_req,
    input  bus_pkg::bus_rsp_s ddr3_backend_bus_rsp

);

    // ========================================================
    // CPU INSTRUCTION BUS
    // ========================================================

    bus_pkg::bus_req_s cpu_instr_bus_req;
    bus_pkg::bus_rsp_s cpu_instr_bus_rsp;

    // ========================================================
    // CPU DATA BUS
    // ========================================================

    bus_pkg::bus_req_s cpu_bus_req;
    bus_pkg::bus_rsp_s cpu_bus_rsp;

    // ========================================================
    // SHARED DATA BUS
    // ========================================================
    //
    // The arbiter produces one downstream transaction.
    //
    // The interconnect treats it exactly like the original
    // Stage 3 CPU data-bus request.
    // ========================================================

    bus_pkg::bus_req_s shared_bus_req;
    bus_pkg::bus_rsp_s shared_bus_rsp;

    // ========================================================
    // INTERNAL RAM BUS
    // ========================================================

    bus_pkg::bus_req_s ram_bus_req;
    bus_pkg::bus_rsp_s ram_bus_rsp;

    // ========================================================
    // GPU MMIO SLAVE BUS
    // ========================================================

    bus_pkg::bus_req_s gpu_mmio_bus_req;
    bus_pkg::bus_rsp_s gpu_mmio_bus_rsp;

    // ========================================================
    // DDR3 BRIDGE BUS
    // ========================================================

    bus_pkg::bus_req_s ddr3_bus_req;
    bus_pkg::bus_rsp_s ddr3_bus_rsp;

    // ========================================================
    // CPU
    // ========================================================
    //
    // CPU instruction accesses bypass the shared data
    // arbiter and continue using instruction ROM.
    //
    // CPU loads and stores enter the arbiter.
    // ========================================================

    cpu u_cpu (

        .clk           (clk),
        .rst           (rst),
        .run           (run),

        .cpu_instr_bus_req      (cpu_instr_bus_req),
        .cpu_instr_bus_rsp      (cpu_instr_bus_rsp),

        .cpu_bus_req      (cpu_bus_req),
        .cpu_bus_rsp      (cpu_bus_rsp),

        .retire_valid  (retire_valid),
        .illegal_instr (illegal_instr),
        .fault         (cpu_fault)

    );

    // ========================================================
    // THREE-MASTER ARBITER
    // ========================================================
    //
    // CPU, GPU and TPU requests compete for one shared
    // data-bus transaction interface.
    //
    // Priority rotates after successful completion,
    // including transactions that finish with bus errors.
    // ========================================================

    bus_arbiter u_bus_arbiter (

        .clk       (clk),
        .rst       (rst),

        .cpu_bus_req   (cpu_bus_req),
        .cpu_bus_rsp   (cpu_bus_rsp),

        .gpu_bus_req   (gpu_bus_req),
        .gpu_bus_rsp   (gpu_bus_rsp),

        .tpu_bus_req   (tpu_bus_req),
        .tpu_bus_rsp   (tpu_bus_rsp),

        .shared_bus_req (shared_bus_req),
        .shared_bus_rsp (shared_bus_rsp)

    );

    // ========================================================
    // DATA BUS INTERCONNECT
    // ========================================================
    //
    // The interconnect sees only one incoming request.
    //
    // It does not need to know which master generated it.
    //
    // The arbiter retains that ownership information.
    // ========================================================

    bus_interconnect u_bus_interconnect (

        .shared_bus_req     (shared_bus_req),
        .shared_bus_rsp     (shared_bus_rsp),

        .ram_bus_req (ram_bus_req),
        .ram_bus_rsp (ram_bus_rsp),

        .gpu_mmio_bus_req (gpu_mmio_bus_req),
        .gpu_mmio_bus_rsp (gpu_mmio_bus_rsp),

        .ddr3_bus_req     (ddr3_bus_req),
        .ddr3_bus_rsp     (ddr3_bus_rsp)

    );

    // ========================================================
    // INTERNAL MEMORY SUBSYSTEM
    // ========================================================

    memory_subsystem u_memory (

        .clk          (clk),
        .rst          (rst),

        .cpu_instr_bus_req     (cpu_instr_bus_req),
        .cpu_instr_bus_rsp     (cpu_instr_bus_rsp),

        .ram_bus_req (ram_bus_req),
        .ram_bus_rsp (ram_bus_rsp)

    );

    // ========================================================
    // GPU MMIO SLAVE
    // ========================================================
    //
    // The GPU block currently implements only configuration
    // and status registers.
    //
    // It does not yet generate its own memory requests.
    // ========================================================

    gpu u_gpu (

        .clk      (clk),
        .rst      (rst),

        .gpu_mmio_bus_req (gpu_mmio_bus_req),
        .gpu_mmio_bus_rsp (gpu_mmio_bus_rsp)

    );

    // ========================================================
    // DDR3 NATIVE BUS BRIDGE
    // ========================================================

    ddr3_bridge u_ddr3_bridge (

        .clk           (clk),
        .rst           (rst),

        .ddr3_bus_req      (ddr3_bus_req),
        .ddr3_bus_rsp      (ddr3_bus_rsp),

        .backend_ready (ddr3_backend_ready),

        .ddr3_backend_bus_req   (ddr3_backend_bus_req),
        .ddr3_backend_bus_rsp   (ddr3_backend_bus_rsp)

    );

endmodule
