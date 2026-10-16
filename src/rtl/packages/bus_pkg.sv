`timescale 1ns/1ps
`ifndef BUS_PKG_SV
`define BUS_PKG_SV

// ============================================================
// LACOODA NATIVE BUS AND SYSTEM MEMORY MAP
// ============================================================
//
// Stage 2 responsibilities:
//
//   1. Preserve the Stage 1 bus request/response protocol.
//   2. Define the complete CPU-visible address map.
//   3. Identify mapped and reserved hardware regions.
//   4. Provide reusable address classification functions.
//   5. Guarantee that address ranges do not overlap.
//
// The bus is currently:
//   - 32-bit, using cpu_pkg::word_t
//   - Byte addressed
//   - Word aligned
//   - Single outstanding transaction per master
//
// A transaction completes at the rising clock edge when:
//
//     request.valid && response.ready
//
// Stage 2 adds no physical DDR3, TPU, DMA or SD controller.
//
// Reserved regions must return a bus error until their
// hardware is connected.
// ============================================================

package bus_pkg;

    // ========================================================
    // BUS OPERATIONS
    // ========================================================

    typedef enum logic {
        BUS_READ  = 1'b0,
        BUS_WRITE = 1'b1
    } bus_op_e;

    // ========================================================
    // BYTE WRITE STROBES
    // ========================================================
    //
    // One bit per byte of the native CPU word.
    //
    // For a 32-bit word:
    //
    //   wstrb[0] controls wdata[ 7: 0]
    //   wstrb[1] controls wdata[15: 8]
    //   wstrb[2] controls wdata[23:16]
    //   wstrb[3] controls wdata[31:24]
    // ========================================================

    typedef logic [cpu_pkg::WORD_BYTES-1:0] bus_strb_t;

    localparam bus_strb_t BUS_STRB_NONE = '0;
    localparam bus_strb_t BUS_STRB_ALL  = '1;

    // ========================================================
    // BUS REQUEST
    // ========================================================

    typedef struct packed {
        logic           valid;
        bus_op_e        op;
        cpu_pkg::word_t addr;
        cpu_pkg::word_t wdata;
        bus_strb_t      wstrb;
    } bus_req_s;

    // ========================================================
    // BUS RESPONSE
    // ========================================================

    typedef struct packed {
        logic           ready;
        cpu_pkg::word_t rdata;
        logic           error;
    } bus_rsp_s;

    // ========================================================
    // DEVICE IDENTIFIERS
    // ========================================================
    //
    // These identify global address regions.
    //
    // A device identifier does not imply that the device
    // has been implemented or connected.
    //
    // DEVICE_NONE represents an unmapped address.
    // ========================================================

    typedef enum logic [3:0] {
        DEVICE_NONE        = 4'h0,
        DEVICE_DATA_RAM    = 4'h1,
        DEVICE_GPU_MMIO    = 4'h2,
        DEVICE_TPU_MMIO    = 4'h3,
        DEVICE_DMA_MMIO    = 4'h4,
        DEVICE_SD_MMIO     = 4'h5,
        DEVICE_SYSTEM_MMIO = 4'h6,
        DEVICE_DDR3        = 4'h7
    } bus_device_e;

    // ========================================================
    // ADDRESS DECODE RESULT
    // ========================================================
    //
    // device:
    //   Identifies the region containing the address.
    //
    // local_addr:
    //   Address relative to the selected region base.
    //
    // mapped:
    //   Address belongs to a defined address region.
    //
    // implemented:
    //   Stage 2 interconnect has a connected slave for
    //   the selected region.
    //
    // A reserved region is mapped but not implemented.
    // ========================================================

    typedef struct packed {
        bus_device_e     device;
        cpu_pkg::word_t local_addr;
        logic           mapped;
        logic           implemented;
    } bus_decode_s;

    // ========================================================
    // INTERNAL DATA RAM
    // ========================================================
    //
    // Base:  0x00000000
    // Size:  32 KiB
    // Limit: 0x00008000, exclusive
    //
    // The capacity is inherited from memory_pkg.
    // ========================================================

    localparam cpu_pkg::word_t DATA_RAM_BASE =
        cpu_pkg::word_t'(32'h0000_0000);

    localparam cpu_pkg::word_t DATA_RAM_SIZE =
        cpu_pkg::word_t'(memory_pkg::DATA_RAM_WORDS)
        * cpu_pkg::word_t'(cpu_pkg::WORD_BYTES);

    localparam cpu_pkg::word_t DATA_RAM_LIMIT =
        DATA_RAM_BASE + DATA_RAM_SIZE;

    // ========================================================
    // GPU MMIO
    // ========================================================
    //
    // Base:  0x10000000
    // Size:  4 KiB
    //
    // This is GPU register address space.
    // It is not framebuffer storage.
    // ========================================================

    localparam cpu_pkg::word_t GPU_BASE =
        cpu_pkg::word_t'(32'h1000_0000);

    localparam cpu_pkg::word_t GPU_SIZE =
        cpu_pkg::word_t'(memory_pkg::GPU_MMIO_BYTES);

    localparam cpu_pkg::word_t GPU_LIMIT =
        GPU_BASE + GPU_SIZE;

    // ========================================================
    // TPU MMIO — RESERVED
    // ========================================================

    localparam cpu_pkg::word_t TPU_BASE =
        cpu_pkg::word_t'(32'h1000_1000);

    localparam cpu_pkg::word_t TPU_SIZE =
        cpu_pkg::word_t'(32'h0000_1000);

    localparam cpu_pkg::word_t TPU_LIMIT =
        TPU_BASE + TPU_SIZE;

    // ========================================================
    // DMA MMIO — RESERVED
    // ========================================================

    localparam cpu_pkg::word_t DMA_BASE =
        cpu_pkg::word_t'(32'h1000_2000);

    localparam cpu_pkg::word_t DMA_SIZE =
        cpu_pkg::word_t'(32'h0000_1000);

    localparam cpu_pkg::word_t DMA_LIMIT =
        DMA_BASE + DMA_SIZE;

    // ========================================================
    // MICROSD CONTROLLER MMIO — RESERVED
    // ========================================================
    //
    // This address region will contain controller registers.
    //
    // It does not represent the capacity of the SD card.
    // ========================================================

    localparam cpu_pkg::word_t SD_BASE =
        cpu_pkg::word_t'(32'h1000_3000);

    localparam cpu_pkg::word_t SD_SIZE =
        cpu_pkg::word_t'(32'h0000_1000);

    localparam cpu_pkg::word_t SD_LIMIT =
        SD_BASE + SD_SIZE;

    // ========================================================
    // SYSTEM CONTROL MMIO — RESERVED
    // ========================================================

    localparam cpu_pkg::word_t SYSTEM_BASE =
        cpu_pkg::word_t'(32'h1000_4000);

    localparam cpu_pkg::word_t SYSTEM_SIZE =
        cpu_pkg::word_t'(32'h0000_1000);

    localparam cpu_pkg::word_t SYSTEM_LIMIT =
        SYSTEM_BASE + SYSTEM_SIZE;

    // ========================================================
    // EXTERNAL DDR3 — RESERVED
    // ========================================================
    //
    // Base:  0x80000000
    // Size:  128 MiB
    // Limit: 0x88000000, exclusive
    //
    // Physical DDR3 integration belongs to Stage 3.
    // ========================================================

    localparam cpu_pkg::word_t DDR3_BASE =
        cpu_pkg::word_t'(32'h8000_0000);

    localparam cpu_pkg::word_t DDR3_SIZE =
        cpu_pkg::word_t'(32'h0800_0000);

    localparam cpu_pkg::word_t DDR3_LIMIT =
        DDR3_BASE + DDR3_SIZE;

    // ========================================================
    // BUS HELPERS
    // ========================================================

    function automatic logic bus_is_aligned(
        input cpu_pkg::word_t addr
    );

        return (addr % cpu_pkg::WORD_BYTES) == 0;

    endfunction

    function automatic logic bus_has_write_bytes(
        input bus_strb_t wstrb
    );

        return |wstrb;

    endfunction

    // ========================================================
    // SUCCESSFUL RESPONSE
    // ========================================================

    function automatic bus_rsp_s bus_success(
        input cpu_pkg::word_t rdata
    );

        bus_rsp_s rsp;

        rsp = '0;

        rsp.ready = 1'b1;
        rsp.rdata = rdata;
        rsp.error = 1'b0;

        return rsp;

    endfunction

    // ========================================================
    // FAILED RESPONSE
    // ========================================================

    function automatic bus_rsp_s bus_failure();

        bus_rsp_s rsp;

        rsp = '0;

        rsp.ready = 1'b1;
        rsp.rdata = '0;
        rsp.error = 1'b1;

        return rsp;

    endfunction

    // ========================================================
    // REGION MEMBERSHIP
    // ========================================================
    //
    // All regions use inclusive base and exclusive limit:
    //
    //     base <= addr < limit
    //
    // Unsigned cpu_pkg::word_t comparisons are used.
    // ========================================================

    function automatic logic bus_in_region(
        input cpu_pkg::word_t addr,
        input cpu_pkg::word_t region_base,
        input cpu_pkg::word_t region_limit
    );

        return
            (addr >= region_base) &&
            (addr < region_limit);

    endfunction

    // ========================================================
    // GLOBAL ADDRESS DECODER
    // ========================================================
    //
    // This function is the single authoritative classifier
    // of the Stage 2 CPU-visible data address space.
    //
    // Only DATA_RAM and GPU_MMIO are currently implemented.
    //
    // TPU, DMA, SD, SYSTEM, and DDR3 are reserved.
    //
    // The surrounding gaps remain completely unmapped.
    //
    // No address alignment check is performed here.
    // Alignment is validated separately by the interconnect.
    // ========================================================

    function automatic bus_decode_s bus_decode_address(
        input cpu_pkg::word_t addr
    );

        bus_decode_s result;

        result = '0;
        result.device = DEVICE_NONE;

        if (
            bus_in_region(
                addr,
                DATA_RAM_BASE,
                DATA_RAM_LIMIT
            )
        ) begin

            result.device      = DEVICE_DATA_RAM;
            result.local_addr  = addr - DATA_RAM_BASE;
            result.mapped      = 1'b1;
            result.implemented = 1'b1;

        end else if (
            bus_in_region(
                addr,
                GPU_BASE,
                GPU_LIMIT
            )
        ) begin

            result.device      = DEVICE_GPU_MMIO;
            result.local_addr  = addr - GPU_BASE;
            result.mapped      = 1'b1;
            result.implemented = 1'b1;

        end else if (
            bus_in_region(
                addr,
                TPU_BASE,
                TPU_LIMIT
            )
        ) begin

            result.device      = DEVICE_TPU_MMIO;
            result.local_addr  = addr - TPU_BASE;
            result.mapped      = 1'b1;
            result.implemented = 1'b0;

        end else if (
            bus_in_region(
                addr,
                DMA_BASE,
                DMA_LIMIT
            )
        ) begin

            result.device      = DEVICE_DMA_MMIO;
            result.local_addr  = addr - DMA_BASE;
            result.mapped      = 1'b1;
            result.implemented = 1'b0;

        end else if (
            bus_in_region(
                addr,
                SD_BASE,
                SD_LIMIT
            )
        ) begin

            result.device      = DEVICE_SD_MMIO;
            result.local_addr  = addr - SD_BASE;
            result.mapped      = 1'b1;
            result.implemented = 1'b0;

        end else if (
            bus_in_region(
                addr,
                SYSTEM_BASE,
                SYSTEM_LIMIT
            )
        ) begin

            result.device      = DEVICE_SYSTEM_MMIO;
            result.local_addr  = addr - SYSTEM_BASE;
            result.mapped      = 1'b1;
            result.implemented = 1'b0;

        end else if (
            bus_in_region(
                addr,
                DDR3_BASE,
                DDR3_LIMIT
            )
        ) begin

            result.device      = DEVICE_DDR3;
            result.local_addr  = addr - DDR3_BASE;
            result.mapped      = 1'b1;
            result.implemented = 1'b0;

        end

        return result;

    endfunction

    // ========================================================
    // ADDRESS-MAP CONFIGURATION VALIDATION
    // ========================================================
    //
    // Every allocated region must:
    //
    //   - Have nonzero size.
    //   - Have a base aligned to its size.
    //   - Have a limit greater than its base.
    //   - Not overlap another allocated region.
    //
    // The current addresses are ordered:
    //
    //   DATA_RAM < GPU < TPU < DMA < SD < SYSTEM < DDR3
    //
    // Therefore validating successive exclusive limits
    // establishes non-overlap for the entire map.
    //
    // Intended for simulation/elaboration checks.
    // ========================================================

    function automatic bit bus_validate_memory_map();

        if (
            (DATA_RAM_SIZE == 0) ||
            (GPU_SIZE == 0) ||
            (TPU_SIZE == 0) ||
            (DMA_SIZE == 0) ||
            (SD_SIZE == 0) ||
            (SYSTEM_SIZE == 0) ||
            (DDR3_SIZE == 0)
        ) begin

            $fatal(
                1,
                "LACOODA memory map contains a zero-size region"
            );

        end

        if (
            ((DATA_RAM_BASE % DATA_RAM_SIZE) != 0) ||
            ((GPU_BASE % GPU_SIZE) != 0) ||
            ((TPU_BASE % TPU_SIZE) != 0) ||
            ((DMA_BASE % DMA_SIZE) != 0) ||
            ((SD_BASE % SD_SIZE) != 0) ||
            ((SYSTEM_BASE % SYSTEM_SIZE) != 0) ||
            ((DDR3_BASE % DDR3_SIZE) != 0)
        ) begin

            $fatal(
                1,
                "LACOODA memory map has an incorrectly aligned region"
            );

        end

        if (
            !(DATA_RAM_BASE < DATA_RAM_LIMIT) ||
            !(GPU_BASE < GPU_LIMIT) ||
            !(TPU_BASE < TPU_LIMIT) ||
            !(DMA_BASE < DMA_LIMIT) ||
            !(SD_BASE < SD_LIMIT) ||
            !(SYSTEM_BASE < SYSTEM_LIMIT) ||
            !(DDR3_BASE < DDR3_LIMIT)
        ) begin

            $fatal(
                1,
                "LACOODA memory map contains an invalid range"
            );

        end

        if (
            !(DATA_RAM_LIMIT <= GPU_BASE) ||
            !(GPU_LIMIT <= TPU_BASE) ||
            !(TPU_LIMIT <= DMA_BASE) ||
            !(DMA_LIMIT <= SD_BASE) ||
            !(SD_LIMIT <= SYSTEM_BASE) ||
            !(SYSTEM_LIMIT <= DDR3_BASE)
        ) begin

            $fatal(
                1,
                "LACOODA memory map contains overlapping regions"
            );

        end

        return 1'b1;

    endfunction

endpackage

`endif