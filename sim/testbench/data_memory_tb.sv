`timescale 1ns/1ps

// ============================================================
// Data-memory bus-slave regression
//
// Verifies the local memory's valid/ready protocol, byte-address
// indexing, combinational LOAD response, synchronous STORE commit,
// and the preserved invalid-address behavior.
// ============================================================

module data_memory_tb;
    import cpu_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic bus_valid;
    logic bus_write;
    data_t address;
    data_t write_data;
    logic bus_ready;
    data_t read_data;

    integer tests = 0;
    integer errors = 0;

    data_memory dut (
        .clk(clk),
        .bus_valid(bus_valid),
        .bus_write(bus_write),
        .address(address),
        .write_data(write_data),
        .bus_ready(bus_ready),
        .read_data(read_data)
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
        $dumpfile("data_memory.vcd");
        $dumpvars(0, data_memory_tb);

        bus_valid = 1'b0;
        bus_write = 1'b0;
        address = '0;
        write_data = '0;

        #1;
        check(bus_ready === 1'b0, "idle slave does not report a completed transfer");
        check(read_data === '0, "idle read data is zero");

        // STORE one complete DATA_WIDTH word at byte address DATA_BYTES.
        @(negedge clk);
        bus_valid = 1'b1;
        bus_write = 1'b1;
        address = data_t'(DATA_BYTES);
        write_data = data_t'(64'h1122_3344_5566_7788);
        #1;
        check(bus_ready === 1'b1, "local memory accepts STORE immediately");

        @(posedge clk);
        #1;
        bus_valid = 1'b0;
        bus_write = 1'b0;

        // LOAD the word back.
        @(negedge clk);
        bus_valid = 1'b1;
        bus_write = 1'b0;
        address = data_t'(DATA_BYTES);
        #1;
        check(bus_ready === 1'b1, "local memory accepts LOAD immediately");
        check(read_data === data_t'(64'h1122_3344_5566_7788),
              "aligned STORE/LOAD round trip");

        // Adjacent word remains independent.
        address = data_t'(2 * DATA_BYTES);
        #1;
        check(read_data === '0, "adjacent word unchanged");

        // Misaligned LOAD completes with zero rather than deadlocking.
        address = data_t'(DATA_BYTES + 1);
        #1;
        check(bus_ready === 1'b1, "misaligned LOAD still completes");
        check(read_data === '0, "misaligned LOAD returns zero");

        // Misaligned STORE completes but is ignored.
        @(negedge clk);
        bus_write = 1'b1;
        address = data_t'(1);
        write_data = data_t'('1);
        #1;
        check(bus_ready === 1'b1, "misaligned STORE still completes");
        @(posedge clk);
        #1;

        // Verify memory word zero was not modified.
        @(negedge clk);
        bus_write = 1'b0;
        address = data_t'(0);
        #1;
        check(read_data === '0, "misaligned STORE is ignored");

        // First address immediately beyond configured memory is invalid.
        address = data_t'(DATA_MEMORY_DEPTH * DATA_BYTES);
        #1;
        check(bus_ready === 1'b1, "out-of-range LOAD still completes");
        check(read_data === '0, "out-of-range LOAD returns zero");

        bus_valid = 1'b0;
        #1;
        check(bus_ready === 1'b0, "ready drops after request is removed");

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
