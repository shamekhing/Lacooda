`timescale 1ns/1ps

// ============================================================
// LACOODA BUS ARBITER TESTBENCH — STAGE 4
// ============================================================
//
// TEST COVERAGE
//
//   1. Reset behavior
//   2. Idle bus behavior
//   3. CPU-only transactions
//   4. GPU-only transactions
//   5. TPU-only transactions
//   6. Immediate responses
//   7. Delayed downstream responses
//   8. Stable ownership under backpressure
//   9. Response routing to selected master
//  10. Full request-field preservation
//  11. Round-robin ordering
//  12. Continuous contention
//  13. Error response propagation
//  14. No unsolicited responses
//
// No CPU, GPU, TPU or DDR3 physical IP is instantiated.
//
// The testbench directly drives native bus requests.
// ============================================================

module bus_arbiter_tb;

    import cpu_pkg::*;
    import bus_pkg::*;

    // ========================================================
    // CLOCK AND RESET
    // ========================================================

    logic clk = 1'b0;
    logic rst;

    always #5 clk = ~clk;

    // ========================================================
    // MASTER BUS SIGNALS
    // ========================================================

    bus_req_s cpu_bus_req;
    bus_rsp_s cpu_bus_rsp;

    bus_req_s gpu_bus_req;
    bus_rsp_s gpu_bus_rsp;

    bus_req_s tpu_bus_req;
    bus_rsp_s tpu_bus_rsp;

    // ========================================================
    // SHARED BUS SIGNALS
    // ========================================================

    bus_req_s shared_bus_req;
    bus_rsp_s shared_bus_rsp;

    // ========================================================
    // TEST STATISTICS
    // ========================================================

    integer tests;
    integer errors;

    // ========================================================
    // DEVICE UNDER TEST
    // ========================================================

    bus_arbiter dut (

        .clk        (clk),
        .rst        (rst),

        .cpu_bus_req    (cpu_bus_req),
        .cpu_bus_rsp    (cpu_bus_rsp),

        .gpu_bus_req    (gpu_bus_req),
        .gpu_bus_rsp    (gpu_bus_rsp),

        .tpu_bus_req    (tpu_bus_req),
        .tpu_bus_rsp    (tpu_bus_rsp),

        .shared_bus_req (shared_bus_req),
        .shared_bus_rsp (shared_bus_rsp)

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
    // CREATE A BUS REQUEST
    // ========================================================

    function automatic bus_req_s make_request(
        input word_t address,
        input bus_op_e operation,
        input word_t write_data,
        input bus_strb_t strobes
    );

        bus_req_s result;

        result = '0;

        result.valid = 1'b1;
        result.op    = operation;
        result.addr  = address;
        result.wdata = write_data;
        result.wstrb = strobes;

        return result;

    endfunction

    // ========================================================
    // CLEAR TRANSACTION SIGNALS
    // ========================================================

    task automatic clear_transactions();

        begin

            @(negedge clk);

            cpu_bus_req = '0;
            gpu_bus_req = '0;
            tpu_bus_req = '0;

            shared_bus_rsp = '0;

            #1;

        end

    endtask

    // ========================================================
    // RESET THE ARBITER
    // ========================================================
    //
    // Used to make independent tests deterministic.
    // ========================================================

    task automatic reset_arbiter();

        begin

            @(negedge clk);

            rst = 1'b1;

            cpu_bus_req = '0;
            gpu_bus_req = '0;
            tpu_bus_req = '0;

            shared_bus_rsp = '0;

            repeat (2) @(posedge clk);

            @(negedge clk);

            rst = 1'b0;

            #1;

        end

    endtask

    // ========================================================
    // VERIFY ONLY ONE RESPONSE IS ACTIVE
    // ========================================================

    task automatic check_response_exclusive(
        input string description
    );

        integer ready_count;

        begin

            ready_count = 0;

            if (cpu_bus_rsp.ready)
                ready_count = ready_count + 1;

            if (gpu_bus_rsp.ready)
                ready_count = ready_count + 1;

            if (tpu_bus_rsp.ready)
                ready_count = ready_count + 1;

            check(
                ready_count <= 1,
                description
            );

        end

    endtask

    // ========================================================
    // COMPLETE ONE IMMEDIATE TRANSACTION
    // ========================================================
    //
    // The downstream response is made ready before the
    // completion edge.
    //
    // The selected master drops valid after that edge.
    // ========================================================

    task automatic finish_immediate();

        begin

            @(posedge clk);

            @(negedge clk);

            cpu_bus_req = '0;
            gpu_bus_req = '0;
            tpu_bus_req = '0;
            shared_bus_rsp = '0;

            #1;

        end

    endtask

    // ========================================================
    // MAIN TEST
    // ========================================================

    initial begin

        tests  = 0;
        errors = 0;

        rst = 1'b1;

        cpu_bus_req = '0;
        gpu_bus_req = '0;
        tpu_bus_req = '0;

        shared_bus_rsp = '0;

        $dumpfile("bus_arbiter.vcd");
        $dumpvars(0, bus_arbiter_tb);

        // ====================================================
        // RESET
        // ====================================================

        reset_arbiter();

        check(
            shared_bus_req.valid === 1'b0,
            "Reset leaves shared bus idle"
        );

        check(
            cpu_bus_rsp.ready === 1'b0 &&
            gpu_bus_rsp.ready === 1'b0 &&
            tpu_bus_rsp.ready === 1'b0,
            "Reset leaves all master responses idle"
        );

        // ====================================================
        // CPU-ONLY TRANSACTION
        // ====================================================

        @(negedge clk);

        cpu_bus_req = make_request(
            word_t'(32'h0000_0100),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        shared_bus_rsp = bus_success(
            word_t'(32'h1234_5678)
        );

        #1;

        check(
            shared_bus_req === cpu_bus_req,
            "CPU request forwarded unchanged"
        );

        check(
            cpu_bus_rsp.ready &&
            (cpu_bus_rsp.rdata == word_t'(32'h1234_5678)),
            "CPU receives downstream response"
        );

        check(
            !gpu_bus_rsp.ready && !tpu_bus_rsp.ready,
            "GPU and TPU do not receive CPU response"
        );

        check_response_exclusive(
            "CPU transaction has exclusive response"
        );

        finish_immediate();

        // ====================================================
        // GPU-ONLY TRANSACTION
        // ====================================================

        reset_arbiter();

        @(negedge clk);

        gpu_bus_req = make_request(
            word_t'(32'h8000_1000),
            BUS_WRITE,
            word_t'(32'hAABB_CCDD),
            BUS_STRB_ALL
        );

        shared_bus_rsp = bus_success('0);

        #1;

        check(
            shared_bus_req === gpu_bus_req,
            "GPU request forwarded unchanged"
        );

        check(
            gpu_bus_rsp.ready &&
            !cpu_bus_rsp.ready &&
            !tpu_bus_rsp.ready,
            "Only GPU receives its completion"
        );

        check(
            shared_bus_req.wstrb == BUS_STRB_ALL,
            "GPU write strobes preserved"
        );

        finish_immediate();

        // ====================================================
        // TPU-ONLY TRANSACTION
        // ====================================================

        reset_arbiter();

        @(negedge clk);

        tpu_bus_req = make_request(
            word_t'(32'h8000_2000),
            BUS_WRITE,
            word_t'(32'h0000_AB00),
            bus_strb_t'(4'b0010)
        );

        shared_bus_rsp = bus_success('0);

        #1;

        check(
            shared_bus_req === tpu_bus_req,
            "TPU request forwarded unchanged"
        );

        check(
            tpu_bus_rsp.ready &&
            !cpu_bus_rsp.ready &&
            !gpu_bus_rsp.ready,
            "Only TPU receives its completion"
        );

        check(
            shared_bus_req.wstrb == bus_strb_t'(4'b0010),
            "TPU partial write strobes preserved"
        );

        finish_immediate();

        // ====================================================
        // DELAYED RESPONSE / OWNERSHIP RETENTION
        // ====================================================

        reset_arbiter();

        @(negedge clk);

        cpu_bus_req = make_request(
            word_t'(32'h8000_3000),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        shared_bus_rsp = '0;

        #1;

        check(
            shared_bus_req.valid &&
            (shared_bus_req.addr == word_t'(32'h8000_3000)),
            "CPU initially wins an uncontended request"
        );

        // The first rising edge registers CPU ownership.
        @(posedge clk);
        @(negedge clk);

        // Other masters begin requesting while CPU waits.
        gpu_bus_req = make_request(
            word_t'(32'h8000_4000),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        tpu_bus_req = make_request(
            word_t'(32'h8000_5000),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        #1;

        check(
            shared_bus_req === cpu_bus_req,
            "CPU retains ownership under contention"
        );

        check(
            !gpu_bus_rsp.ready && !tpu_bus_rsp.ready,
            "Waiting masters remain stalled"
        );

        // Simulate four stalled clock cycles.
        repeat (4) begin

            @(posedge clk);
            @(negedge clk);

            check(
                shared_bus_req === cpu_bus_req,
                "CPU request remains selected during stall"
            );

        end

        // Return the delayed response.
        shared_bus_rsp = bus_success(
            word_t'(32'hFEED_BEEF)
        );

        #1;

        check(
            cpu_bus_rsp.ready &&
            (cpu_bus_rsp.rdata == word_t'(32'hFEED_BEEF)),
            "Delayed response reaches CPU"
        );

        check(
            !gpu_bus_rsp.ready && !tpu_bus_rsp.ready,
            "Delayed response does not reach other masters"
        );

        // Consume CPU completion.
        @(posedge clk);
        @(negedge clk);

        cpu_bus_req = '0;
        shared_bus_rsp = '0;

        #1;

        // The next priority should be GPU.
        check(
            shared_bus_req === gpu_bus_req,
            "Round-robin selects GPU after CPU"
        );

        shared_bus_rsp = bus_success(
            word_t'(32'h2222_2222)
        );

        #1;

        check(
            gpu_bus_rsp.ready &&
            (gpu_bus_rsp.rdata == word_t'(32'h2222_2222)),
            "GPU receives second transaction response"
        );

        @(posedge clk);
        @(negedge clk);

        gpu_bus_req = '0;
        shared_bus_rsp = '0;

        #1;

        // TPU follows GPU.
        check(
            shared_bus_req === tpu_bus_req,
            "Round-robin selects TPU after GPU"
        );

        shared_bus_rsp = bus_success(
            word_t'(32'h3333_3333)
        );

        #1;

        check(
            tpu_bus_rsp.ready &&
            (tpu_bus_rsp.rdata == word_t'(32'h3333_3333)),
            "TPU receives third transaction response"
        );

        @(posedge clk);
        @(negedge clk);

        tpu_bus_req = '0;
        shared_bus_rsp = '0;

        #1;

        check(
            !shared_bus_req.valid,
            "Shared bus returns idle after three requests"
        );

        // ====================================================
        // CONTINUOUS THREE-MASTER CONTENTION
        // ====================================================
        //
        // Each master issues a new request after its
        // previous completion.
        //
        // Expected order:
        //
        // CPU -> GPU -> TPU -> CPU -> GPU -> TPU
        // ====================================================

        reset_arbiter();

        @(negedge clk);

        cpu_bus_req = make_request(
            word_t'(32'h0000_0100),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        gpu_bus_req = make_request(
            word_t'(32'h0000_0200),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        tpu_bus_req = make_request(
            word_t'(32'h0000_0300),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        shared_bus_rsp = bus_success('0);

        #1;

        // First arbitration: CPU.
        check(
            shared_bus_req.addr == word_t'(32'h0000_0100),
            "Contention round 1 selects CPU"
        );

        @(posedge clk);
        @(negedge clk);

        // The CPU has completed its previous request.
        // Change its request only after the completion edge.
        cpu_bus_req.addr = word_t'(32'h0000_0104);

        #1;

        check(
            shared_bus_req.addr == word_t'(32'h0000_0200),
            "Contention round 2 selects GPU"
        );

        @(posedge clk);
        @(negedge clk);

        gpu_bus_req.addr = word_t'(32'h0000_0204);

        #1;

        check(
            shared_bus_req.addr == word_t'(32'h0000_0300),
            "Contention round 3 selects TPU"
        );

        @(posedge clk);
        @(negedge clk);

        tpu_bus_req.addr = word_t'(32'h0000_0304);

        #1;

        check(
            shared_bus_req.addr == word_t'(32'h0000_0104),
            "Contention round 4 returns to CPU"
        );

        @(posedge clk);
        @(negedge clk);

        cpu_bus_req.addr = word_t'(32'h0000_0108);

        #1;

        check(
            shared_bus_req.addr == word_t'(32'h0000_0204),
            "Contention round 5 returns to GPU"
        );

        @(posedge clk);
        @(negedge clk);

        gpu_bus_req.addr = word_t'(32'h0000_0208);

        #1;

        check(
            shared_bus_req.addr == word_t'(32'h0000_0304),
            "Contention round 6 returns to TPU"
        );

        // Complete the last transaction.
        @(posedge clk);

        clear_transactions();

        check(
            !shared_bus_req.valid,
            "Shared bus becomes idle after contention"
        );

        // ====================================================
        // ERROR RESPONSE ROUTING
        // ====================================================

        reset_arbiter();

        @(negedge clk);

        gpu_bus_req = make_request(
            word_t'(32'h4000_0000),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        shared_bus_rsp = bus_failure();

        #1;

        check(
            gpu_bus_rsp.ready && gpu_bus_rsp.error,
            "GPU receives downstream bus error"
        );

        check(
            !cpu_bus_rsp.ready && !tpu_bus_rsp.ready,
            "Bus error is not broadcast to other masters"
        );

        finish_immediate();

        // ====================================================
        // FINAL RESULTS
        // ====================================================

        $display("==========================================");
        $display("LACOODA STAGE 4 BUS ARBITER");
        $display("Tests:  %0d", tests);
        $display("Passed: %0d", tests - errors);
        $display("Failed: %0d", errors);
        $display("==========================================");

        if (errors != 0) begin

            $fatal(
                1,
                "LACOODA STAGE 4 ARBITER TEST FAILED"
            );

        end

        $display(
            "LACOODA STAGE 4 ARBITER TEST PASSED"
        );

        $finish;

    end

    // ========================================================
    // SIMULATION TIMEOUT
    // ========================================================

    initial begin

        #100000;

        $fatal(
            1,
            "LACOODA Stage 4 arbiter test timed out"
        );

    end

endmodule