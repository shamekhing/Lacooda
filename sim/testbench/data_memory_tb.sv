`timescale 1ns/1ps

// ============================================================
// Stage 7 data-memory regression
//
// Verifies byte-address indexing, combinational reads, synchronous
// writes, disabled reads, and rejection of misaligned/out-of-range
// accesses.
// ============================================================

module data_memory_tb;
    import cpu_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic read_enable;
    logic write_enable;
    data_t address;
    data_t write_data;
    data_t read_data;

    integer tests = 0;
    integer errors = 0;

    data_memory dut (
        .clk(clk),
        .read_enable(read_enable),
        .write_enable(write_enable),
        .address(address),
        .write_data(write_data),
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

        read_enable = 1'b0;
        write_enable = 1'b0;
        address = '0;
        write_data = '0;

        #1;
        check(read_data === '0, "disabled read returns zero");

        // Write one complete DATA_WIDTH word at byte address DATA_BYTES.
        @(negedge clk);
        address = data_t'(DATA_BYTES);
        write_data = data_t'(64'h1122_3344_5566_7788);
        write_enable = 1'b1;
        @(posedge clk);
        #1;
        write_enable = 1'b0;

        read_enable = 1'b1;
        #1;
        check(read_data === data_t'(64'h1122_3344_5566_7788),
              "aligned write/read round trip");

        // Adjacent word remains independent.
        address = data_t'(2 * DATA_BYTES);
        #1;
        check(read_data === '0, "adjacent word unchanged");

        // Misaligned read is rejected.
        address = data_t'(DATA_BYTES + 1);
        #1;
        check(read_data === '0, "misaligned read returns zero");

        // Misaligned write is ignored.
        @(negedge clk);
        read_enable = 1'b0;
        write_enable = 1'b1;
        address = data_t'(1);
        write_data = data_t'('1);
        @(posedge clk);
        #1;
        write_enable = 1'b0;
        read_enable = 1'b1;
        address = data_t'(0);
        #1;
        check(read_data === '0, "misaligned write ignored");

        // First address immediately beyond the configured memory is invalid.
        address = data_t'(DATA_MEMORY_DEPTH * DATA_BYTES);
        #1;
        check(read_data === '0, "out-of-range read returns zero");

        $display("========================================");
        $display("LACOODA STAGE 7 DATA MEMORY TEST SUMMARY");
        $display("Total tests : %0d", tests);
        $display("Passed      : %0d", tests-errors);
        $display("Failed      : %0d", errors);
        $display("========================================");

        if (errors != 0)
            $fatal(1, "DATA MEMORY TEST FAILED");

        $display("ALL DATA MEMORY TESTS PASSED");
        $finish;
    end
endmodule
