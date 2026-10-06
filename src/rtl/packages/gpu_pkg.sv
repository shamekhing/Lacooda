`timescale 1ns/1ps
`ifndef GPU_PKG_SV
`define GPU_PKG_SV

// ============================================================
// LACOODA GPU package
//
// GPU architectural definitions.
//
// The GPU MMIO allocation SIZE is owned by memory_pkg.
//
// The GPU package derives its local address width from that
// allocation and owns the register offsets inside the region.
// ============================================================

package gpu_pkg;

    // ========================================================
    // GPU local address
    // ========================================================
    //
    // GPU_MMIO_BYTES = 4096
    //
    // clog2(4096) = 12
    //
    // Therefore:
    //
    //   gpu_addr_t = logic [11:0]
    //
    // Valid local address space:
    //
    //   0x000 .. 0xFFF
    //
    // Do NOT hard-code 12 elsewhere.
    // ========================================================

    localparam int GPU_ADDR_WIDTH =
        $clog2(memory_pkg::GPU_MMIO_BYTES);

    typedef logic [GPU_ADDR_WIDTH-1:0] gpu_addr_t;

    // ========================================================
    // GPU MMIO register offsets
    // ========================================================
    //
    // These are GPU-LOCAL addresses.
    //
    // The underlying width is gpu_addr_t.
    // ========================================================

    typedef enum gpu_addr_t {
        GPU_REG_ID                 = 'h000,
        GPU_REG_CONTROL            = 'h004,
        GPU_REG_STATUS             = 'h008,
        GPU_REG_FRAMEBUFFER_BASE   = 'h00C,
        GPU_REG_FRAMEBUFFER_WIDTH  = 'h010,
        GPU_REG_FRAMEBUFFER_HEIGHT = 'h014,
        GPU_REG_CLEAR_COLOR        = 'h018
    } gpu_addr_e;

    // ========================================================
    // GPU identification
    // ========================================================

    localparam cpu_pkg::word_t GPU_ID_VALUE =
        cpu_pkg::word_t'(32'h4750_5530); // GPU0 in ASCII

    // ========================================================
    // GPU internal state
    // ========================================================
    //
    // Unlike the register addresses, this needs a named type
    // because GPU logic actually declares signals of this type.
    // ========================================================

    typedef enum logic [1:0] {
        GPU_IDLE,
        GPU_BUSY,
        GPU_ERROR
    } gpu_state_e;

    // ========================================================
    // GPU STATUS register
    // ========================================================
    //
    // Fixed 32-bit architectural layout:
    //
    // 31                         7 6 5 4 3 2 1 0
    // +---------------------------+-+-+-+-+-+-+-+
    // |         RESERVED          |D|F|C|E|B|I|N|
    // +---------------------------+-+-+-+-+-+-+-+
    //
    // N = enabled
    // I = idle
    // B = busy
    // E = error
    // C = command_done
    // F = framebuffer_valid
    // D = display_active
    //
    // Packed structs are declared MSB -> LSB, therefore
    // enabled is the least significant bit.
    // ========================================================

    typedef struct packed {
        logic [24:0] reserved;
        logic        display_active;
        logic        framebuffer_valid;
        logic        command_done;
        logic        error;
        logic        busy;
        logic        idle;
        logic        enabled;
    } gpu_status_s;

    localparam int GPU_STATUS_WIDTH =
        $bits(gpu_status_s);

endpackage

`endif