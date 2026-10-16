`timescale 1ns/1ps
`ifndef BUS_PKG_SV
`define BUS_PKG_SV

// ============================================================
// LACOODA NATIVE BUS PACKAGE
// ============================================================
//
// PURPOSE
//
//   Define the native LACOODA bus protocol and the global
//   CPU-visible memory address map.
//
// ARCHITECTURE
//
//   Data width:       cpu_pkg::WORD_WIDTH
//   Address width:    cpu_pkg::WORD_WIDTH
//   Addressing:       Byte addressed
//   Alignment:        Native word aligned
//   Transactions:     One outstanding transaction per master
//
// HANDSHAKE
//
//   A transaction completes on a rising clock edge when:
//
//       request.valid && response.ready
//
//   The requesting master must hold the request stable until
//   that handshake occurs.
//
// SYNTHESIS
//
//   This package contains no simulation system tasks.
//
//   Memory-map validation returns a Boolean value.
//   Testbenches are responsible for reporting validation
//   failures using $fatal.
//
// MEMORY REGIONS
//
//   Internal RAM:  0x00000000 - 0x00007FFF
//   GPU MMIO:      0x10000000 - 0x10000FFF
//   TPU MMIO:      0x10001000 - 0x10001FFF
//   DMA MMIO:      0x10002000 - 0x10002FFF
//   SD MMIO:       0x10003000 - 0x10003FFF
//   System MMIO:   0x10004000 - 0x10004FFF
//   DDR3:          0x80000000 - 0x87FFFFFF
//
// DDR3 NOTE
//
//   Stage 3 introduces a DDR3 bus bridge.
//
//   The bridge being present does not guarantee that the
//   physical DDR3 controller is initialized or available.
//
//   Physical memory readiness is a runtime condition
//   handled by the DDR3 bridge.
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
    // Each strobe bit controls one byte of the data word.
    //
    // For a 32-bit data word:
    //
    //   wstrb[0] -> wdata[ 7: 0]
    //   wstrb[1] -> wdata[15: 8]
    //   wstrb[2] -> wdata[23:16]
    //   wstrb[3] -> wdata[31:24]
    //
    // BUS_STRB_NONE:
    //   No write bytes enabled.
    //
    // BUS_STRB_ALL:
    //   All write bytes enabled.
    // ========================================================

    typedef logic [cpu_pkg::WORD_BYTES-1:0] bus_strb_t;

    localparam bus_strb_t BUS_STRB_NONE = '0;
    localparam bus_strb_t BUS_STRB_ALL  = '1;

    // ========================================================
    // BUS REQUEST
    // ========================================================
    //
    // valid:
    //   A transaction is being requested.
    //
    // op:
    //   Read or write operation.
    //
    // addr:
    //   Byte address.
    //
    // wdata:
    //   Data supplied by the requesting master.
    //
    // wstrb:
    //   Write-byte enables.
    //
    // Read transactions should use BUS_STRB_NONE.
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
    //
    // ready:
    //   The selected slave has completed the transaction.
    //
    // rdata:
    //   Data returned by a successful read.
    //
    // error:
    //   The transaction completed unsuccessfully.
    //
    // Error responses must also assert ready so the
    // requesting master does not wait indefinitely.
    // ========================================================

    typedef struct packed {

        logic           ready;

        cpu_pkg::word_t rdata;

        logic           error;

    } bus_rsp_s;

    // ========================================================
    // GLOBAL DEVICE IDENTIFIERS
    // ========================================================
    //
    // These values identify address regions.
    //
    // DEVICE_NONE:
    //   Address is not assigned to a device.
    //
    // Other identifiers:
    //   Address belongs to the corresponding region.
    //
    // An assigned region does not necessarily have
    // physically operational hardware attached.
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
    //   Identifies the address region.
    //
    // local_addr:
    //   Byte address relative to the region base.
    //
    // mapped:
    //   The address belongs to a defined region.
    //
    // implemented:
    //   The current architecture provides a bus-accessible
    //   slave for this region.
    //
    // Stage 3 provides a DDR3 bridge.
    //
    // Physical DDR3 availability is determined separately.
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
    // Base: 0x00000000
    //
    // Size is derived from memory_pkg to avoid duplicating
    // the RAM capacity definition.
    //
    // The upper limit is exclusive.
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
    // GPU control and status registers.
    //
    // This region does not contain framebuffer pixels.
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
    // This region is for controller registers.
    //
    // SD card storage capacity is not directly represented
    // by the size of this MMIO region.
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
    // EXTERNAL DDR3
    // ========================================================
    //
    // CPU-visible memory allocation:
    //
    //   Base:  0x80000000
    //   Size:  128 MiB
    //   Limit: 0x88000000 (exclusive)
    //
    // The DDR3 bridge receives local addresses:
    //
    //   local_addr = global_addr - DDR3_BASE
    // ========================================================

    localparam cpu_pkg::word_t DDR3_BASE =
        cpu_pkg::word_t'(32'h8000_0000);

    localparam cpu_pkg::word_t DDR3_SIZE =
        cpu_pkg::word_t'(32'h0800_0000);

    localparam cpu_pkg::word_t DDR3_LIMIT =
        DDR3_BASE + DDR3_SIZE;

    // ========================================================
    // ADDRESS ALIGNMENT
    // ========================================================
    //
    // Returns 1 when the byte address is aligned to the
    // native bus word size.
    //
    // The current CPU uses 32-bit words, so valid word
    // addresses are multiples of four.
    // ========================================================

    function automatic logic bus_is_aligned(
        input cpu_pkg::word_t addr
    );

        return
            (addr % cpu_pkg::WORD_BYTES) == 0;

    endfunction

    // ========================================================
    // WRITE-STROBE VALIDITY
    // ========================================================
    //
    // Returns 1 when at least one byte is selected.
    //
    // This function does not distinguish reads from writes.
    // ========================================================

    function automatic logic bus_has_write_bytes(
        input bus_strb_t wstrb
    );

        return |wstrb;

    endfunction

    // ========================================================
    // SUCCESSFUL RESPONSE
    // ========================================================
    //
    // Generates a completed, non-error response.
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
    //
    // Generates a completed transaction with an error.
    //
    // ready must be asserted even on failure.
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
    // Address ranges use:
    //
    //   base <= addr < limit
    //
    // The limit is exclusive.
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
    // GLOBAL ADDRESS CLASSIFICATION
    // ========================================================
    //
    // Returns the matching device and peripheral-local
    // byte address.
    //
    // Region order follows ascending global addresses.
    //
    // Reserved devices are recognized but marked as
    // unimplemented.
    //
    // DDR3 is marked implemented because Stage 3 introduces
    // a bus bridge. The bridge itself may still reject access
    // when its backend is unavailable.
    //
    // Alignment is checked by the interconnect, not here.
    // ========================================================

    function automatic bus_decode_s bus_decode_address(
        input cpu_pkg::word_t addr
    );

        bus_decode_s result;

        result = '0;

        result.device = DEVICE_NONE;

        // ----------------------------------------------------
        // INTERNAL DATA RAM
        // ----------------------------------------------------

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

        end

        // ----------------------------------------------------
        // GPU MMIO
        // ----------------------------------------------------

        else if (
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

        end

        // ----------------------------------------------------
        // TPU MMIO — RESERVED
        // ----------------------------------------------------

        else if (
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

        end

        // ----------------------------------------------------
        // DMA MMIO — RESERVED
        // ----------------------------------------------------

        else if (
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

        end

        // ----------------------------------------------------
        // MICROSD MMIO — RESERVED
        // ----------------------------------------------------

        else if (
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

        end

        // ----------------------------------------------------
        // SYSTEM CONTROL MMIO — RESERVED
        // ----------------------------------------------------

        else if (
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

        end

        // ----------------------------------------------------
        // EXTERNAL DDR3 — STAGE 3 BRIDGE
        // ----------------------------------------------------

        else if (
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
    // MEMORY-MAP CONFIGURATION VALIDATION
    // ========================================================
    //
    // PURE COMBINATIONAL FUNCTION
    //
    // Returns:
    //
    //   1 = memory-map configuration is valid
    //   0 = memory-map configuration is invalid
    //
    // This function never invokes $fatal, $error, $display,
    // or any other simulation-only system task.
    //
    // Tests:
    //
    //   1. Every region has a nonzero size.
    //   2. Every base is aligned to its region size.
    //   3. Every region has an increasing address range.
    //   4. Consecutive regions do not overlap.
    //
    // The size parameters are compile-time constants.
    //
    // This is an address-map configuration check rather
    // than a runtime transaction validation operation.
    // ========================================================

    function automatic bit bus_validate_memory_map();

        bit sizes_valid;
        bit alignment_valid;
        bit ranges_valid;
        bit ordering_valid;

        // ----------------------------------------------------
        // NONZERO REGION SIZES
        // ----------------------------------------------------

        sizes_valid =

            (DATA_RAM_SIZE != 0) &&

            (GPU_SIZE != 0) &&

            (TPU_SIZE != 0) &&

            (DMA_SIZE != 0) &&

            (SD_SIZE != 0) &&

            (SYSTEM_SIZE != 0) &&

            (DDR3_SIZE != 0);

        // ----------------------------------------------------
        // REGION BASE ALIGNMENT
        // ----------------------------------------------------
        //
        // Every declared region size must divide its base.
        //
        // Size values in the current address map are fixed
        // nonzero constants.
        // ----------------------------------------------------

        alignment_valid =

            ((DATA_RAM_BASE % DATA_RAM_SIZE) == 0) &&

            ((GPU_BASE % GPU_SIZE) == 0) &&

            ((TPU_BASE % TPU_SIZE) == 0) &&

            ((DMA_BASE % DMA_SIZE) == 0) &&

            ((SD_BASE % SD_SIZE) == 0) &&

            ((SYSTEM_BASE % SYSTEM_SIZE) == 0) &&

            ((DDR3_BASE % DDR3_SIZE) == 0);

        // ----------------------------------------------------
        // VALID EXCLUSIVE LIMITS
        // ----------------------------------------------------
        //
        // A region must have:
        //
        //   base < limit
        //
        // This also detects wraparound when a calculated
        // limit becomes less than its base.
        // ----------------------------------------------------

        ranges_valid =

            (DATA_RAM_BASE < DATA_RAM_LIMIT) &&

            (GPU_BASE < GPU_LIMIT) &&

            (TPU_BASE < TPU_LIMIT) &&

            (DMA_BASE < DMA_LIMIT) &&

            (SD_BASE < SD_LIMIT) &&

            (SYSTEM_BASE < SYSTEM_LIMIT) &&

            (DDR3_BASE < DDR3_LIMIT);

        // ----------------------------------------------------
        // REGION ORDER AND NON-OVERLAP
        // ----------------------------------------------------
        //
        // Regions are defined in ascending address order.
        //
        // Every region must end at or before the next
        // region begins.
        // ----------------------------------------------------

        ordering_valid =

            (DATA_RAM_LIMIT <= GPU_BASE) &&

            (GPU_LIMIT <= TPU_BASE) &&

            (TPU_LIMIT <= DMA_BASE) &&

            (DMA_LIMIT <= SD_BASE) &&

            (SD_LIMIT <= SYSTEM_BASE) &&

            (SYSTEM_LIMIT <= DDR3_BASE);

        // ----------------------------------------------------
        // FINAL RESULT
        // ----------------------------------------------------

        return
            sizes_valid &&
            alignment_valid &&
            ranges_valid &&
            ordering_valid;

    endfunction

endpackage

`endif