`timescale 1ns/1ps

// ============================================================
// LACOODA instruction-fetch / I-BUS regression
//
// Covers single-word fetches, two-word fetches (instruction plus the
// immediate word that follows it), PC skipping, pause/hold guarantees
// and redirect behaviour.
// ============================================================

module instruction_fetch_tb;
    import cpu_pkg::*;
    import opcode_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst = 1'b1;
    logic run = 1'b0;
    logic retire = 1'b0;
    logic redirect = 1'b0;
    word_t redirect_target = '0;

    bus_pkg::bus_req_t ibus_req;
    bus_pkg::bus_rsp_t ibus_rsp;

    word_t pc;
    instruction_t instruction;
    word_t immediate_word;
    logic instruction_available;

    integer tests = 0;
    integer errors = 0;

    // MOVI R1 (I=1): an instruction that is followed by an immediate word.
    instruction_t movi_instr;

    instruction_fetch dut (
        .clk(clk),
        .rst(rst),
        .run(run),
        .retire(retire),
        .redirect(redirect),
        .redirect_target(redirect_target),
        .ibus_req(ibus_req),
        .ibus_rsp(ibus_rsp),
        .pc(pc),
        .instruction(instruction),
        .immediate_word(immediate_word),
        .instruction_available(instruction_available)
    );

    task automatic check(input logic condition, input string description);
        begin
            tests = tests + 1;
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL %0d %s", tests, description);
            end else $display("PASS %0d %s", tests, description);
        end
    endtask

    initial begin
        $dumpfile("instruction_fetch.vcd");
        $dumpvars(0, instruction_fetch_tb);
        movi_instr = encode_instruction(ALU_PASS_B, reg_addr_t'(1),
                                        ZERO_REG, ZERO_REG, 1'b1, 1'b0);
        movi_instr = encode_instruction(ALU_PASS_B, reg_addr_t'(1), ZERO_REG, ZERO_REG, 1'b1, 1'b0);

        @(posedge clk);
        #1;
        check(pc === '0 && !ibus_req.valid && !instruction_available,
              "reset clears PC/fetch state");

        @(negedge clk);
        rst = 1'b0;
        run = 1'b1;
        @(posedge clk);
        #1;
        check(ibus_req.valid && ibus_req.addr === word_t'(0),
              "run starts I-BUS request at current PC");

        // Started request survives pause and keeps address stable.
        @(negedge clk);
        run = 1'b0;
        @(posedge clk);
        #1;
        check(ibus_req.valid && ibus_req.addr === word_t'(0),
              "waiting I-BUS request is held across pause");

        // Accept a one-word instruction (no immediate follows).
        @(negedge clk);
        ibus_rsp.rdata = 'h1234;
        ibus_rsp.ready = 1'b1;
        @(posedge clk);
        #1;
        ibus_rsp.ready = 1'b0;
        check(instruction_available && instruction === instruction_t'('h1234),
              "I-BUS handshake fills instruction buffer");
        check(pc === word_t'(0),
              "fetch handshake alone does not advance PC");

        // Retire sequentially while paused. No new fetch should start.
        @(negedge clk);
        retire = 1'b1;
        @(posedge clk);
        #1;
        retire = 1'b0;
        check(pc === word_t'(WORD_BYTES),
              "sequential retirement advances PC by one word");
        check(!instruction_available && !ibus_req.valid,
              "paused retirement leaves fetch idle");

        // Resume: fetch an instruction that uses an immediate word.
        @(negedge clk);
        run = 1'b1;
        @(posedge clk);
        #1;
        check(ibus_req.valid && ibus_req.addr === word_t'(WORD_BYTES),
              "resume fetches sequential PC");

        @(negedge clk);
        ibus_rsp.rdata = movi_instr;
        ibus_rsp.ready = 1'b1;
        @(posedge clk);
        #1;
        ibus_rsp.ready = 1'b0;
        check(!instruction_available && ibus_req.valid &&
              ibus_req.addr === word_t'(2 * WORD_BYTES),
              "immediate fetch follows the instruction word");

        // The immediate request is held until accepted, even when paused.
        @(negedge clk);
        run = 1'b0;
        @(posedge clk);
        #1;
        check(ibus_req.valid && ibus_req.addr === word_t'(2 * WORD_BYTES),
              "waiting immediate request is held across pause");

        @(negedge clk);
        ibus_rsp.rdata = word_t'(32'hABCD_1234);
        ibus_rsp.ready = 1'b1;
        @(posedge clk);
        #1;
        ibus_rsp.ready = 1'b0;
        check(instruction_available && instruction === movi_instr &&
              immediate_word === word_t'(32'hABCD_1234),
              "instruction and immediate word are buffered together");

        // Retiring an immediate instruction skips the immediate word.
        @(negedge clk);
        retire = 1'b1;
        @(posedge clk);
        #1;
        retire = 1'b0;
        check(pc === word_t'(3 * WORD_BYTES),
              "retirement after immediate advances PC by two words");

        // Redirect: single-word instruction after the target.
        @(negedge clk);
        run = 1'b1;
        redirect = 1'b1;
        redirect_target = word_t'(8 * WORD_BYTES);
        retire = 1'b1;
        @(posedge clk);
        #1;
        retire = 1'b0;
        redirect = 1'b0;
        check(pc === word_t'(8 * WORD_BYTES),
              "redirect retirement loads target PC");
        check(ibus_req.valid && ibus_req.addr === word_t'(8 * WORD_BYTES),
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
