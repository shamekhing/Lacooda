`timescale 1ns/1ps

// ============================================================
// LACOODA SYSTEM — STAGE 5
// ============================================================
//
// SYSTEM ARCHITECTURE
//
//   CPU_I ──┐
//   CPU_D ──┤
//   GPU   ──┼──> RPU (4 x 4 routing fabric) ──┬──> ROM
//   TPU   ──┘                                 ├──> DATA RAM
//                                             ├──> GPU MMIO
//                                             └──> DDR3 bridge
//                                                      |
//                                                      v
//                                                DDR3 backend
//
// The RPU replaces the former global arbiter and single-lane
// data interconnect. Each slave has its own round-robin port,
// so transactions to different slaves proceed in parallel.
//
// The CPU instruction and data buses are separate RPU masters.
// Master-qualified routing lets CPU_I see ROM at address 0 and
// CPU_D/GPU/TPU see DATA_RAM at address 0, preserving the
// existing boot program and PC reset value.
//
// GPU MMIO is a slave, whereas the GPU memory interface is a
// master. The two interfaces must not be confused. The same
// distinction applies to the future TPU MMIO slave and TPU
// memory master.
//
// Stage 5 does not implement GPU/TPU execution engines, DMA,
// DDR3 physical signaling, or cache coherency.
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
    // Interface to the DDR3 bridge backend. The backend must
    // share this module's clock domain.
    // ========================================================

    input logic ddr3_backend_ready,

    output bus_pkg::bus_req_s ddr3_backend_bus_req,
    input  bus_pkg::bus_rsp_s ddr3_backend_bus_rsp

);

    // ========================================================
    // CPU INSTRUCTION BUS (CPU_I RPU MASTER)
    // ========================================================

    bus_pkg::bus_req_s cpu_instr_bus_req;
    bus_pkg::bus_rsp_s cpu_instr_bus_rsp;

    // ========================================================
    // CPU DATA BUS (CPU_D RPU MASTER)
    // ========================================================

    bus_pkg::bus_req_s cpu_bus_req;
    bus_pkg::bus_rsp_s cpu_bus_rsp;

    // ========================================================
    // ROM SLAVE BUS
    // ========================================================

    bus_pkg::bus_req_s rom_bus_req;
    bus_pkg::bus_rsp_s rom_bus_rsp;

    // ========================================================
    // INTERNAL RAM SLAVE BUS
    // ========================================================

    bus_pkg::bus_req_s ram_bus_req;
    bus_pkg::bus_rsp_s ram_bus_rsp;

    // ========================================================
    // GPU MMIO SLAVE BUS
    // ========================================================

    bus_pkg::bus_req_s gpu_mmio_bus_req;
    bus_pkg::bus_rsp_s gpu_mmio_bus_rsp;

    // ========================================================
    // DDR3 BRIDGE SLAVE BUS
    // ========================================================

    bus_pkg::bus_req_s ddr3_bus_req;
    bus_pkg::bus_rsp_s ddr3_bus_rsp;

    // ========================================================
    // CPU
    // ========================================================
    //
    // Both the instruction bus and the data bus are RPU
    // masters. The CPU no longer connects directly to memory.
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
    // ROUTING PROCESSING UNIT
    // ========================================================
    //
    // Four masters, four implemented slaves. The RPU performs
    // per-slave arbitration and routes each response back to
    // the originating master only.
    //
    // All arbitration, ownership, and routing state remains
    // internal to the RPU.
    // ========================================================

    rpu_top u_rpu (

        .clk                 (clk),
        .rst                 (rst),

        .cpu_instr_bus_req   (cpu_instr_bus_req),
        .cpu_instr_bus_rsp   (cpu_instr_bus_rsp),

        .cpu_bus_req         (cpu_bus_req),
        .cpu_bus_rsp         (cpu_bus_rsp),

        .gpu_bus_req         (gpu_bus_req),
        .gpu_bus_rsp         (gpu_bus_rsp),

        .tpu_bus_req         (tpu_bus_req),
        .tpu_bus_rsp         (tpu_bus_rsp),

        .rom_bus_req         (rom_bus_req),
        .rom_bus_rsp         (rom_bus_rsp),

        .ram_bus_req         (ram_bus_req),
        .ram_bus_rsp         (ram_bus_rsp),

        .gpu_mmio_bus_req    (gpu_mmio_bus_req),
        .gpu_mmio_bus_rsp    (gpu_mmio_bus_rsp),

        .ddr3_bus_req        (ddr3_bus_req),
        .ddr3_bus_rsp        (ddr3_bus_rsp)

    );

    // ========================================================
    // INTERNAL MEMORY SUBSYSTEM
    // ========================================================
    //
    // ROM and RAM are independent RPU slaves. The memory
    // subsystem no longer owns the CPU instruction connection.
    // ========================================================

    memory_subsystem u_memory (

        .clk          (clk),
        .rst          (rst),

        .rom_bus_req  (rom_bus_req),
        .rom_bus_rsp  (rom_bus_rsp),

        .ram_bus_req  (ram_bus_req),
        .ram_bus_rsp  (ram_bus_rsp)

    );


    // ========================================================
    // GPU MMIO SLAVE
    // ========================================================
    //
    // The GPU block currently implements only configuration
    // and status registers. Its memory-master port remains
    // separate and may be driven by a future GPU engine.
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
