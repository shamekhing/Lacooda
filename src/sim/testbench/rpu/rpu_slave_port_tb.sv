`timescale 1ns/1ps

// ============================================================
// LACOODA RPU SLAVE PORT TESTBENCH — STAGE 5
// ============================================================
//
// Verifies round-robin arbitration, owner stability under
// backpressure, response isolation, field preservation,
// immediate and delayed completion, and reset behavior.
// ============================================================

module rpu_slave_port_tb;

    import cpu_pkg::*;
    import bus_pkg::*;

    logic clk = 1'b0;
    logic rst;

    bus_req_s req0;
    bus_req_s req1;
    bus_req_s req2;
    bus_req_s req3;

    bus_rsp_s rsp0;
    bus_rsp_s rsp1;
    bus_rsp_s rsp2;
    bus_rsp_s rsp3;

    bus_req_s slave_req;
    bus_rsp_s slave_rsp;

    logic owner_active;

    integer tests;
    integer errors;

    always #5 clk = ~clk;

    rpu_slave_port dut (
        .clk(clk),
        .rst(rst),
        .req0(req0),
        .req1(req1),
        .req2(req2),
        .req3(req3),
        .rsp0(rsp0),
        .rsp1(rsp1),
        .rsp2(rsp2),
        .rsp3(rsp3),
        .slave_req(slave_req),
        .slave_rsp(slave_rsp),
        .owner_active(owner_active)
    );

    task automatic check(
        input logic condition,
        input string description
    );

        begin

            tests = tests + 1;

            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("[FAIL] %0d: %s", tests, description);
            end else begin
                $display("[PASS] %0d: %s", tests, description);
            end

        end

    endtask

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

    task automatic clear_transactions();

        begin

            @(negedge clk);

            req0 = '0;
            req1 = '0;
            req2 = '0;
            req3 = '0;

            slave_rsp = '0;

            #1;

        end

    endtask

    task automatic reset_port();

        begin

            @(negedge clk);

            rst = 1'b1;

            req0 = '0;
            req1 = '0;
            req2 = '0;
            req3 = '0;

            slave_rsp = '0;

            repeat (2) @(posedge clk);

            @(negedge clk);

            rst = 1'b0;

            #1;

        end

    endtask

    task automatic check_response_exclusive(
        input string description
    );

        integer ready_count;

        begin

            ready_count = 0;

            if (rsp0.ready) ready_count = ready_count + 1;
            if (rsp1.ready) ready_count = ready_count + 1;
            if (rsp2.ready) ready_count = ready_count + 1;
            if (rsp3.ready) ready_count = ready_count + 1;

            check(
                ready_count <= 1,
                description
            );

        end

    endtask

    task automatic finish_immediate();

        begin

            @(posedge clk);
            @(negedge clk);

            req0 = '0;
            req1 = '0;
            req2 = '0;
            req3 = '0;

            slave_rsp = '0;

            #1;

        end

    endtask

    initial begin

        tests  = 0;
        errors = 0;

        rst = 1'b1;

        req0 = '0;
        req1 = '0;
        req2 = '0;
        req3 = '0;

        slave_rsp = '0;

        $dumpfile("rpu_slave_port.vcd");
        $dumpvars(0, rpu_slave_port_tb);

        // ====================================================
        // RESET
        // ====================================================

        reset_port();

        check(
            slave_req.valid === 1'b0,
            "Reset leaves slave request idle"
        );

        check(
            !rsp0.ready && !rsp1.ready && !rsp2.ready && !rsp3.ready,
            "Reset leaves all master responses idle"
        );

        check(
            owner_active === 1'b0,
            "Reset leaves slave port idle"
        );

        // ====================================================
        // SINGLE MASTER, IMMEDIATE RESPONSE
        // ====================================================

        @(negedge clk);

        req0 = make_request(
            word_t'(32'h0000_0100),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        slave_rsp = bus_success(word_t'(32'h1234_5678));

        #1;

        check(
            slave_req === req0,
            "Immediate request forwarded unchanged"
        );

        check(
            rsp0.ready && (rsp0.rdata == word_t'(32'h1234_5678)),
            "Selected master receives immediate response"
        );

        check_response_exclusive(
            "Immediate response is not broadcast"
        );

        finish_immediate();

        check(
            !slave_req.valid,
            "Slave port returns idle after immediate completion"
        );

        // ====================================================
        // DELAYED RESPONSE AND OWNER STABILITY
        // ====================================================

        reset_port();

        @(negedge clk);

        req0 = make_request(
            word_t'(32'h0000_0200),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        slave_rsp = '0;

        #1;

        check(
            slave_req === req0,
            "Delayed request forwarded while waiting"
        );

        @(posedge clk);
        @(negedge clk);

        // A second master requests while the first is active.

        req1 = make_request(
            word_t'(32'h0000_0300),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        #1;

        check(
            owner_active,
            "Slave port registers an owner under backpressure"
        );

        check(
            slave_req === req0,
            "Registered owner keeps the slave request"
        );

        check(
            !rsp0.ready && !rsp1.ready,
            "No response before the slave completes"
        );

        // Complete the delayed transaction.

        slave_rsp = bus_success(word_t'(32'hA5A5_5A5A));

        #1;

        check(
            rsp0.ready && (rsp0.rdata == word_t'(32'hA5A5_5A5A)),
            "Owner receives delayed response"
        );

        check(
            !rsp1.ready,
            "Waiting master does not receive the response"
        );

        check_response_exclusive(
            "Delayed response is not broadcast"
        );

        @(posedge clk);
        @(negedge clk);

        // Priority rotated past master 0, so master 1 is served.

        check(
            slave_req.valid && (slave_req.addr == word_t'(32'h0000_0300)),
            "Priority rotates after delayed completion"
        );

        slave_rsp = '0;
        req0 = '0;

        // ====================================================
        // REQUEST FIELD PRESERVATION
        // ====================================================

        reset_port();

        @(negedge clk);

        req0 = make_request(
            word_t'(32'h0000_0400),
            BUS_WRITE,
            word_t'(32'hDEAD_BEEF),
            BUS_STRB_ALL
        );

        slave_rsp = '0;

        #1;

        check(
            (slave_req.op == BUS_WRITE) &&
            (slave_req.addr == word_t'(32'h0000_0400)) &&
            (slave_req.wdata == word_t'(32'hDEAD_BEEF)) &&
            (slave_req.wstrb == BUS_STRB_ALL),
            "Write fields are preserved end to end"
        );

        @(posedge clk);
        @(negedge clk);

        slave_rsp = bus_success('0);

        #1;

        check(
            rsp0.ready && !rsp0.error,
            "Write completes with success response"
        );

        @(posedge clk);
        @(negedge clk);

        req0 = '0;
        slave_rsp = '0;


        // ====================================================
        // ROUND-ROBIN ACROSS FOUR MASTERS
        // ====================================================

        reset_port();

        @(negedge clk);

        req0 = make_request(word_t'(32'h0000_1000), BUS_READ, '0, BUS_STRB_NONE);
        req1 = make_request(word_t'(32'h0000_2000), BUS_READ, '0, BUS_STRB_NONE);
        req2 = make_request(word_t'(32'h0000_3000), BUS_READ, '0, BUS_STRB_NONE);
        req3 = make_request(word_t'(32'h0000_4000), BUS_READ, '0, BUS_STRB_NONE);

        slave_rsp = bus_success(word_t'(32'h0000_0001));

        #1;

        check(
            slave_req.addr == word_t'(32'h0000_1000),
            "Round-robin round 1 selects master 0"
        );

        @(posedge clk);
        @(negedge clk);
        #1;

        check(
            slave_req.addr == word_t'(32'h0000_2000),
            "Round-robin round 2 selects master 1"
        );

        @(posedge clk);
        @(negedge clk);
        #1;

        check(
            slave_req.addr == word_t'(32'h0000_3000),
            "Round-robin round 3 selects master 2"
        );

        @(posedge clk);
        @(negedge clk);
        #1;

        check(
            slave_req.addr == word_t'(32'h0000_4000),
            "Round-robin round 4 selects master 3"
        );

        @(posedge clk);
        @(negedge clk);
        #1;

        check(
            slave_req.addr == word_t'(32'h0000_1000),
            "Round-robin wraps to master 0"
        );

        @(posedge clk);
        @(negedge clk);

        req0 = '0;
        req1 = '0;
        req2 = '0;
        req3 = '0;
        slave_rsp = '0;

        // ====================================================
        // RESET DURING ACTIVE TRANSACTION
        // ====================================================

        reset_port();

        @(negedge clk);

        req0 = make_request(
            word_t'(32'h0000_0500),
            BUS_READ,
            '0,
            BUS_STRB_NONE
        );

        slave_rsp = '0;

        @(posedge clk);
        @(negedge clk);

        check(
            owner_active,
            "Transaction is active before reset"
        );

        rst = 1'b1;

        @(posedge clk);
        #1;

        check(
            !slave_req.valid,
            "Reset clears the active slave request"
        );

        check(
            !rsp0.ready && !rsp1.ready && !rsp2.ready && !rsp3.ready,
            "Reset clears all master responses"
        );

        check(
            !owner_active,
            "Reset clears the registered owner"
        );

        @(negedge clk);

        rst = 1'b0;
        req0 = '0;
        slave_rsp = '0;

        #1;

        // ====================================================
        // FINAL RESULTS
        // ====================================================

        $display("==========================================");
        $display("LACOODA STAGE 5 RPU SLAVE PORT");
        $display("Tests:  %0d", tests);
        $display("Passed: %0d", tests - errors);
        $display("Failed: %0d", errors);
        $display("==========================================");

        if (errors != 0)
            $fatal(1, "LACOODA STAGE 5 RPU SLAVE PORT TEST FAILED");

        $display("LACOODA STAGE 5 RPU SLAVE PORT TEST PASSED");
        $finish;

    end

    initial begin
        #200000;
        $fatal(1, "LACOODA Stage 5 RPU slave port test timed out");
    end

endmodule
