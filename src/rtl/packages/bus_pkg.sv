`timescale 1ns/1ps
`ifndef BUS_PKG_SV
`define BUS_PKG_SV

package bus_pkg;

    // ========================================================
    // Bus protocol
    // ========================================================

    typedef enum logic {
        BUS_READ  = 1'b0,
        BUS_WRITE = 1'b1
    } bus_op_e;

    typedef struct packed {
        logic           valid;
        bus_op_e        op;
        cpu_pkg::word_t addr;
        cpu_pkg::word_t wdata;
    } bus_req_s;

    typedef struct packed {
        logic           ready;
        cpu_pkg::word_t rdata;
    } bus_rsp_s;

    // ========================================================
    // DATA MEMORY
    //
    // Logical size:
    //
    //   32 KiB
    //   32768 bytes decimal
    //   0x00008000 bytes hexadecimal
    //
    // Address range:
    //
    //   decimal: 0 .. 32767
    //   hex:     0x00000000 .. 0x00007FFF
    //
    // LIMIT is exclusive:
    //
    //   decimal: 32768
    //   hex:     0x00008000
    // ========================================================

    localparam cpu_pkg::word_t DATA_MEMORY_BASE  = cpu_pkg::word_t'(0);
    localparam cpu_pkg::word_t DATA_MEMORY_SIZE  = cpu_pkg::word_t'(memory_pkg::DATA_MEMORY_COUNT) * cpu_pkg::word_t'(cpu_pkg::WORD_BYTES);
    localparam cpu_pkg::word_t DATA_MEMORY_LIMIT = DATA_MEMORY_BASE + DATA_MEMORY_SIZE;

    // ========================================================
    // GPU MMIO
    //
    // This reserves ADDRESS SPACE. It does not instantiate
    // 4 KiB of RAM.
    //
    // Base:
    //   decimal: 268435456
    //   hex:     0x10000000
    //
    // Size:
    //   decimal: 4096 bytes
    //   hex:     0x00001000
    //
    // Last address:
    //   decimal: 268439551
    //   hex:     0x10000FFF
    //
    // Exclusive limit:
    //   decimal: 268439552
    //   hex:     0x10001000
    // ========================================================

    localparam cpu_pkg::word_t GPU_BASE  = cpu_pkg::word_t'(32'h1000_0000);
    localparam cpu_pkg::word_t GPU_SIZE  = cpu_pkg::word_t'(32'h0000_1000);
    localparam cpu_pkg::word_t GPU_LIMIT = GPU_BASE + GPU_SIZE;

    // ========================================================
    // FUTURE EXTERNAL DDR3
    //
    // Not connected in Stage 1.
    //
    // Physical capacity:
    //   128 MiB
    //   134217728 bytes
    //   1073741824 bits
    //
    // Base:
    //   decimal: 2147483648
    //   hex:     0x80000000
    //
    // Size:
    //   decimal: 134217728
    //   hex:     0x08000000
    //
    // Last address:
    //   decimal: 2281701375
    //   hex:     0x87FFFFFF
    //
    // Exclusive limit:
    //   decimal: 2281701376
    //   hex:     0x88000000
    //
    // These constants reserve the intended future map only.
    // They DO NOT make DDR3 functional.
    // ========================================================

    localparam cpu_pkg::word_t DDR3_BASE  = cpu_pkg::word_t'(32'h8000_0000);
    localparam cpu_pkg::word_t DDR3_SIZE  = cpu_pkg::word_t'(32'h0800_0000);
    localparam cpu_pkg::word_t DDR3_LIMIT = DDR3_BASE + DDR3_SIZE;

endpackage

`endif