`timescale 1ns/1ps
module register_file_tb;
    localparam int DATA_WIDTH = 64;
    localparam int ADDR_WIDTH = 8;
    logic clk = 0;
    logic rst = 0;
    logic [ADDR_WIDTH-1:0] read_addr_a = 0, read_addr_b = 0;
    logic [DATA_WIDTH-1:0] read_data_a, read_data_b;
    logic write_enable = 0;
    logic [ADDR_WIDTH-1:0] write_addr = 0;
    logic [DATA_WIDTH-1:0] write_data = 0;
    integer tests = 0, errors = 0;

    register_file #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) dut (
        .clk(clk), .rst(rst),
        .read_addr_a(read_addr_a), .read_data_a(read_data_a),
        .read_addr_b(read_addr_b), .read_data_b(read_data_b),
        .write_enable(write_enable), .write_addr(write_addr), .write_data(write_data)
    );
    always #5 clk = ~clk;

    task automatic check(input logic [63:0] expected_a, expected_b, input string description);
        begin
            #1;
            tests = tests + 1;
            if (read_data_a !== expected_a || read_data_b !== expected_b) begin
                errors = errors + 1;
                $display("FAIL %0d %s: A=%h expected=%h B=%h expected=%h", tests, description,
                         read_data_a, expected_a, read_data_b, expected_b);
            end else $display("PASS %0d %s", tests, description);
        end
    endtask

    task automatic write_reg(input logic [7:0] address, input logic [63:0] value);
        begin
            @(negedge clk);
            write_enable = 1;
            write_addr = address;
            write_data = value;
            @(posedge clk);
            #1;
            @(negedge clk);
            write_enable = 0;
        end
    endtask

    initial begin
        $dumpfile("register_file.vcd");
        $dumpvars(0, register_file_tb);
        // Assert reset after time zero so its edge is unambiguous.
        #1 rst = 1;
        read_addr_a = 8'd1;
        read_addr_b = 8'd255;
        check(0, 0, "asynchronous reset clears registers");
        @(negedge clk);
        rst = 0;

        write_reg(8'd1, 64'd10);
        write_reg(8'd2, 64'd20);
        write_reg(8'd255, 64'hDEADBEEFCAFEBABE);
        read_addr_a = 8'd1;
        read_addr_b = 8'd2;
        check(10, 20, "two independent asynchronous reads");
        read_addr_a = 8'd255;
        read_addr_b = 8'd1;
        check(64'hDEADBEEFCAFEBABE, 10, "highest register address");

        write_reg(8'd0, 64'hFFFFFFFFFFFFFFFF);
        read_addr_a = 8'd0;
        read_addr_b = 8'd255;
        check(0, 64'hDEADBEEFCAFEBABE, "R0 ignores writes");

        // Inputs change but storage must not change before a rising edge.
        @(negedge clk);
        write_enable = 1;
        write_addr = 8'd2;
        write_data = 64'd99;
        read_addr_a = 8'd2;
        read_addr_b = 8'd2;
        check(20, 20, "write is not visible before rising edge");
        @(posedge clk);
        check(99, 99, "write visible after rising edge");
        @(negedge clk);
        write_enable = 0;
        write_data = 64'd1234;
        @(posedge clk);
        check(99, 99, "write disabled preserves register");

        // Reset clears previously written registers without waiting for a clock.
        @(negedge clk);
        rst = 1;
        read_addr_a = 8'd1;
        read_addr_b = 8'd255;
        check(0, 0, "asynchronous reset after writes");
        rst = 0;
        $display("TESTS=%0d PASSED=%0d FAILED=%0d", tests, tests-errors, errors);
        if (errors != 0) $fatal(1, "REGISTER FILE TEST FAILED");
        $display("ALL REGISTER FILE TESTS PASSED");
        $finish;
    end
endmodule