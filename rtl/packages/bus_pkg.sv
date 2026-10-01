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

    import cpu_pkg::*;

    // local data RAM occupies the first DATA_MEMORY_COUNT words
    // of the data address space. Future MMIO/DDR regions can be added here
    // without changing the CPU interface or instruction set.
    localparam reg_t DATA_MEMORY_BASE = reg_t'(0);

    // Perform the size calculation at the architectural data/address width.
    // Using SystemVerilog `int` here would make the multiplication 32-bit
    // signed arithmetic and could wrap a valid large memory map back to zero.
    // The region is sized from the data memory's own parameter group.
    localparam reg_t DATA_MEMORY_SIZE_BYTES =
        reg_t'(DATA_MEMORY_COUNT) * reg_t'(DATA_MEMORY_BYTES);

    localparam reg_t DATA_MEMORY_LIMIT =
        DATA_MEMORY_BASE + DATA_MEMORY_SIZE_BYTES;

endpackage

`endif
