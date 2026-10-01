`timescale 1ns/1ps

// ============================================================
// Data-memory bus-slave regression
//
// Verifies the local memory's valid/ready protocol, byte-slave_address
// indexing, combinational LOAD response, synchronous STORE commit,
// and the preserved invalid-slave_address behavior.
// ============================================================

module data_memory_tb;
    import cpu_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic slave_valid;
    logic slave_write;
    reg_t slave_address;
    reg_t slave_write_data;
    logic slave_ready;
    reg_t slave_read_data;

    integer tests = 0;
    integer errors = 0;

    data_memory dut (
        .clk(clk),
        .slave_valid(slave_valid),
        .slave_write(slave_write),
        .slave_address(slave_address),
        .slave_write_data(slave_write_data),
        .slave_ready(slave_ready),
        .slave_read_data(slave_read_data)
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

        slave_valid = 1'b0;
        slave_write = 1'b0;
        slave_address = '0;
        slave_write_data = '0;

        #1;
        check(slave_ready === 1'b0, "idle slave does not report a completed transfer");
        check(slave_read_data === '0, "idle read data is zero");

        // STORE one complete REG_FILE_WIDTH word at byte address REG_FILE_BYTES.
        @(negedge clk);
        slave_valid = 1'b1;
        slave_write = 1'b1;
        slave_address = reg_t'(REG_FILE_BYTES);
        slave_write_data = reg_t'(64'h1122_3344_5566_7788);
        #1;
        check(slave_ready === 1'b1, "local memory accepts STORE immediately");

        @(posedge clk);
        #1;
        slave_valid = 1'b0;
        slave_write = 1'b0;

        // LOAD the word back.
        @(negedge clk);
        slave_valid = 1'b1;
        slave_write = 1'b0;
        slave_address = reg_t'(REG_FILE_BYTES);
        #1;
        check(slave_ready === 1'b1, "local memory accepts LOAD immediately");
        check(slave_read_data === reg_t'(64'h1122_3344_5566_7788),
              "aligned STORE/LOAD round trip");

        // Adjacent word remains independent.
        slave_address = reg_t'(2 * REG_FILE_BYTES);
        #1;
        check(slave_read_data === '0, "adjacent word unchanged");

        // Misaligned LOAD completes with zero rather than deadlocking.
        slave_address = reg_t'(REG_FILE_BYTES + 1);
        #1;
        check(slave_ready === 1'b1, "misaligned LOAD still completes");
        check(slave_read_data === '0, "misaligned LOAD returns zero");

        // Misaligned STORE completes but is ignored.
        @(negedge clk);
        slave_write = 1'b1;
        slave_address = reg_t'(1);
        slave_write_data = reg_t'('1);
        #1;
        check(slave_ready === 1'b1, "misaligned STORE still completes");
        @(posedge clk);
        #1;

        // Verify memory word zero was not modified.
        @(negedge clk);
        slave_write = 1'b0;
        slave_address = reg_t'(0);
        #1;
        check(slave_read_data === '0, "misaligned STORE is ignored");

        // First slave_address immediately beyond configured memory is invalid.
        slave_address = reg_t'(DATA_MEMORY_COUNT * DATA_MEMORY_BYTES);
        #1;
        check(slave_ready === 1'b1, "out-of-range LOAD still completes");
        check(slave_read_data === '0, "out-of-range LOAD returns zero");

        slave_valid = 1'b0;
        #1;
        check(slave_ready === 1'b0, "ready drops after request is removed");

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
