`timescale 1ns/1ps

// ============================================================
// LACOODA STAGE 2 BUS INTERCONNECT TESTBENCH
// ============================================================
//
// Tests:
//
//   1. Memory-map configuration.
//   2. Idle bus behavior.
//   3. Internal RAM routing.
//   4. RAM local-address translation.
//   5. GPU MMIO routing.
//   6. GPU local-address translation.
//   7. Read and write propagation.
//   8. Byte write-strobe propagation.
//   9. Delayed slave responses.
//  10. Slave response-error propagation.
//  11. Misaligned accesses.
//  12. Reserved TPU/DMA/SD/SYSTEM regions.
//  13. Reserved DDR3 region.
//  14. Unmapped address rejection.
//  15. Address-region boundaries.
//  16. Single-slave selection.
//
// This testbench supplies simulated RAM/GPU responses.
//
// It does not instantiate the real RAM, GPU, CPU, or DDR3
// controller.
//
// It tests the Stage 2 decoder and interconnect only.
// ============================================================

module bus_interconnect_tb;

    import cpu_pkg::*;
    import bus_pkg::*;

    // ========================================================
    // BUS SIGNALS
    // ========================================================

    bus_req_s dbus_req;
    bus_rsp_s dbus_rsp;

    bus_req_s data_ram_req;
    bus_rsp_s data_ram_rsp;

    bus_req_s gpu_mmio_req;
    bus_rsp_s gpu_mmio_rsp;

    // ========================================================
    // TEST COUNTERS
    // ========================================================

    integer tests;
    integer errors;

    // ========================================================
    // DEVICE UNDER TEST
    // ========================================================

    bus_interconnect dut (

        .dbus_req      (dbus_req),
        .dbus_rsp      (dbus_rsp),

        .data_ram_req  (data_ram_req),
        .data_ram_rsp  (data_ram_rsp),

        .gpu_mmio_req  (gpu_mmio_req),
        .gpu_mmio_rsp  (gpu_mmio_rsp)

    );

    // ========================================================
    // ASSERTION HELPER
    // ========================================================

    task automatic check(
        input logic condition,
        input string description
    );

        begin

            tests = tests + 1;

            if (condition !== 1'b1) begin

                errors = errors + 1;

                $display(
                    "[FAIL] %0d: %s",
                    tests,
                    description
                );

            end else begin

                $display(
                    "[PASS] %0d: %s",
                    tests,
                    description
                );

            end

        end

    endtask

    // ========================================================
    // BUS RESET HELPER
    // ========================================================
    //
    // Establishes a clean testbench starting state.
    //
    // The combinational interconnect has no hardware reset.
    // ========================================================

    task automatic clear_bus();

        begin

            dbus_req = '0;

            data_ram_rsp = '0;
            gpu_mmio_rsp = '0;

            #1;

        end

    endtask

    // ========================================================
    // REQUEST HELPER
    // ========================================================

    task automatic make_request(
        input word_t address,
        input bus_op_e operation,
        input word_t write_data,
        input bus_strb_t write_strobes
    );

        begin

            dbus_req = '0;

            dbus_req.valid = 1'b1;
            dbus_req.op    = operation;
            dbus_req.addr  = address;
            dbus_req.wdata = write_data;
            dbus_req.wstrb = write_strobes;

            #1;

        end

    endtask

    // ========================================================
    // RESERVED/UNMAPPED REGION TEST
    // ========================================================
    //
    // A reserved or unmapped address must:
    //
    //   - Select no connected slave.
    //   - Complete immediately.
    //   - Report an error.
    //   - Return zero data.
    // ========================================================

    task automatic check_unavailable(
        input word_t address,
        input string description
    );

        begin

            make_request(
                address,
                BUS_READ,
                '0,
                BUS_STRB_NONE
            );

            check(
                !data_ram_req.valid &&
                !gpu_mmio_req.valid,
                {description, ": no slave selected"}
            );

            check(
                dbus_rsp.ready &&
                dbus_rsp.error &&
                (dbus_rsp.rdata === '0),
                {description, ": error response"}
            );

        end

    endtask

    // ========================================================
    // DECODE CLASSIFICATION TEST
    // ========================================================
    //
    // Directly verifies the authoritative package decoder.
    // ========================================================

    task automatic check_decode(
        input word_t address,
        input bus_device_e expected_device,
        input word_t expected_local_addr,
        input logic expected_mapped,
        input logic expected_implemented,
        input string description
    );

        bus_decode_s result;

        begin

            result = bus_decode_address(address);

            check(
                (result.device == expected_device) &&
                (result.local_addr == expected_local_addr) &&
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

        tests  = 0;
        errors = 0;

        $dumpfile("bus_interconnect.vcd");
        $dumpvars(0, bus_interconnect_tb);

        // ====================================================
        // MEMORY MAP CONFIGURATION
        // ====================================================

        check(
            bus_validate_memory_map(),
            "memory map configuration is valid"
        );

        check(
            DATA_RAM_SIZE == word_t'(32768),
            "internal RAM capacity is 32 KiB"
        );

        check(
            GPU_SIZE == word_t'(4096),
            "GPU MMIO allocation is 4 KiB"
        );

        check(
            DDR3_SIZE == word_t'(32'h0800_0000),
            "DDR3 reserved capacity is 128 MiB"
        );

        // ====================================================
        // IDLE
        // ====================================================

        clear_bus();

        check(
            !dbus_rsp.ready,
            "idle bus produces no completion"
        );

        check(
            !data_ram_req.valid &&
            !gpu_mmio_req.valid,
            "idle bus selects no slave"
        );

        // ====================================================
        // INTERNAL RAM WRITE
        // ====================================================

        make_request(
            DATA_RAM_BASE + word_t'(12),
            BUS_WRITE,
            word_t'(32'h1234_5678),
            BUS_STRB_ALL
        );

        check(
            data_ram_req.valid,
            "RAM write selects internal RAM"
        );

        check(
            !gpu_mmio_req.valid,
            "RAM write does not select GPU"
        );

        check(
            data_ram_req.op == BUS_WRITE,
            "RAM write operation is preserved"
        );

        check(
            data_ram_req.addr == word_t'(12),
            "RAM receives local byte address"
        );

        check(
            data_ram_req.wdata == word_t'(32'h1234_5678),
            "RAM receives correct write data"
        );

        check(
            data_ram_req.wstrb == BUS_STRB_ALL,
            "full-word write strobes are forwarded"
        );

        check(
            !dbus_rsp.ready,
            "CPU waits for RAM completion"
        );

        // ====================================================
        // DELAYED RAM RESPONSE
        // ====================================================

        data_ram_rsp = bus_success(
            word_t'(32'hAABB_CCDD)
        );

        #1;

        check(
            dbus_rsp.ready && !dbus_rsp.error,
            "successful RAM response reaches CPU"
        );

        check(
            dbus_rsp.rdata == word_t'(32'hAABB_CCDD),
            "RAM response data is preserved"
        );

        // ====================================================
        // PARTIAL RAM WRITE
        // ====================================================

        data_ram_rsp = '0;

        make_request(
            DATA_RAM_BASE + word_t'(16),
            BUS_WRITE,
            word_t'(32'h0000_AA00),
            bus_strb_t'(4'b0010)
        );

        check(
            data_ram_req.valid &&
            (data_ram_req.wstrb == bus_strb_t'(4'b0010)),
            "single-byte write strobe reaches RAM"
        );

        check(
            data_ram_req.wdata == word_t'(32'h0000_AA00),
            "partial RAM write data is preserved"
        );

        // ====================================================
        // GPU MMIO WRITE
        // ====================================================

        clear_bus();

        make_request(
            GPU_BASE + word_t'(20),
            BUS_WRITE,
            word_t'(32'hDEAD_BEEF),
            BUS_STRB_ALL
        );

        check(
            gpu_mmio_req.valid,
            "GPU MMIO write selects GPU"
        );

        check(
            !data_ram_req.valid,
            "GPU MMIO write does not select RAM"
        );

        check(
            gpu_mmio_req.addr == word_t'(20),
            "GPU receives local register offset"
        );

        check(
            gpu_mmio_req.op == BUS_WRITE,
            "GPU write operation is forwarded"
        );

        check(
            gpu_mmio_req.wdata == word_t'(32'hDEAD_BEEF),
            "GPU write data is forwarded"
        );

        check(
            gpu_mmio_req.wstrb == BUS_STRB_ALL,
            "GPU write strobes are forwarded"
        );

        // ====================================================
        // GPU RESPONSE
        // ====================================================

        gpu_mmio_rsp = bus_success('0);

        #1;

        check(
            dbus_rsp.ready && !dbus_rsp.error,
            "GPU completion reaches CPU"
        );

        // ====================================================
        // GPU READ
        // ====================================================

        gpu_mmio_rsp = bus_success(
            word_t'(32'hCAFEBABE)
        );

        make_request(
            GPU_BASE + word_t'(8),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        check(
            gpu_mmio_req.valid &&
            (gpu_mmio_req.op == BUS_READ),
            "GPU read request is forwarded"
        );

        check(
            dbus_rsp.ready &&
            (dbus_rsp.rdata == word_t'(32'hCAFEBABE)),
            "GPU read data reaches CPU"
        );

        // ====================================================
        // SLAVE ERROR PROPAGATION
        // ====================================================

        gpu_mmio_rsp = bus_failure();

        #1;

        check(
            dbus_rsp.ready && dbus_rsp.error,
            "GPU bus error propagates to CPU"
        );

        // ====================================================
        // MISALIGNED REQUESTS
        // ====================================================

        clear_bus();

        make_request(
            DATA_RAM_BASE + word_t'(1),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        check(
            !data_ram_req.valid &&
            !gpu_mmio_req.valid,
            "misaligned RAM access selects no slave"
        );

        check(
            dbus_rsp.ready && dbus_rsp.error,
            "misaligned RAM access returns bus error"
        );

        make_request(
            GPU_BASE + word_t'(2),
            BUS_WRITE,
            word_t'(32'h1234),
            BUS_STRB_ALL
        );

        check(
            !data_ram_req.valid &&
            !gpu_mmio_req.valid,
            "misaligned GPU access selects no slave"
        );

        check(
            dbus_rsp.ready && dbus_rsp.error,
            "misaligned GPU access returns bus error"
        );

        // ====================================================
        // RAM REGION BOUNDARIES
        // ====================================================

        check_decode(
            DATA_RAM_BASE,
            DEVICE_DATA_RAM,
            '0,
            1'b1,
            1'b1,
            "RAM first address decodes correctly"
        );

        check_decode(
            DATA_RAM_LIMIT - word_t'(1),
            DEVICE_DATA_RAM,
            DATA_RAM_SIZE - word_t'(1),
            1'b1,
            1'b1,
            "RAM last byte belongs to RAM region"
        );

        make_request(
            DATA_RAM_LIMIT - word_t'(WORD_BYTES),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        check(
            data_ram_req.valid,
            "RAM last aligned word is accessible"
        );

        check_unavailable(
            DATA_RAM_LIMIT,
            "first address after RAM"
        );

        // ====================================================
        // GPU REGION BOUNDARIES
        // ====================================================

        check_decode(
            GPU_BASE,
            DEVICE_GPU_MMIO,
            '0,
            1'b1,
            1'b1,
            "GPU first address decodes correctly"
        );

        check_decode(
            GPU_LIMIT - word_t'(1),
            DEVICE_GPU_MMIO,
            GPU_SIZE - word_t'(1),
            1'b1,
            1'b1,
            "GPU final byte belongs to GPU region"
        );

        make_request(
            GPU_LIMIT - word_t'(WORD_BYTES),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        check(
            gpu_mmio_req.valid,
            "GPU final aligned word selects GPU"
        );

        // ====================================================
        // RESERVED TPU REGION
        // ====================================================

        check_decode(
            TPU_BASE,
            DEVICE_TPU_MMIO,
            '0,
            1'b1,
            1'b0,
            "TPU region is reserved but not implemented"
        );

        check_unavailable(
            TPU_BASE,
            "reserved TPU MMIO"
        );

        // ====================================================
        // RESERVED DMA REGION
        // ====================================================

        check_decode(
            DMA_BASE,
            DEVICE_DMA_MMIO,
            '0,
            1'b1,
            1'b0,
            "DMA region is reserved but not implemented"
        );

        check_unavailable(
            DMA_BASE,
            "reserved DMA MMIO"
        );

        // ====================================================
        // RESERVED MICROSD REGION
        // ====================================================

        check_decode(
            SD_BASE,
            DEVICE_SD_MMIO,
            '0,
            1'b1,
            1'b0,
            "SD region is reserved but not implemented"
        );

        check_unavailable(
            SD_BASE,
            "reserved microSD MMIO"
        );

        // ====================================================
        // RESERVED SYSTEM REGION
        // ====================================================

        check_decode(
            SYSTEM_BASE,
            DEVICE_SYSTEM_MMIO,
            '0,
            1'b1,
            1'b0,
            "system-control region is reserved"
        );

        check_unavailable(
            SYSTEM_BASE,
            "reserved system MMIO"
        );

        // ====================================================
        // RESERVED DDR3 REGION
        // ====================================================

        check_decode(
            DDR3_BASE,
            DEVICE_DDR3,
            '0,
            1'b1,
            1'b0,
            "DDR3 base address is reserved"
        );

        check_decode(
            DDR3_BASE + word_t'(32'h0000_1000),
            DEVICE_DDR3,
            word_t'(32'h0000_1000),
            1'b1,
            1'b0,
            "DDR3 global-to-local translation"
        );

        check_decode(
            DDR3_LIMIT - word_t'(1),
            DEVICE_DDR3,
            DDR3_SIZE - word_t'(1),
            1'b1,
            1'b0,
            "DDR3 last byte belongs to reserved region"
        );

        check_unavailable(
            DDR3_BASE,
            "DDR3 not yet connected"
        );

        check_unavailable(
            DDR3_LIMIT,
            "first address after DDR3"
        );

        // ====================================================
        // COMPLETELY UNMAPPED ADDRESS
        // ====================================================

        check_decode(
            word_t'(32'h4000_0000),
            DEVICE_NONE,
            '0,
            1'b0,
            1'b0,
            "unmapped address classified correctly"
        );

        check_unavailable(
            word_t'(32'h4000_0000),
            "unmapped address"
        );

        // ====================================================
        // NO MULTIPLE SLAVE SELECTIONS
        // ====================================================

        clear_bus();

        make_request(
            DATA_RAM_BASE,
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        check(
            !(data_ram_req.valid && gpu_mmio_req.valid),
            "RAM request cannot select two slaves"
        );

        make_request(
            GPU_BASE,
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        check(
            !(data_ram_req.valid && gpu_mmio_req.valid),
            "GPU request cannot select two slaves"
        );

        // ====================================================
        // FINAL IDLE TEST
        // ====================================================

        clear_bus();

        check(
            !dbus_rsp.ready &&
            !data_ram_req.valid &&
            !gpu_mmio_req.valid,
            "bus returns to idle correctly"
        );

        // ====================================================
        // RESULTS
        // ====================================================

        $display(
            "============================================"
        );

        $display(
            "LACOODA STAGE 2 INTERCONNECT REGRESSION"
        );

        $display(
            "Total tests: %0d",
            tests
        );

        $display(
            "Passed:      %0d",
            tests - errors
        );

        $display(
            "Failed:      %0d",
            errors
        );

        $display(
            "============================================"
        );

        if (errors != 0) begin

            $fatal(
                1,
                "LACOODA STAGE 2 REGRESSION FAILED"
            );

        end

        $display(
            "LACOODA STAGE 2 INTERCONNECT TEST PASSED"
        );

        $finish;

    end

endmodule