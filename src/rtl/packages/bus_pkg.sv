`timescale 1ns/1ps
`ifndef BUS_PKG_SV
`define BUS_PKG_SV

// ============================================================
// LACOODA bus package
//
// Shared SoC-side definitions for the simple valid/ready bus.
//
// The CPU does not know which devices occupy which addresses.
// It only produces byte addresses through its instruction/data
// master interfaces.
//
// Address-map ownership belongs here rather than in cpu_pkg or
// individual peripherals.
// ============================================================

package bus_pkg;

    // --------------------------------------------------------
    // Bus operation
    // --------------------------------------------------------

    typedef enum logic {
        BUS_READ  = 1'b0,
        BUS_WRITE = 1'b1
    } bus_op_e;

    // --------------------------------------------------------
    // Bus request
    //
    // A master keeps this request stable until the selected
    // slave completes the transaction with rsp.ready.
    // --------------------------------------------------------

    typedef struct packed {
        logic           valid;
        bus_op_e        op;
        cpu_pkg::word_t addr;
        cpu_pkg::word_t wdata;
    } bus_req_s;

    // --------------------------------------------------------
    // Bus response
    //
    // A transaction completes when:
    //
    //     req.valid && rsp.ready
    //
    // rdata is meaningful for BUS_READ transactions.
    // --------------------------------------------------------

    typedef struct packed {
        logic           ready;
        cpu_pkg::word_t rdata;
    } bus_rsp_s;

    // ========================================================
    // LOCAL DATA MEMORY REGION
    // ========================================================
    //
    // Local data RAM begins at address zero and occupies exactly
    // DATA_MEMORY_COUNT architectural words.
    //
    // Address range:
    //
    //     [DATA_MEMORY_BASE, DATA_MEMORY_LIMIT)
    //
    // LIMIT is exclusive.
    // ========================================================

    localparam cpu_pkg::word_t DATA_MEMORY_BASE =
        cpu_pkg::word_t'(0);

    // Perform the calculation using the architectural word type.
    //
    // This avoids SystemVerilog int-width overflow when the
    // address space is made larger.
    localparam cpu_pkg::word_t DATA_MEMORY_SIZE =
        cpu_pkg::word_t'(cpu_pkg::DATA_MEMORY_COUNT) *
        cpu_pkg::word_t'(cpu_pkg::WORD_BYTES);

    localparam cpu_pkg::word_t DATA_MEMORY_LIMIT =
        DATA_MEMORY_BASE + DATA_MEMORY_SIZE;

    // ========================================================
    // GPU MMIO REGION
    // ========================================================
    //
    // Stage 1 reserves a 4 KiB address window for the GPU.
    //
    // The GPU does not yet contain architectural registers.
    // This region simply gives the GPU a permanent place in the
    // SoC address map so CPU LOAD/STORE transactions can reach it.
    //
    // CPU-visible address range:
    //
    //     0x1000_0000
    //          ...
    //     0x1000_0FFF
    //
    // GPU_LIMIT is exclusive:
    //
    //     0x1000_1000
    //
    // The interconnect converts these CPU-visible addresses into
    // GPU-local offsets before presenting them to gpu.sv.
    // ========================================================

    localparam cpu_pkg::word_t GPU_BASE =
        cpu_pkg::word_t'(32'h1000_0000);

    localparam cpu_pkg::word_t GPU_SIZE =
        cpu_pkg::word_t'(32'h0000_1000);

    localparam cpu_pkg::word_t GPU_LIMIT =
        GPU_BASE + GPU_SIZE;

endpackage

`endif