`timescale 1ns/1ps

// ============================================================
// LACOODA Stage 6 branch-unit regression
//
// Tests every branch condition independently from the decoder, PC,
// instruction memory and CPU. This makes failures easy to localize.
// ============================================================

module branch_unit_tb;

    import cpu_pkg::*;
    import opcode_pkg::*;

    logic enable;
    opcode_t opcode;
    word_t lhs;
    word_t rhs;
    word_t target;

    logic redirect;
    word_t redirect_target;

    integer tests = 0;
    integer errors = 0;

    branch_unit dut (
        .enable(enable),
        .opcode(opcode),
        .operand_a(lhs),
        .operand_b(rhs),
        .target(target),
        .redirect(redirect),
        .redirect_target(redirect_target)
    );

    task automatic check_branch(
        input string description,
        input logic expected_redirect
    );
        begin
            #1;
            tests = tests + 1;

            if (redirect !== expected_redirect) begin
                errors = errors + 1;
                $display("FAIL %0d %s redirect expected=%b actual=%b",
                         tests, description, expected_redirect, redirect);
            end else if (redirect_target !== target) begin
                errors = errors + 1;
                $display("FAIL %0d %s target expected=%h actual=%h",
                         tests, description, target, redirect_target);
            end else begin
                $display("PASS %0d %s", tests, description);
            end
        end
    endtask

    initial begin
        $dumpfile("branch_unit.vcd");
        $dumpvars(0, branch_unit_tb);

        enable = 1'b1;
        target = word_t'(64);
        lhs = '0;
        rhs = '0;

        opcode = opcode_pkg::CTRL_JMP;
        check_branch("JMP always redirects", 1'b1);

        lhs = word_t'(10);
        rhs = word_t'(10);
        opcode = opcode_pkg::CTRL_BEQ;
        check_branch("BEQ taken", 1'b1);

        rhs = word_t'(11);
        check_branch("BEQ not taken", 1'b0);

        opcode = opcode_pkg::CTRL_BNE;
        check_branch("BNE taken", 1'b1);

        rhs = word_t'(10);
        check_branch("BNE not taken", 1'b0);

        // Same raw lhs value (-1 / all ones) produces different signed
        // and unsigned ordering relative to +1.
        lhs = word_t'(-1);
        rhs = word_t'(1);

        opcode = opcode_pkg::CTRL_BLT;
        check_branch("BLT signed -1 < 1", 1'b1);

        opcode = opcode_pkg::CTRL_BGE;
        check_branch("BGE signed -1 >= 1", 1'b0);

        opcode = opcode_pkg::CTRL_BLTU;
        check_branch("BLTU unsigned max < 1", 1'b0);

        opcode = opcode_pkg::CTRL_BGEU;
        check_branch("BGEU unsigned max >= 1", 1'b1);

        // Disable must suppress even an unconditional jump.
        enable = 1'b0;
        opcode = opcode_pkg::CTRL_JMP;
        check_branch("disabled unit never redirects", 1'b0);

        $display("========================================");
        $display("LACOODA STAGE 6 BRANCH UNIT TEST SUMMARY");
        $display("Total tests : %0d", tests);
        $display("Passed      : %0d", tests-errors);
        $display("Failed      : %0d", errors);
        $display("========================================");

        if (errors != 0)
            $fatal(1, "BRANCH UNIT TEST FAILED");

        $display("ALL BRANCH UNIT TESTS PASSED");
        $finish;
    end

endmodule
