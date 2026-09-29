`timescale 1ns/1ps

module program_counter_tb;

    logic clk = 0;
    logic rst = 1;
    logic enable = 0;
    logic redirect = 0;

    logic [63:0] target = 0;
    logic [63:0] pc;

    always #5 clk = ~clk;

    program_counter dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .redirect(redirect),
        .target(target),
        .pc(pc)
    );

    task automatic check_pc(input logic [63:0] expected);
        assert (pc === expected)
            else $fatal(1,
                "PC mismatch: expected %0d, got %0d",
                expected, pc);
    endtask

    initial begin
        $dumpfile("program_counter.vcd");
        $dumpvars(0, program_counter_tb);
        // Reset
        @(posedge clk);
        #1;
        check_pc(0);

        // First instruction
        @(negedge clk);
        rst = 0;
        enable = 1;

        @(posedge clk);
        #1;
        check_pc(8);

        // Second instruction
        @(posedge clk);
        #1;
        check_pc(16);

        // Hold
        @(negedge clk);
        enable = 0;

        @(posedge clk);
        #1;
        check_pc(16);

        // Redirect
        @(negedge clk);
        enable = 1;
        redirect = 1;
        target = 64;

        @(posedge clk);
        #1;
        check_pc(64);

        // Resume sequential execution
        @(negedge clk);
        redirect = 0;

        @(posedge clk);
        #1;
        check_pc(72);

        $display("PASS: program_counter_tb");
        $finish;
    end

endmodule