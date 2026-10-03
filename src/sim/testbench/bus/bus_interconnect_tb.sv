`timescale 1ns/1ps

// ============================================================
// LACOODA data-bus interconnect regression
// ============================================================

module bus_interconnect_tb;
    import cpu_pkg::*;
    import bus_pkg::*;

    bus_req_t d_req;
    bus_rsp_t d_rsp;
    bus_req_t slave_req;
    bus_rsp_t slave_rsp;

    integer tests = 0;
    integer errors = 0;

    bus_interconnect dut (
        .d_req(d_req),
        .d_rsp(d_rsp),
        .slave_req(slave_req),
        .slave_rsp(slave_rsp)
    );

    task automatic check(input logic condition, input string description);
        begin
            tests = tests + 1;
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL %0d %s", tests, description);
            end else begin
                $display("PASS %0d %s", tests, description);
            end
        end
    endtask

    initial begin
        check(BUS_READ === 1'b0 && BUS_WRITE === 1'b1,
              "bus op encodings match the existing write bit");
        $dumpfile("bus_interconnect.vcd");
        $dumpvars(0, bus_interconnect_tb);

        d_req.valid = 1'b0;
        d_req.op = BUS_READ;
        d_req.addr = '0;
        d_req.wdata = '0;
        slave_rsp.ready = 1'b0;
        slave_rsp.rdata = word_t'(16'h1234);
        #1;

        check(!d_rsp.ready && !slave_req.valid,
              "idle master produces no slave request");

        // Mapped request is forwarded and waits for the selected slave.
        d_req.valid = 1'b1;
        d_req.op = BUS_WRITE;
        d_req.addr = DATA_MEMORY_BASE + word_t'(3 * WORD_BYTES);
        d_req.wdata = word_t'(16'h55AA);
        #1;
        check(slave_req.valid && slave_req.op == BUS_WRITE,
              "mapped STORE selects data memory");
        check(slave_req.addr === word_t'(3 * WORD_BYTES) &&
              slave_req.wdata === word_t'(16'h55AA),
              "mapped STORE payload is forwarded");
        check(!d_rsp.ready,
              "master waits while selected slave is not ready");

        slave_rsp.ready = 1'b1;
        #1;
        check(d_rsp.ready,
              "selected slave ready is returned to master");

        d_req.op = BUS_READ;
        slave_rsp.rdata = word_t'(16'hCAFE);
        #1;
        check(slave_req.op == BUS_READ,
              "mapped READ op reaches the slave");
        check(d_rsp.rdata === word_t'(16'hCAFE),
              "selected slave read data is returned to master");

        // First address after local RAM is unmapped. Current architectural
        // behavior completes such accesses immediately with zero data.
        d_req.addr = DATA_MEMORY_LIMIT;
        slave_rsp.ready = 1'b0;
        slave_rsp.rdata = word_t'(16'hFFFF);
        #1;
        check(!slave_req.valid,
              "unmapped address selects no data-memory slave");
        check(d_rsp.ready && d_rsp.rdata === '0,
              "unmapped access completes with zero response");

        d_req.valid = 1'b0;
        #1;
        check(!d_rsp.ready,
              "ready drops when master request is removed");

        $display("========================================");
        $display("LACOODA BUS INTERCONNECT TEST SUMMARY");
        $display("Total tests : %0d", tests);
        $display("Passed      : %0d", tests-errors);
        $display("Failed      : %0d", errors);
        $display("========================================");

        if (errors != 0)
            $fatal(1, "BUS INTERCONNECT TEST FAILED");

        $display("ALL BUS INTERCONNECT TESTS PASSED");
        $finish;
    end

endmodule
