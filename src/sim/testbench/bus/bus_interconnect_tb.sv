`timescale 1ns/1ps

// ============================================================
// LACOODA data-bus interconnect regression
//
// Stage 1 verifies routing between:
//
//   CPU D-BUS
//       |
//       +---- local data memory
//       |
//       +---- GPU
//
// It also verifies:
//   - slave-local address translation
//   - response routing
//   - unmapped-address behavior
// ============================================================

module bus_interconnect_tb;

    import cpu_pkg::*;
    import bus_pkg::*;

    bus_req_s cpu_req;
    bus_rsp_s cpu_rsp;

    bus_req_s bram_memory_req;
    bus_rsp_s bram_memory_rsp;

    bus_req_s gpu_req;
    bus_rsp_s gpu_rsp;

    integer tests  = 0;
    integer errors = 0;

    // --------------------------------------------------------
    // DUT
    // --------------------------------------------------------

    bus_interconnect dut (
        .cpu_req           (cpu_req),
        .cpu_rsp           (cpu_rsp),

        .bram_memory_req (bram_memory_req),
        .bram_memory_rsp (bram_memory_rsp),

        .gpu_req         (gpu_req),
        .gpu_rsp         (gpu_rsp)
    );

    // --------------------------------------------------------
    // Check helper
    // --------------------------------------------------------

    task automatic check(
        input logic condition,
        input string description
    );
        begin

            tests = tests + 1;

            if (condition !== 1'b1) begin

                errors = errors + 1;
                $display(
                    "FAIL %0d %s",
                    tests,
                    description
                );

            end else begin

                $display(
                    "PASS %0d %s",
                    tests,
                    description
                );

            end

        end
    endtask

    // --------------------------------------------------------
    // Main test
    // --------------------------------------------------------

    initial begin

        $dumpfile("bus_interconnect.vcd");
        $dumpvars(0, bus_interconnect_tb);

        check(
            BUS_READ === 1'b0 &&
            BUS_WRITE === 1'b1,
            "bus operation encodings"
        );

        // ----------------------------------------------------
        // Initial state
        // ----------------------------------------------------

        cpu_req = '0;

        bram_memory_rsp = '0;
        gpu_rsp = '0;

        #1;

        check(
            !cpu_rsp.ready,
            "idle master receives no completion"
        );

        check(
            !bram_memory_req.valid &&
            !gpu_req.valid,
            "idle master selects no slave"
        );

        // ====================================================
        // DATA MEMORY ROUTING
        // ====================================================

        cpu_req.valid = 1'b1;
        cpu_req.op    = BUS_WRITE;

        cpu_req.addr =
            BRAM_MEMORY_BASE +
            word_t'(3 * WORD_BYTES);

        cpu_req.wdata =
            word_t'(16'h55AA);

        #1;

        check(
            bram_memory_req.valid,
            "RAM address selects data memory"
        );

        check(
            !gpu_req.valid,
            "RAM address does not select GPU"
        );

        check(
            bram_memory_req.op == BUS_WRITE,
            "RAM write operation forwarded"
        );

        check(
            bram_memory_req.addr ===
                word_t'(3 * WORD_BYTES),
            "RAM receives local address"
        );

        check(
            bram_memory_req.wdata ===
                word_t'(16'h55AA),
            "RAM receives write data"
        );

        check(
            !cpu_rsp.ready,
            "CPU waits while RAM is not ready"
        );

        bram_memory_rsp.ready = 1'b1;
        bram_memory_rsp.rdata = word_t'(16'hCAFE);

        #1;

        check(
            cpu_rsp.ready,
            "RAM ready reaches CPU"
        );

        check(
            cpu_rsp.rdata === word_t'(16'hCAFE),
            "RAM response data reaches CPU"
        );

        // ====================================================
        // GPU ROUTING
        // ====================================================

        bram_memory_rsp = '0;

        cpu_req.valid = 1'b1;
        cpu_req.op    = BUS_WRITE;

        cpu_req.addr =
            GPU_BASE + word_t'(12);

        cpu_req.wdata =
            word_t'(32'h1234_5678);

        #1;

        check(
            gpu_req.valid,
            "GPU address selects GPU"
        );

        check(
            !bram_memory_req.valid,
            "GPU address does not select RAM"
        );

        check(
            gpu_req.op == BUS_WRITE,
            "GPU write operation forwarded"
        );

        check(
            gpu_req.addr === word_t'(12),
            "GPU receives local address"
        );

        check(
            gpu_req.wdata ===
                word_t'(32'h1234_5678),
            "GPU receives write data"
        );

        check(
            !cpu_rsp.ready,
            "CPU waits while GPU is not ready"
        );

        // Pretend the GPU completes the request.

        gpu_rsp.ready = 1'b1;
        gpu_rsp.rdata = word_t'(32'hA5A5_5A5A);

        #1;

        check(
            cpu_rsp.ready,
            "GPU ready reaches CPU"
        );

        check(
            cpu_rsp.rdata ===
                word_t'(32'hA5A5_5A5A),
            "GPU response data reaches CPU"
        );

        // ====================================================
        // GPU READ
        // ====================================================

        cpu_req.op =
            BUS_READ;

        #1;

        check(
            gpu_req.valid &&
            gpu_req.op == BUS_READ,
            "GPU read operation forwarded"
        );

        check(
            cpu_rsp.rdata ===
                word_t'(32'hA5A5_5A5A),
            "GPU read response returned to CPU"
        );

        // ====================================================
        // LAST GPU ADDRESS
        // ====================================================

        cpu_req.addr =
            GPU_LIMIT - word_t'(1);

        #1;

        check(
            gpu_req.valid,
            "last byte inside GPU region selects GPU"
        );

        // ====================================================
        // FIRST ADDRESS AFTER GPU
        // ====================================================

        cpu_req.addr =
            GPU_LIMIT;

        gpu_rsp = '0;

        #1;

        check(
            !bram_memory_req.valid &&
            !gpu_req.valid,
            "address after GPU region selects no slave"
        );

        check(
            cpu_rsp.ready &&
            cpu_rsp.rdata === '0,
            "unmapped access completes with zero"
        );

        // ====================================================
        // IDLE
        // ====================================================

        cpu_req.valid = 1'b0;

        #1;

        check(
            !cpu_rsp.ready,
            "ready drops when CPU request disappears"
        );

        check(
            !bram_memory_req.valid &&
            !gpu_req.valid,
            "all slave valid signals drop when idle"
        );

        // ====================================================
        // SUMMARY
        // ====================================================

        $display(
            "========================================"
        );

        $display(
            "LACOODA STAGE 1 BUS INTERCONNECT TEST"
        );

        $display(
            "Total tests : %0d",
            tests
        );

        $display(
            "Passed      : %0d",
            tests - errors
        );

        $display(
            "Failed      : %0d",
            errors
        );

        $display(
            "========================================"
        );

        if (errors != 0)
            $fatal(
                1,
                "BUS INTERCONNECT TEST FAILED"
            );

        $display(
            "ALL BUS INTERCONNECT TESTS PASSED"
        );

        $finish;

    end

endmodule