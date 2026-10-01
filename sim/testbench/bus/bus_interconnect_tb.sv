`timescale 1ns/1ps

// ============================================================
// LACOODA data-bus interconnect regression
// ============================================================

module bus_interconnect_tb;
    import cpu_pkg::*;
    import bus_pkg::*;

    logic dbus_valid;
    logic dbus_write;
    reg_t dbus_address;
    reg_t dbus_write_data;
    logic dbus_ready;
    reg_t dbus_read_data;

    logic slave_valid;
    logic slave_write;
    reg_t slave_address;
    reg_t slave_write_data;
    logic slave_ready;
    reg_t slave_read_data;

    integer tests = 0;
    integer errors = 0;

    bus_interconnect dut (
        .dbus_valid(dbus_valid),
        .dbus_write(dbus_write),
        .dbus_address(dbus_address),
        .dbus_write_data(dbus_write_data),
        .dbus_ready(dbus_ready),
        .dbus_read_data(dbus_read_data),
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
        $dumpfile("bus_interconnect.vcd");
        $dumpvars(0, bus_interconnect_tb);

        dbus_valid = 1'b0;
        dbus_write = 1'b0;
        dbus_address = '0;
        dbus_write_data = '0;
        slave_ready = 1'b0;
        slave_read_data = reg_t'(16'h1234);
        #1;

        check(!dbus_ready && !slave_valid,
              "idle master produces no slave request");

        // Mapped request is forwarded and waits for the selected slave.
        dbus_valid = 1'b1;
        dbus_write = 1'b1;
        dbus_address = DATA_MEMORY_BASE + reg_t'(3 * REG_FILE_BYTES);
        dbus_write_data = reg_t'(16'h55AA);
        #1;
        check(slave_valid && slave_write,
              "mapped STORE selects data memory");
        check(slave_address === reg_t'(3 * REG_FILE_BYTES) &&
              slave_write_data === reg_t'(16'h55AA),
              "mapped STORE payload is forwarded");
        check(!dbus_ready,
              "master waits while selected slave is not ready");

        slave_ready = 1'b1;
        #1;
        check(dbus_ready,
              "selected slave ready is returned to master");

        dbus_write = 1'b0;
        slave_read_data = reg_t'(16'hCAFE);
        #1;
        check(dbus_read_data === reg_t'(16'hCAFE),
              "selected slave read data is returned to master");

        // First address after local RAM is unmapped. Current architectural
        // behavior completes such accesses immediately with zero data.
        dbus_address = DATA_MEMORY_LIMIT;
        slave_ready = 1'b0;
        slave_read_data = reg_t'(16'hFFFF);
        #1;
        check(!slave_valid,
              "unmapped address selects no data-memory slave");
        check(dbus_ready && dbus_read_data === '0,
              "unmapped access completes with zero response");

        dbus_valid = 1'b0;
        #1;
        check(!dbus_ready,
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
