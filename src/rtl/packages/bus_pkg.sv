`timescale 1ns/1ps
`ifndef BUS_PKG_SV
`define BUS_PKG_SV

// ============================================================
// LACOODA bus package
//
// Shared SoC-side address-map constants for the simple valid/ready
// memory bus. The CPU itself does not depend on these addresses; it
// only emits byte addresses on its instruction and data master ports.
// ============================================================

package bus_pkg;

    typedef enum logic {
        BUS_READ  = 1'b0,
        BUS_WRITE = 1'b1
    } bus_op_t;

    // A single request completes when req.valid && rsp.ready.
    typedef struct packed {
        logic              valid;
        bus_op_t    op;
        cpu_pkg::word_t addr;
        cpu_pkg::word_t    wdata;
    } bus_req_t;

    typedef struct packed {
        logic           ready;
        cpu_pkg::word_t rdata;
    } bus_rsp_t;

    // local data RAM occupies the first DATA_MEMORY_COUNT words
    // of the data address space. Future MMIO/DDR regions can be added here
    // without changing the CPU interface or instruction set.
    localparam cpu_pkg::word_t DATA_MEMORY_BASE = cpu_pkg::word_t'(0);

    // Perform the size calculation at the architectural data/address width.
    // Using SystemVerilog `int` here would make the multiplication 32-bit
    // signed arithmetic and could wrap a valid large memory map back to zero.
    // The region is sized from the data memory's own parameter group.
    localparam cpu_pkg::word_t DATA_MEMORY_SIZE =
        cpu_pkg::word_t'(cpu_pkg::DATA_MEMORY_COUNT) *
        cpu_pkg::word_t'(cpu_pkg::WORD_BYTES);

    localparam cpu_pkg::word_t DATA_MEMORY_LIMIT =
        DATA_MEMORY_BASE + DATA_MEMORY_SIZE;

endpackage

`endif
