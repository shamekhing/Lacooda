`timescale 1ns/1ps
`ifndef GPU_PKG_SV
`define GPU_PKG_SV

// ============================================================
// LACOODA GPU package
//
// Architectural definitions shared by the GPU.
//
// The SoC/bus owns:
//   - absolute GPU base address
//   - address routing
//
// The GPU package owns:
//   - GPU-local MMIO address type
//   - GPU register addresses
//   - GPU configuration structure
//   - GPU status structure
// ============================================================

package gpu_pkg;

    // ========================================================
    // GPU LOCAL MMIO ADDRESS
    // ========================================================
    //
    // GPU receives memory_pkg::GPU_MMIO_BYTES bytes of local
    // MMIO address space from the bus interconnect.
    //
    // bus_interconnect converts:
    //
    //     global CPU address
    //
    // into:
    //
    //     GPU-local byte address
    //
    // before the request reaches the GPU.
    // ========================================================

    localparam int GPU_ADDR_WIDTH =
        $clog2(memory_pkg::GPU_MMIO_BYTES);

    typedef logic [GPU_ADDR_WIDTH-1:0] gpu_addr_t;


    // ========================================================
    // GPU REGISTER MAP
    // ========================================================
    //
    // The LACOODA bus transfers exactly one cpu_pkg::word_t.
    //
    // There are currently no byte-enable signals in bus_req_s.
    //
    // Therefore every GPU MMIO register occupies one complete
    // architectural word.
    //
    // 32-bit CPU:
    //
    //     ID                  0x00
    //     CONTROL             0x04
    //     STATUS              0x08
    //     FRAMEBUFFER_BASE    0x0C
    //     FRAMEBUFFER_WIDTH   0x10
    //     FRAMEBUFFER_HEIGHT  0x14
    //     CLEAR_COLOR         0x18
    //
    // 64-bit CPU:
    //
    //     ID                  0x00
    //     CONTROL             0x08
    //     STATUS              0x10
    //     FRAMEBUFFER_BASE    0x18
    //     FRAMEBUFFER_WIDTH   0x20
    //     FRAMEBUFFER_HEIGHT  0x28
    //     CLEAR_COLOR         0x30
    //
    // Do not hard-code a 4-byte register stride.
    // ========================================================

    typedef enum gpu_addr_t {

        GPU_REG_ID =
            gpu_addr_t'(
                0 * cpu_pkg::WORD_BYTES
            ),

        GPU_REG_CONTROL =
            gpu_addr_t'(
                1 * cpu_pkg::WORD_BYTES
            ),

        GPU_REG_STATUS =
            gpu_addr_t'(
                2 * cpu_pkg::WORD_BYTES
            ),

        GPU_REG_FRAMEBUFFER_BASE =
            gpu_addr_t'(
                3 * cpu_pkg::WORD_BYTES
            ),

        GPU_REG_FRAMEBUFFER_WIDTH =
            gpu_addr_t'(
                4 * cpu_pkg::WORD_BYTES
            ),

        GPU_REG_FRAMEBUFFER_HEIGHT =
            gpu_addr_t'(
                5 * cpu_pkg::WORD_BYTES
            ),

        GPU_REG_CLEAR_COLOR =
            gpu_addr_t'(
                6 * cpu_pkg::WORD_BYTES
            )

    } gpu_reg_addr_e;


    // ========================================================
    // GPU IDENTIFICATION
    // ========================================================

    localparam cpu_pkg::word_t GPU_ID_VALUE =
        cpu_pkg::word_t'(
            32'h4750_5530
        ); // ASCII: "GPU0"


    // ========================================================
    // CPU-WRITABLE GPU CONFIGURATION
    // ========================================================
    //
    // This structure contains the persistent architectural
    // state configured by the CPU.
    //
    // gpu_register owns these registers.
    //
    // Later:
    //
    //     gpu_register
    //          │
    //          │ gpu_config_s
    //          ▼
    //       gpu_core
    //
    // Keeping them together avoids another forest of unrelated
    // wires between GPU modules.
    // ========================================================

    typedef struct packed {

        cpu_pkg::word_t control;

        cpu_pkg::word_t framebuffer_base;

        cpu_pkg::word_t framebuffer_width;

        cpu_pkg::word_t framebuffer_height;

        cpu_pkg::word_t clear_color;

    } gpu_config_s;


    // ========================================================
    // GPU STATUS
    // ========================================================
    //
    // STATUS is CPU-readable but not CPU-writable.
    //
    // Fixed 32-bit layout:
    //
    //     bit 0 : enabled
    //     bit 1 : idle
    //     bit 2 : busy
    //     bit 3 : error
    //     bit 4 : command_done
    //     bit 5 : framebuffer_valid
    //     bit 6 : display_active
    //
    //     bits 31:7 reserved
    //
    // Later gpu_core will produce most of this structure.
    // ========================================================

    typedef struct packed {

        logic [24:0] reserved;

        logic display_active;

        logic framebuffer_valid;

        logic command_done;

        logic error;

        logic busy;

        logic idle;

        logic enabled;

    } gpu_status_s;


    localparam int GPU_STATUS_WIDTH =
        $bits(gpu_status_s);

endpackage

`endif