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
    //     ID                  0x00
    //     CONTROL             0x04
    //     STATUS              0x08
    //     FRAMEBUFFER_BASE    0x0C
    //     FRAMEBUFFER_WIDTH   0x10
    //     FRAMEBUFFER_HEIGHT  0x14
    //     CLEAR_COLOR         0x18
    //
    // The register stride is one 32-bit word.
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

    // ============================================================
    // PIXEL FORMAT
    // ============================================================
    //
    // Initial GPU pixel format:
    //
    //     32-bit RGBA
    //
    // Memory representation:
    //
    //     [31:24] R
    //     [23:16] G
    //     [15:8]  B
    //     [7:0]   A
    //
    // Keeping the pixel width fixed initially makes framebuffer
    // addressing deterministic and simple.
    // ============================================================

    localparam int GPU_PIXEL_WIDTH = 32;
    localparam int GPU_PIXEL_BYTES = GPU_PIXEL_WIDTH / 8;

    typedef logic [GPU_PIXEL_WIDTH-1:0] gpu_pixel_t;


    // ============================================================
    // GPU COORDINATE
    // ============================================================

    localparam int GPU_COORD_WIDTH = 16;

    typedef logic [GPU_COORD_WIDTH-1:0] gpu_coord_t;


    // ============================================================
    // PIXEL REQUEST
    // ============================================================
    //
    // Internal request sent to the pixel engine.
    //
    // This is NOT a bus transaction.
    // It describes a graphics operation.
    // ============================================================

    typedef struct packed {

        logic       valid;

        gpu_coord_t x;
        gpu_coord_t y;

        gpu_pixel_t color;

    } gpu_pixel_req_s;


    // ============================================================
    // PIXEL WRITE
    // ============================================================
    //
    // Result of pixel address generation.
    //
    // The future GPU memory interface converts this into the
    // actual LACOODA bus transaction.
    // ============================================================

    typedef struct packed {

        logic valid;

        cpu_pkg::word_t addr;
        gpu_pixel_t     data;

    } gpu_pixel_write_s;

    // ============================================================
    // GPU MEMORY REQUEST
    // ============================================================
    //
    // Internal GPU request for one native LACOODA memory word.
    //
    // Graphics engines do not directly construct bus_req_s.
    // They submit memory operations through this interface.
    //
    // Address is a byte address.
    // ============================================================

    typedef struct packed {

        logic valid;

        bus_pkg::bus_op_e op;

        cpu_pkg::word_t addr;
        cpu_pkg::word_t wdata;

    } gpu_mem_req_s;


    // ============================================================
    // GPU MEMORY RESPONSE
    // ============================================================

    typedef struct packed {

        logic ready;

        cpu_pkg::word_t rdata;

    } gpu_mem_rsp_s;

endpackage

`endif
