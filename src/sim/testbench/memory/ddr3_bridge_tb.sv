`timescale 1ns/1ps

// ============================================================
// LACOODA DDR3 BRIDGE TESTBENCH — STAGE 3
// ============================================================
//
// Verifies the native DDR3 transaction bridge.
//
// TESTS
//
//   1. Reset state
//   2. Backend unavailable
//   3. Misaligned local address
//   4. Out-of-range local address
//   5. Successful read
//   6. Stable request during backend stalls
//   7. Successful full-word write
//   8. Partial write-strobe preservation
//   9. Backend error propagation
//  10. Last valid aligned DDR3 word
//
// A simulated transaction backend supplies completion.
//
// This test does not verify physical DDR3 timing,
// initialization, or Gowin IP operation.
// ============================================================

module ddr3_bridge_tb;

    import cpu_pkg::*;
    import bus_pkg::*;

    // ========================================================
    // CLOCK
    // ========================================================

    logic clk = 1'b0;

    always #5 clk = ~clk;

    // ========================================================
    // RESET
    // ========================================================

    logic rst;

    // ========================================================
    // UPSTREAM BUS
    // ========================================================

    bus_req_s ddr3_bus_req;
    bus_rsp_s ddr3_bus_rsp;

    // ========================================================
    // BACKEND BUS
    // ========================================================

    bus_req_s ddr3_backend_bus_req;
    bus_rsp_s ddr3_backend_bus_rsp;

    logic backend_ready;

    // ========================================================
    // TEST RESULTS
    // ========================================================

    integer tests;
    integer errors;

    // ========================================================
    // DEVICE UNDER TEST
    // ========================================================

    ddr3_bridge dut (

        .clk           (clk),
        .rst           (rst),

        .ddr3_bus_req      (ddr3_bus_req),
        .ddr3_bus_rsp      (ddr3_bus_rsp),

        .backend_ready (backend_ready),

        .ddr3_backend_bus_req   (ddr3_backend_bus_req),
        .ddr3_backend_bus_rsp   (ddr3_backend_bus_rsp)

    );

    // ========================================================
    // CHECK HELPER
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
    // START A REQUEST
    // ========================================================
    //
    // Drive signals on falling clock edges to avoid
    // races with the DUT's rising-edge state machine.
    // ========================================================

    task automatic start_request(
        input word_t address,
        input bus_op_e operation,
        input word_t write_data,
        input bus_strb_t write_strobes
    );

        begin

            @(negedge clk);

            ddr3_bus_req = '0;

            ddr3_bus_req.valid = 1'b1;
            ddr3_bus_req.op    = operation;
            ddr3_bus_req.addr  = address;
            ddr3_bus_req.wdata = write_data;
            ddr3_bus_req.wstrb = write_strobes;

        end

    endtask

    // ========================================================
    // COMPLETE UPSTREAM REQUEST
    // ========================================================
    //
    // Wait for an asserted response.
    //
    // The upstream request remains valid while waiting.
    //
    // After checking the response, complete the handshake
    // at the next rising edge.
    // ========================================================

    task automatic complete_upstream(
        input logic expected_error,
        input word_t expected_data,
        input string description
    );

        integer cycles;

        begin

            cycles = 0;

            while (
                (ddr3_bus_rsp.ready !== 1'b1) &&
                (cycles < 100)
            ) begin

                @(negedge clk);
                cycles = cycles + 1;

            end

            check(
                ddr3_bus_rsp.ready === 1'b1,
                {description, ": response ready"}
            );

            if (ddr3_bus_rsp.ready === 1'b1) begin

                check(
                    ddr3_bus_rsp.error === expected_error,
                    {description, ": response error"}
                );

                if (!expected_error) begin

                    check(
                        ddr3_bus_rsp.rdata === expected_data,
                        {description, ": response data"}
                    );

                end

                // Consume the response at a rising edge.
                @(posedge clk);

                // Release valid on the following falling edge.
                @(negedge clk);

                ddr3_bus_req = '0;

            end else begin

                // Timeout recovery for testbench cleanup.
                @(negedge clk);
                ddr3_bus_req = '0;

            end

            @(negedge clk);

            check(
                ddr3_bus_rsp.ready === 1'b0,
                {description, ": response released"}
            );

        end

    endtask

    // ========================================================
    // COMPLETE BACKEND REQUEST
    // ========================================================
    //
    // Wait for a captured backend request.
    //
    // Hold the backend stalled for stall_cycles.
    //
    // Verify request stability on every stalled cycle.
    //
    // Then assert one backend completion response.
    // ========================================================

    task automatic complete_backend(
        input integer stall_cycles,
        input word_t response_data,
        input logic response_error,
        input string description
    );

        bus_req_s captured;

        integer cycles;

        begin

            cycles = 0;

            while (
                (ddr3_backend_bus_req.valid !== 1'b1) &&
                (cycles < 100)
            ) begin

                @(negedge clk);
                cycles = cycles + 1;

            end

            check(
                ddr3_backend_bus_req.valid === 1'b1,
                {description, ": backend request"}
            );

            if (ddr3_backend_bus_req.valid !== 1'b1) begin

                $fatal(
                    1,
                    "Timed out waiting for backend request"
                );

            end

            captured = ddr3_backend_bus_req;

            // --------------------------------------------
            // BACKEND STALL
            // --------------------------------------------

            ddr3_backend_bus_rsp = '0;

            for (
                integer i = 0;
                i < stall_cycles;
                i++
            ) begin

                @(negedge clk);

                check(
                    ddr3_backend_bus_req === captured,
                    {description, ": request remains stable"}
                );

                check(
                    ddr3_bus_rsp.ready === 1'b0,
                    {description, ": upstream is stalled"}
                );

            end

            // --------------------------------------------
            // RETURN BACKEND RESPONSE
            // --------------------------------------------

            ddr3_backend_bus_rsp = bus_success(response_data);

            ddr3_backend_bus_rsp.error = response_error;

            // The next rising edge completes the backend
            // request/response handshake.
            @(posedge clk);

            // Observe registered DUT state after the edge.
            @(negedge clk);

            ddr3_backend_bus_rsp = '0;

            check(
                ddr3_backend_bus_req.valid === 1'b0,
                {description, ": backend request withdrawn"}
            );

            check(
                ddr3_bus_rsp.ready === 1'b1,
                {description, ": upstream response registered"}
            );

        end

    endtask

    // ========================================================
    // MAIN TEST
    // ========================================================

    initial begin

        tests  = 0;
        errors = 0;

        rst = 1'b1;

        ddr3_bus_req = '0;
        ddr3_backend_bus_rsp = '0;
        backend_ready = 1'b0;

        $dumpfile("ddr3_bridge.vcd");
        $dumpvars(0, ddr3_bridge_tb);

        // ====================================================
        // RESET
        // ====================================================

        repeat (3) @(negedge clk);

        rst = 1'b0;

        check(
            !ddr3_bus_rsp.ready,
            "Reset clears upstream response"
        );

        check(
            !ddr3_backend_bus_req.valid,
            "Reset clears backend request"
        );

        // ====================================================
        // UNAVAILABLE BACKEND
        // ====================================================

        start_request(
            word_t'(32'h0000_1000),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        complete_upstream(
            1'b1,
            '0,
            "Unavailable backend"
        );

        check(
            !ddr3_backend_bus_req.valid,
            "Unavailable backend receives no request"
        );

        // ====================================================
        // ENABLE BACKEND
        // ====================================================

        backend_ready = 1'b1;

        // ====================================================
        // MISALIGNED ADDRESS
        // ====================================================

        start_request(
            word_t'(32'h0000_1001),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        complete_upstream(
            1'b1,
            '0,
            "Misaligned address"
        );

        // ====================================================
        // OUT-OF-RANGE ADDRESS
        // ====================================================

        start_request(
            DDR3_SIZE,
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        complete_upstream(
            1'b1,
            '0,
            "Out-of-range address"
        );

        // ====================================================
        // DELAYED READ
        // ====================================================

        start_request(
            word_t'(32'h0000_2000),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        complete_backend(
            4,
            word_t'(32'h1234_5678),
            1'b0,
            "Delayed read"
        );

        complete_upstream(
            1'b0,
            word_t'(32'h1234_5678),
            "Delayed read"
        );

        // ====================================================
        // FULL-WORD WRITE
        // ====================================================

        start_request(
            word_t'(32'h0000_3000),
            BUS_WRITE,
            word_t'(32'hAABB_CCDD),
            BUS_STRB_ALL
        );

        // Wait for bridge request capture.
        while (ddr3_backend_bus_req.valid !== 1'b1)
            @(negedge clk);

        check(
            ddr3_backend_bus_req.op == BUS_WRITE,
            "Write operation forwarded"
        );

        check(
            ddr3_backend_bus_req.addr == word_t'(32'h0000_3000),
            "Write address forwarded"
        );

        check(
            ddr3_backend_bus_req.wdata == word_t'(32'hAABB_CCDD),
            "Write data forwarded"
        );

        check(
            ddr3_backend_bus_req.wstrb == BUS_STRB_ALL,
            "Full-word strobes forwarded"
        );

        complete_backend(
            2,
            '0,
            1'b0,
            "Full-word write"
        );

        complete_upstream(
            1'b0,
            '0,
            "Full-word write"
        );

        // ====================================================
        // PARTIAL WRITE
        // ====================================================

        start_request(
            word_t'(32'h0000_4000),
            BUS_WRITE,
            word_t'(32'h0000_AA00),
            bus_strb_t'(4'b0010)
        );

        while (ddr3_backend_bus_req.valid !== 1'b1)
            @(negedge clk);

        check(
            ddr3_backend_bus_req.wstrb == bus_strb_t'(4'b0010),
            "Single-byte strobe preserved"
        );

        check(
            ddr3_backend_bus_req.wdata == word_t'(32'h0000_AA00),
            "Partial-write data preserved"
        );

        complete_backend(
            3,
            '0,
            1'b0,
            "Partial write"
        );

        complete_upstream(
            1'b0,
            '0,
            "Partial write"
        );

        // ====================================================
        // BACKEND ERROR
        // ====================================================

        start_request(
            word_t'(32'h0000_5000),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        complete_backend(
            1,
            '0,
            1'b1,
            "Backend error"
        );

        complete_upstream(
            1'b1,
            '0,
            "Backend error"
        );

        // ====================================================
        // FINAL ALIGNED DDR3 WORD
        // ====================================================

        start_request(
            DDR3_SIZE - word_t'(WORD_BYTES),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        while (ddr3_backend_bus_req.valid !== 1'b1)
            @(negedge clk);

        check(
            ddr3_backend_bus_req.addr ==
                DDR3_SIZE - word_t'(WORD_BYTES),
            "Final aligned DDR3 word accepted"
        );

        complete_backend(
            1,
            word_t'(32'hFACE_CAFE),
            1'b0,
            "Final DDR3 word"
        );

        complete_upstream(
            1'b0,
            word_t'(32'hFACE_CAFE),
            "Final DDR3 word"
        );

        // ====================================================
        // RESULTS
        // ====================================================

        $display("======================================");
        $display("LACOODA DDR3 BRIDGE — STAGE 3");
        $display("Tests:  %0d", tests);
        $display("Passed: %0d", tests - errors);
        $display("Failed: %0d", errors);
        $display("======================================");

        if (errors != 0) begin

            $fatal(
                1,
                "STAGE 3 DDR3 BRIDGE TEST FAILED"
            );

        end

        $display("STAGE 3 DDR3 BRIDGE TEST PASSED");

        $finish;

    end

    // ========================================================
    // GLOBAL TESTBENCH TIMEOUT
    // ========================================================

    initial begin

        #100000;

        $fatal(
            1,
            "Stage 3 testbench timed out"
        );

    end

endmodule