`timescale 1ns/1ps

// ============================================================
// LACOODA instruction-fetch / I-BUS regression
// ============================================================

module instruction_fetch_tb;
    import cpu_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst = 1'b1;
    logic run = 1'b0;
    logic retire = 1'b0;
    logic redirect = 1'b0;
    reg_t redirect_target = '0;

    logic ibus_valid;
    reg_t ibus_address;
    logic ibus_ready = 1'b0;
    instruction_t ibus_read_data = '0;

    reg_t pc;
    instruction_t instruction;
    logic instruction_available;

    integer tests = 0;
    integer errors = 0;

    instruction_fetch dut (
        .clk(clk),
        .rst(rst),
        .run(run),
        .retire(retire),
        .redirect(redirect),
        .redirect_target(redirect_target),
        .ibus_valid(ibus_valid),
        .ibus_address(ibus_address),
        .ibus_ready(ibus_ready),
        .ibus_read_data(ibus_read_data),
        .pc(pc),
        .instruction(instruction),
        .instruction_available(instruction_available)
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
        $dumpfile("instruction_fetch.vcd");
        $dumpvars(0, instruction_fetch_tb);

        @(posedge clk);
        #1;
        check(pc === '0 && !ibus_valid && !instruction_available,
              "reset clears PC/fetch state");

        @(negedge clk);
        rst = 1'b0;
        run = 1'b1;
        @(posedge clk);
        #1;
        check(ibus_valid && ibus_address === reg_t'(0),
              "run starts I-BUS request at current PC");

        // Started request survives pause and keeps address stable.
        @(negedge clk);
        run = 1'b0;
        @(posedge clk);
        #1;
        check(ibus_valid && ibus_address === reg_t'(0),
              "waiting I-BUS request is held across pause");

        // Accept instruction.
        @(negedge clk);
        ibus_read_data = instruction_t'('h1234);
        ibus_ready = 1'b1;
        @(posedge clk);
        #1;
        ibus_ready = 1'b0;
        check(instruction_available && instruction === instruction_t'('h1234),
              "I-BUS handshake fills instruction buffer");
        check(pc === reg_t'(0),
              "fetch handshake alone does not advance PC");

        // Retire sequentially while paused. No new fetch should start.
        @(negedge clk);
        retire = 1'b1;
        @(posedge clk);
        #1;
        retire = 1'b0;
        check(pc === reg_t'(INSTRUCTION_MEMORY_BYTES),
              "sequential retirement advances PC");
        check(!instruction_available && !ibus_valid,
              "paused retirement leaves fetch idle");

        // Resume, fetch second instruction, then retire with redirect.
        @(negedge clk);
        run = 1'b1;
        @(posedge clk);
        #1;
        check(ibus_valid && ibus_address === reg_t'(INSTRUCTION_MEMORY_BYTES),
              "resume fetches sequential PC");

        @(negedge clk);
        ibus_read_data = instruction_t'('h5678);
        ibus_ready = 1'b1;
        @(posedge clk);
        #1;
        ibus_ready = 1'b0;
        check(instruction_available && instruction === instruction_t'('h5678),
              "second instruction is buffered");

        @(negedge clk);
        redirect = 1'b1;
        redirect_target = reg_t'(8 * INSTRUCTION_MEMORY_BYTES);
        retire = 1'b1;
        @(posedge clk);
        #1;
        retire = 1'b0;
        redirect = 1'b0;
        check(pc === reg_t'(8 * INSTRUCTION_MEMORY_BYTES),
              "redirect retirement loads target PC");
        check(ibus_valid && ibus_address === reg_t'(8 * INSTRUCTION_MEMORY_BYTES),
              "run starts target fetch immediately after redirect");

        $display("========================================");
        $display("LACOODA INSTRUCTION FETCH TEST SUMMARY");
        $display("Total tests : %0d", tests);
        $display("Passed      : %0d", tests-errors);
        $display("Failed      : %0d", errors);
        $display("========================================");

        if (errors != 0)
            $fatal(1, "INSTRUCTION FETCH TEST FAILED");

        $display("ALL INSTRUCTION FETCH TESTS PASSED");
        $finish;
    end

endmodule
