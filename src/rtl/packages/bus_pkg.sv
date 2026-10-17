`timescale 1ns/1ps
`ifndef BUS_PKG_SV
`define BUS_PKG_SV

// ============================================================
// LACOODA NATIVE BUS PACKAGE — STAGE 3
// ============================================================
//
// Single source of truth for:
//   - Native bus operations
//   - Request and response structures
//   - Byte-write strobes
//   - Global memory-map constants
//   - Address classification
//   - Response construction
//
// Bus conventions:
//   - 32-bit native words
//   - Byte-addressed locations
//   - Word-aligned native accesses
//   - One outstanding transaction per master
//
// Completion occurs on a rising clock edge with:
//   request.valid && response.ready
//
// A master must hold its request stable until completion.
//
// No $fatal, $display, or other simulation tasks appear
// in this synthesizable package.
// ============================================================

package bus_pkg;

    // ========================================================
    // OPERATIONS
    // ========================================================

    typedef enum logic {
        BUS_READ  = 1'b0,
        BUS_WRITE = 1'b1
    } bus_op_e;

    // ========================================================
    // WRITE STROBES
    // ========================================================
    //
    // Strobe bit n enables byte n of wdata.
    // For a 32-bit word, there are four strobe bits.
    // ========================================================

    typedef logic [cpu_pkg::WORD_BYTES-1:0] bus_strb_t;

    localparam bus_strb_t BUS_STRB_NONE = '0;
    localparam bus_strb_t BUS_STRB_ALL  = '1;

    // ========================================================
    // REQUEST AND RESPONSE
    // ========================================================

    typedef struct packed {
        logic           valid;
        bus_op_e        op;
        cpu_pkg::word_t addr;
        cpu_pkg::word_t wdata;
        bus_strb_t      wstrb;
    } bus_req_s;

    typedef struct packed {
        logic           ready;
        cpu_pkg::word_t rdata;
        logic           error;
    } bus_rsp_s;

    // ========================================================
    // DEVICE IDENTIFIERS
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
    // mapped:
    //   Address belongs to an allocated region.
    //
    // implemented:
    //   A bus slave is connected to that region.
    //
    // DDR3 is implemented at the native-bus boundary
    // by the Stage 3 bridge.
    //
    // This does not imply that physical DDR3 is ready.
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
    // MICROSD MMIO — RESERVED
    // ========================================================

    localparam cpu_pkg::word_t SD_BASE =
        cpu_pkg::word_t'(32'h1000_3000);

    localparam cpu_pkg::word_t SD_SIZE =
        cpu_pkg::word_t'(32'h0000_1000);

    localparam cpu_pkg::word_t SD_LIMIT =
        SD_BASE + SD_SIZE;

    // ========================================================
    // SYSTEM MMIO — RESERVED
    // ========================================================

    localparam cpu_pkg::word_t SYSTEM_BASE =
        cpu_pkg::word_t'(32'h1000_4000);

    localparam cpu_pkg::word_t SYSTEM_SIZE =
        cpu_pkg::word_t'(32'h0000_1000);

    localparam cpu_pkg::word_t SYSTEM_LIMIT =
        SYSTEM_BASE + SYSTEM_SIZE;

    // ========================================================
    // EXTERNAL DDR3 REGION
    // ========================================================
    //
    // The allocated CPU-visible region is 128 MiB.
    //
    // Global base:  0x80000000
    // Global limit: 0x88000000 (exclusive)
    //
    // The interconnect subtracts DDR3_BASE before
    // forwarding requests to the bridge.
    // ========================================================

    localparam cpu_pkg::word_t DDR3_BASE =
        cpu_pkg::word_t'(32'h8000_0000);

    localparam cpu_pkg::word_t DDR3_SIZE =
        cpu_pkg::word_t'(32'h0800_0000);

    localparam cpu_pkg::word_t DDR3_LIMIT =
        DDR3_BASE + DDR3_SIZE;

    // ========================================================
    // ALIGNMENT
    // ========================================================

    function automatic logic bus_is_aligned(
        input cpu_pkg::word_t addr
    );

        return (addr % cpu_pkg::WORD_BYTES) == 0;

    endfunction

    // ========================================================
    // WRITE BYTE VALIDITY
    // ========================================================

    function automatic logic bus_has_write_bytes(
        input bus_strb_t wstrb
    );

        return |wstrb;

    endfunction

    // ========================================================
    // SUCCESS RESPONSE
    // ========================================================

    function automatic bus_rsp_s bus_success(
        input cpu_pkg::word_t rdata
    );

        bus_rsp_s result;

        result = '0;
        result.ready = 1'b1;
        result.rdata = rdata;
        result.error = 1'b0;

        return result;

    endfunction

    // ========================================================
    // ERROR RESPONSE
    // ========================================================

    function automatic bus_rsp_s bus_failure();

        bus_rsp_s result;

        result = '0;
        result.ready = 1'b1;
        result.rdata = '0;
        result.error = 1'b1;

        return result;

    endfunction

    // ========================================================
    // REGION MEMBERSHIP
    // ========================================================
    //
    // A region includes its base and excludes its limit.
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
    // This function classifies the CPU-visible data
    // address space.
    //
    // Reserved peripheral regions are mapped but do not
    // have connected bus slaves.
    //
    // DDR3 has a bridge connected in Stage 3.
    //
    // All outputs receive default values first.
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
            result.implemented = 1'b1;

        end

        return result;

    endfunction

    // ========================================================
    // SYNTHESIZABLE CONFIGURATION VALIDATION
    // ========================================================
    //
    // Returns 1 if the static memory map is valid.
    //
    // This function has no side effects.
    //
    // Any testbench that calls it may report a failure
    // using simulation-only system tasks.
    // ========================================================

    function automatic bit bus_validate_memory_map();

        bit sizes_valid;
        bit alignment_valid;
        bit limits_valid;
        bit no_overlap;

        sizes_valid =
            (DATA_RAM_SIZE != 0) &&
            (GPU_SIZE != 0) &&
            (TPU_SIZE != 0) &&
            (DMA_SIZE != 0) &&
            (SD_SIZE != 0) &&
            (SYSTEM_SIZE != 0) &&
            (DDR3_SIZE != 0);

        // Avoid evaluating modulus with an invalid size.
        // All sizes are fixed compile-time constants.

        alignment_valid = 1'b0;

        if (sizes_valid) begin

            alignment_valid =
                ((DATA_RAM_BASE % DATA_RAM_SIZE) == 0) &&
                ((GPU_BASE % GPU_SIZE) == 0) &&
                ((TPU_BASE % TPU_SIZE) == 0) &&
                ((DMA_BASE % DMA_SIZE) == 0) &&
                ((SD_BASE % SD_SIZE) == 0) &&
                ((SYSTEM_BASE % SYSTEM_SIZE) == 0) &&
                ((DDR3_BASE % DDR3_SIZE) == 0);

        end

        limits_valid =
            (DATA_RAM_BASE < DATA_RAM_LIMIT) &&
            (GPU_BASE < GPU_LIMIT) &&
            (TPU_BASE < TPU_LIMIT) &&
            (DMA_BASE < DMA_LIMIT) &&
            (SD_BASE < SD_LIMIT) &&
            (SYSTEM_BASE < SYSTEM_LIMIT) &&
            (DDR3_BASE < DDR3_LIMIT);

        no_overlap =
            (DATA_RAM_LIMIT <= GPU_BASE) &&
            (GPU_LIMIT <= TPU_BASE) &&
            (TPU_LIMIT <= DMA_BASE) &&
            (DMA_LIMIT <= SD_BASE) &&
            (SD_LIMIT <= SYSTEM_BASE) &&
            (SYSTEM_LIMIT <= DDR3_BASE);

        return
            sizes_valid &&
            alignment_valid &&
            limits_valid &&
            no_overlap;

    endfunction

endpackage

`endif