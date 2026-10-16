`timescale 1ns/1ps

// ============================================================
// LACOODA BUS PACKAGE TESTBENCH
// ============================================================
//
// PURPOSE
//
//   Verify the bus package definitions and address-map
//   classification before integrating the interconnect.
//
// TEST COVERAGE
//
//   - Memory-map configuration validity
//   - Native bus word size
//   - Write-strobe constants
//   - Address alignment
//   - RAM address classification
//   - GPU MMIO classification
//   - Reserved peripheral classification
//   - DDR3 classification
//   - Global-to-local address translation
//   - Address-region boundaries
//   - Unmapped address handling
//   - Successful response construction
//   - Error response construction
//
// This file is for simulation only.
// ============================================================

module bus_pkg_tb;

    import cpu_pkg::*;
    import bus_pkg::*;

    // ========================================================
    // TEST COUNTERS
    // ========================================================

    integer test_count;
    integer error_count;

    // ========================================================
    // ASSERTION HELPER
    // ========================================================

    task automatic check(

        input logic condition,

        input string description

    );

        begin

            test_count = test_count + 1;

            if (condition !== 1'b1) begin

                error_count = error_count + 1;

                $display(
                    "[FAIL] %0d: %s",
                    test_count,
                    description
                );

            end else begin

                $display(
                    "[PASS] %0d: %s",
                    test_count,
                    description
                );

            end

        end

    endtask

    // ========================================================
    // ADDRESS CLASSIFICATION HELPER
    // ========================================================

    task automatic check_decode(

        input word_t address,

        input bus_device_e expected_device,

        input word_t expected_local_address,

        input logic expected_mapped,

        input logic expected_implemented,

        input string description

    );

        bus_decode_s result;

        begin

            result = bus_decode_address(address);

            check(

                (result.device == expected_device) &&

                (result.local_addr == expected_local_address) &&

                (result.mapped == expected_mapped) &&

                (result.implemented == expected_implemented),

                description

            );

        end

    endtask

    // ========================================================
    // MAIN TEST
    // ========================================================

    initial begin

        test_count  = 0;
        error_count = 0;

        // ====================================================
        // CONFIGURATION VALIDATION
        // ====================================================

        check(
            bus_validate_memory_map(),
            "Memory-map configuration is valid"
        );

        // ====================================================
        // BUS DIMENSIONS
        // ====================================================

        check(
            WORD_BYTES == 4,
            "Native bus word contains four bytes"
        );

        check(
            $bits(bus_strb_t) == WORD_BYTES,
            "Write-strobe width matches word byte count"
        );

        // ====================================================
        // WRITE STROBES
        // ====================================================

        check(
            BUS_STRB_NONE == bus_strb_t'(4'b0000),
            "BUS_STRB_NONE disables all bytes"
        );

        check(
            BUS_STRB_ALL == bus_strb_t'(4'b1111),
            "BUS_STRB_ALL enables all bytes"
        );

        check(
            !bus_has_write_bytes(BUS_STRB_NONE),
            "Zero write strobe contains no selected byte"
        );

        check(
            bus_has_write_bytes(BUS_STRB_ALL),
            "Full write strobe selects bytes"
        );

        check(
            bus_has_write_bytes(bus_strb_t'(4'b0010)),
            "Partial write strobe selects one byte"
        );

        // ====================================================
        // ADDRESS ALIGNMENT
        // ====================================================

        check(
            bus_is_aligned(word_t'(32'h0000_0000)),
            "Zero address is aligned"
        );

        check(
            bus_is_aligned(word_t'(32'h0000_0004)),
            "Four-byte address is aligned"
        );

        check(
            !bus_is_aligned(word_t'(32'h0000_0001)),
            "Address +1 is misaligned"
        );

        check(
            !bus_is_aligned(word_t'(32'h0000_0002)),
            "Address +2 is misaligned"
        );

        // ====================================================
        // MEMORY REGION SIZES
        // ====================================================

        check(
            DATA_RAM_SIZE == word_t'(32'h0000_8000),
            "Internal RAM occupies 32 KiB"
        );

        check(
            GPU_SIZE == word_t'(32'h0000_1000),
            "GPU MMIO occupies 4 KiB"
        );

        check(
            TPU_SIZE == word_t'(32'h0000_1000),
            "TPU MMIO reserves 4 KiB"
        );

        check(
            DDR3_SIZE == word_t'(32'h0800_0000),
            "DDR3 address region occupies 128 MiB"
        );

        // ====================================================
        // TPU CONSTANT CONSISTENCY
        // ====================================================
        //
        // Explicitly verify the constant that previously
        // produced the undeclared-identifier error.
        // ====================================================

        check(
            TPU_LIMIT == TPU_BASE + TPU_SIZE,
            "TPU_LIMIT is correctly declared and calculated"
        );

        check(
            TPU_LIMIT <= DMA_BASE,
            "TPU and DMA regions do not overlap"
        );

        // ====================================================
        // INTERNAL RAM
        // ====================================================

        check_decode(

            DATA_RAM_BASE,

            DEVICE_DATA_RAM,

            word_t'(0),

            1'b1,

            1'b1,

            "RAM base address"

        );

        check_decode(

            DATA_RAM_LIMIT - word_t'(WORD_BYTES),

            DEVICE_DATA_RAM,

            DATA_RAM_SIZE - word_t'(WORD_BYTES),

            1'b1,

            1'b1,

            "RAM last aligned word"

        );

        // ====================================================
        // GPU MMIO
        // ====================================================

        check_decode(

            GPU_BASE,

            DEVICE_GPU_MMIO,

            word_t'(0),

            1'b1,

            1'b1,

            "GPU MMIO base"

        );

        check_decode(

            GPU_BASE + word_t'(32'h14),

            DEVICE_GPU_MMIO,

            word_t'(32'h14),

            1'b1,

            1'b1,

            "GPU MMIO local address translation"

        );

        // ====================================================
        // RESERVED TPU MMIO
        // ====================================================

        check_decode(

            TPU_BASE,

            DEVICE_TPU_MMIO,

            word_t'(0),

            1'b1,

            1'b0,

            "TPU MMIO reserved region"

        );

        // ====================================================
        // RESERVED DMA MMIO
        // ====================================================

        check_decode(

            DMA_BASE,

            DEVICE_DMA_MMIO,

            word_t'(0),

            1'b1,

            1'b0,

            "DMA MMIO reserved region"

        );

        // ====================================================
        // RESERVED MICROSD MMIO
        // ====================================================

        check_decode(

            SD_BASE,

            DEVICE_SD_MMIO,

            word_t'(0),

            1'b1,

            1'b0,

            "microSD MMIO reserved region"

        );

        // ====================================================
        // RESERVED SYSTEM MMIO
        // ====================================================

        check_decode(

            SYSTEM_BASE,

            DEVICE_SYSTEM_MMIO,

            word_t'(0),

            1'b1,

            1'b0,

            "System-control MMIO reserved region"

        );

        // ====================================================
        // EXTERNAL DDR3
        // ====================================================
        //
        // Stage 3 provides the DDR3 bridge.
        //
        // The bridge remains responsible for reporting
        // unavailable physical memory.
        // ====================================================

        check_decode(

            DDR3_BASE,

            DEVICE_DDR3,

            word_t'(0),

            1'b1,

            1'b1,

            "DDR3 bridge address region"

        );

        check_decode(

            DDR3_BASE + word_t'(32'h0000_1000),

            DEVICE_DDR3,

            word_t'(32'h0000_1000),

            1'b1,

            1'b1,

            "DDR3 local address translation"

        );

        check_decode(

            DDR3_LIMIT - word_t'(WORD_BYTES),

            DEVICE_DDR3,

            DDR3_SIZE - word_t'(WORD_BYTES),

            1'b1,

            1'b1,

            "DDR3 last aligned word"

        );

        // ====================================================
        // UNMAPPED ADDRESSES
        // ====================================================

        check_decode(

            DATA_RAM_LIMIT,

            DEVICE_NONE,

            word_t'(0),

            1'b0,

            1'b0,

            "First byte after RAM is unmapped"

        );

        check_decode(

            word_t'(32'h4000_0000),

            DEVICE_NONE,

            word_t'(0),

            1'b0,

            1'b0,

            "Unassigned address is unmapped"

        );

        check_decode(

            DDR3_LIMIT,

            DEVICE_NONE,

            word_t'(0),

            1'b0,

            1'b0,

            "First byte after DDR3 is unmapped"

        );

        // ====================================================
        // SUCCESSFUL BUS RESPONSE
        // ====================================================

        begin

            bus_rsp_s rsp;

            rsp = bus_success(
                word_t'(32'h1234_5678)
            );

            check(
                rsp.ready,
                "Successful response asserts ready"
            );

            check(
                !rsp.error,
                "Successful response clears error"
            );

            check(
                rsp.rdata == word_t'(32'h1234_5678),
                "Successful response preserves read data"
            );

        end

        // ====================================================
        // FAILED BUS RESPONSE
        // ====================================================

        begin

            bus_rsp_s rsp;

            rsp = bus_failure();

            check(
                rsp.ready,
                "Failed response asserts ready"
            );

            check(
                rsp.error,
                "Failed response asserts error"
            );

            check(
                rsp.rdata == word_t'(0),
                "Failed response clears read data"
            );

        end

        // ====================================================
        // FINAL RESULTS
        // ====================================================

        $display(
            "=========================================="
        );

        $display(
            "LACOODA BUS PACKAGE REGRESSION"
        );

        $display(
            "Tests:  %0d",
            test_count
        );

        $display(
            "Passed: %0d",
            test_count - error_count
        );

        $display(
            "Failed: %0d",
            error_count
        );

        $display(
            "=========================================="
        );

        if (error_count != 0) begin

            $fatal(
                1,
                "LACOODA BUS PACKAGE REGRESSION FAILED"
            );

        end

        $display(
            "LACOODA BUS PACKAGE REGRESSION PASSED"
        );

        $finish;

    end

endmodule