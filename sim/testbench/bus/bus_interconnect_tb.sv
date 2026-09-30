`timescale 1ns/1ps

// ============================================================
// LACOODA data-bus interconnect regression
// ============================================================

module bus_interconnect_tb;
    import cpu_pkg::*;
    import bus_pkg::*;

    logic master_valid;
    logic master_write;
    data_t master_address;
    data_t master_write_data;
    logic master_ready;
    data_t master_read_data;

    logic data_memory_valid;
    logic data_memory_write;
    data_t data_memory_address;
    data_t data_memory_write_data;
    logic data_memory_ready;
    data_t data_memory_read_data;

    integer tests = 0;
    integer errors = 0;

    bus_interconnect dut (
        .master_valid(master_valid),
        .master_write(master_write),
        .master_address(master_address),
        .master_write_data(master_write_data),
        .master_ready(master_ready),
        .master_read_data(master_read_data),
        .data_memory_valid(data_memory_valid),
        .data_memory_write(data_memory_write),
        .data_memory_address(data_memory_address),
        .data_memory_write_data(data_memory_write_data),
        .data_memory_ready(data_memory_ready),
        .data_memory_read_data(data_memory_read_data)
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
        $dumpfile("bus_interconnect.vcd");
        $dumpvars(0, bus_interconnect_tb);

        master_valid = 1'b0;
        master_write = 1'b0;
        master_address = '0;
        master_write_data = '0;
        data_memory_ready = 1'b0;
        data_memory_read_data = data_t'(16'h1234);
        #1;

        check(!master_ready && !data_memory_valid,
              "idle master produces no slave request");

        // Mapped request is forwarded and waits for the selected slave.
        master_valid = 1'b1;
        master_write = 1'b1;
        master_address = DATA_MEMORY_BASE + data_t'(3 * DATA_BYTES);
        master_write_data = data_t'(16'h55AA);
        #1;
        check(data_memory_valid && data_memory_write,
              "mapped STORE selects data memory");
        check(data_memory_address === data_t'(3 * DATA_BYTES) &&
              data_memory_write_data === data_t'(16'h55AA),
              "mapped STORE payload is forwarded");
        check(!master_ready,
              "master waits while selected slave is not ready");

        data_memory_ready = 1'b1;
        #1;
        check(master_ready,
              "selected slave ready is returned to master");

        master_write = 1'b0;
        data_memory_read_data = data_t'(16'hCAFE);
        #1;
        check(master_read_data === data_t'(16'hCAFE),
              "selected slave read data is returned to master");

        // First address after local RAM is unmapped. Current architectural
        // behavior completes such accesses immediately with zero data.
        master_address = DATA_MEMORY_LIMIT;
        data_memory_ready = 1'b0;
        data_memory_read_data = data_t'(16'hFFFF);
        #1;
        check(!data_memory_valid,
              "unmapped address selects no data-memory slave");
        check(master_ready && master_read_data === '0,
              "unmapped access completes with zero response");

        master_valid = 1'b0;
        #1;
        check(!master_ready,
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
