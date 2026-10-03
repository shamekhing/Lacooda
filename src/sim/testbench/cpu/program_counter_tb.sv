`timescale 1ns/1ps

module program_counter_tb;
    import cpu_pkg::*;
    localparam word_t REDIRECT_TARGET = 8 * WORD_BYTES;

    logic clk = 0;
    logic rst = 1;
    logic enable = 0;
    logic redirect = 0;
    logic immediate_follows = 0;

    word_t target = 0;
    word_t pc;

    always #5 clk = ~clk;

    program_counter dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .redirect(redirect),
        .target(target),
        .has_imm(immediate_follows),
        .pc(pc)
    );

    task automatic check_pc(input word_t expected);
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

        // First instruction without an immediate word.
        @(negedge clk);
        rst = 0;
        enable = 1;
        immediate_follows = 0;

        @(posedge clk);
        #1;
        check_pc(WORD_BYTES);

        // Second instruction skips its immediate word.
        @(negedge clk);
        immediate_follows = 1;
        @(posedge clk);
        #1;
        check_pc(3 * WORD_BYTES);

        // Hold
        @(negedge clk);
        enable = 0;

        @(posedge clk);
        #1;
        check_pc(3 * WORD_BYTES);

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
        immediate_follows = 0;

        @(posedge clk);
        #1;
        check_pc(REDIRECT_TARGET + WORD_BYTES);

        $display("PASS: program_counter_tb");
        $finish;
    end

endmodule
