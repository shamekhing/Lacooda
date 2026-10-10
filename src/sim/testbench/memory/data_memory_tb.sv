`timescale 1ns/1ps

// ============================================================
// Data-memory bus-slave regression
//
// Verifies the local memory's valid/ready protocol, byte-ibus_req.addr
// indexing, combinational LOAD response, synchronous STORE commit,
// and the preserved invalid-ibus_req.addr behavior.
// ============================================================

module cpu_memory_tb;
    import cpu_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    bus_pkg::bus_req_s ibus_req;
    bus_pkg::bus_rsp_s ibus_rsp;

    integer tests = 0;
    integer errors = 0;

    cpu_memory dut (
        .clk(clk),
        .ibus_req(ibus_req),
        .ibus_rsp(ibus_rsp)
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
        $dumpfile("cpu_memory.vcd");
        $dumpvars(0, cpu_memory_tb);

        ibus_req.valid = 1'b0;
        ibus_req.op = bus_pkg::BUS_READ;
        ibus_req.addr = '0;
        ibus_req.wdata = '0;

        #1;
        check(ibus_rsp.ready === 1'b0, "idle slave does not report a completed transfer");
        check(ibus_rsp.rdata === '0, "idle read data is zero");

        // STORE one complete global word at byte address WORD_BYTES.
        @(negedge clk);
        ibus_req.valid = 1'b1;
        ibus_req.op = bus_pkg::BUS_WRITE;
        ibus_req.addr = word_t'(WORD_BYTES);
        ibus_req.wdata = word_t'(32'hDEAD_BEEF);
        #1;
        check(ibus_rsp.ready === 1'b1, "local memory accepts STORE immediately");

        @(posedge clk);
        #1;
        ibus_req.valid = 1'b0;
        ibus_req.op = bus_pkg::BUS_READ;

        // LOAD the word back.
        @(negedge clk);
        ibus_req.valid = 1'b1;
        ibus_req.op = bus_pkg::BUS_READ;
        ibus_req.addr = word_t'(WORD_BYTES);
        #1;
        check(ibus_rsp.ready === 1'b1, "local memory accepts LOAD immediately");
        check(ibus_rsp.rdata === word_t'(32'hDEAD_BEEF),
              "aligned STORE/LOAD round trip");

        // Adjacent word remains independent.
        ibus_req.addr = word_t'(2 * WORD_BYTES);
        #1;
        check(ibus_rsp.rdata === '0, "adjacent word unchanged");

        // Misaligned LOAD completes with zero rather than deadlocking.
        ibus_req.addr = word_t'(WORD_BYTES + 1);
        #1;
        check(ibus_rsp.ready === 1'b1, "misaligned LOAD still completes");
        check(ibus_rsp.rdata === '0, "misaligned LOAD returns zero");

        // Misaligned STORE completes but is ignored.
        @(negedge clk);
        ibus_req.op = bus_pkg::BUS_WRITE;
        ibus_req.addr = word_t'(1);
        ibus_req.wdata = word_t'('1);
        #1;
        check(ibus_rsp.ready === 1'b1, "misaligned STORE still completes");
        @(posedge clk);
        #1;

        // Verify memory word zero was not modified.
        @(negedge clk);
        ibus_req.op = bus_pkg::BUS_READ;
        ibus_req.addr = word_t'(0);
        #1;
        check(ibus_rsp.rdata === '0, "misaligned STORE is ignored");

        // First ibus_req.addr immediately beyond configured memory is invalid.
        ibus_req.addr = word_t'(CPU_MEMORY_COUNT * WORD_BYTES);
        #1;
        check(ibus_rsp.ready === 1'b1, "out-of-range LOAD still completes");
        check(ibus_rsp.rdata === '0, "out-of-range LOAD returns zero");

        ibus_req.valid = 1'b0;
        #1;
        check(ibus_rsp.ready === 1'b0, "ready drops after request is removed");

        $display("========================================");
        $display("LACOODA DATA MEMORY BUS TEST SUMMARY");
        $display("Total tests : %0d", tests);
        $display("Passed      : %0d", tests-errors);
        $display("Failed      : %0d", errors);
        $display("========================================");

        if (errors != 0)
            $fatal(1, "DATA MEMORY BUS TEST FAILED");

        $display("ALL DATA MEMORY BUS TESTS PASSED");
        $finish;
    end
endmodule
