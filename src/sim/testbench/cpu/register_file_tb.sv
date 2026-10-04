`timescale 1ns/1ps
module cpu_register_tb;
    import cpu_pkg::*;

    logic clk = 0;
    logic rst = 0;
    reg_addr_t read_addr_a = 0, read_addr_b = 0;
    word_t read_data_a, read_data_b;
    logic write_enable = 0;
    reg_addr_t write_addr = 0;
    word_t write_data = 0;
    integer tests = 0;
    integer errors = 0;

    cpu_register dut (
        .clk(clk), .rst(rst),
        .rs1_addr(read_addr_a), .rs1_data(read_data_a),
        .rs2_addr(read_addr_b), .rs2_data(read_data_b),
        .write_enable(write_enable), .write_addr(write_addr), .write_data(write_data)
    );
    always #5 clk = ~clk;

    task automatic check(input word_t expected_a, expected_b, input string description);
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

    task automatic write_reg(input reg_addr_t address, input word_t value);
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
        $dumpfile("cpu_register.vcd");
        $dumpvars(0, cpu_register_tb);
        // Assert reset after time zero so its edge is unambiguous.
        #1 rst = 1;
        read_addr_a = reg_addr_t'(1);
        read_addr_b = reg_addr_t'(REG_FILE_COUNT - 1);
        check(0, 0, "asynchronous reset clears registers");
        @(negedge clk);
        rst = 0;

        write_reg(reg_addr_t'(1), word_t'(10));
        write_reg(reg_addr_t'(2), word_t'(20));
        write_reg(reg_addr_t'(REG_FILE_COUNT - 1), word_t'(32'hDEADBEEF));
        read_addr_a = reg_addr_t'(1);
        read_addr_b = reg_addr_t'(2);
        check(10, 20, "two independent asynchronous reads");
        read_addr_a = reg_addr_t'(REG_FILE_COUNT - 1);
        read_addr_b = reg_addr_t'(1);
        check(word_t'(32'hDEADBEEF), 10, "highest register address");

        write_reg(reg_addr_t'(0), word_t'('1));
        read_addr_a = reg_addr_t'(0);
        read_addr_b = reg_addr_t'(REG_FILE_COUNT - 1);
        check(0, word_t'(32'hDEADBEEF), "R0 ignores writes");

        // Inputs change but storage must not change before a rising edge.
        @(negedge clk);
        write_enable = 1;
        write_addr = reg_addr_t'(2);
        write_data = word_t'(99);
        read_addr_a = reg_addr_t'(2);
        read_addr_b = reg_addr_t'(2);
        check(20, 20, "write is not visible before rising edge");
        @(posedge clk);
        check(99, 99, "write visible after rising edge");
        @(negedge clk);
        write_enable = 0;
        write_data = word_t'(1234);
        @(posedge clk);
        check(99, 99, "write disabled preserves register");

        // Reset clears previously written registers without waiting for a clock.
        @(negedge clk);
        rst = 1;
        read_addr_a = reg_addr_t'(1);
        read_addr_b = reg_addr_t'(REG_FILE_COUNT - 1);
        check(0, 0, "asynchronous reset after writes");
        rst = 0;
        $display("TESTS=%0d PASSED=%0d FAILED=%0d", tests, tests-errors, errors);
        if (errors != 0) $fatal(1, "REGISTER FILE TEST FAILED");
        $display("ALL REGISTER FILE TESTS PASSED");
        $finish;
    end
endmodule
