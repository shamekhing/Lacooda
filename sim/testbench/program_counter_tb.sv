`timescale 1ns/1ps

module program_counter_tb;
    import cpu_pkg::*;
    localparam data_t REDIRECT_TARGET = 8 * INSTRUCTION_BYTES;

    logic clk = 0;
    logic rst = 1;
    logic enable = 0;
    logic redirect = 0;

    data_t target = 0;
    data_t pc;

    always #5 clk = ~clk;

    program_counter dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .redirect(redirect),
        .target(target),
        .pc(pc)
    );

    task automatic check_pc(input data_t expected);
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
        check_pc('0);

        // First instruction
        @(negedge clk);
        rst = 0;
        enable = 1;

        @(posedge clk);
        #1;
        check_pc(INSTRUCTION_BYTES);

        // Second instruction
        @(posedge clk);
        #1;
        check_pc(2 * INSTRUCTION_BYTES);

        // Hold
        @(negedge clk);
        enable = 0;

        @(posedge clk);
        #1;
        check_pc(2 * INSTRUCTION_BYTES);

        // Redirect
        @(negedge clk);
        enable = 1;
        redirect = 1;
        target = REDIRECT_TARGET;

        @(posedge clk);
        #1;
        check_pc(REDIRECT_TARGET);

        // Resume sequential execution
        @(negedge clk);
        redirect = 0;

        @(posedge clk);
        #1;
        check_pc(REDIRECT_TARGET + INSTRUCTION_BYTES);

        $display("PASS: program_counter_tb");
        $finish;
    end

endmodule
