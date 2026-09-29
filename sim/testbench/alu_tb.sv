
`timescale 1ns/1ps

module alu_tb;

    import alu_pkg::*;

    localparam int WIDTH = 64;

    logic clk = 0;
    logic rst;
    logic write_enable;

    logic [WIDTH-1:0] A, B;
    logic [5:0] op;
    logic carry_in;

    logic [WIDTH-1:0] result;
    logic valid;

    alu_pkg::flags_t flags;
    alu_pkg::flags_t stored_flags;

    integer tests  = 0;
    integer errors = 0;

    // =========================================================
    // DUT: ALU
    // =========================================================

    alu #(.WIDTH(WIDTH)) dut (
        .A(A),
        .B(B),
        .op(op),
        .carry_in(carry_in),
        .result(result),
        .flags(flags),
        .valid(valid)
    );

    // =========================================================
    // DUT: STATUS REGISTER
    // =========================================================

    status_register u_status (
        .clk(clk),
        .rst(rst),
        .write_enable(write_enable),
        .flags_in(flags),
        .flags_out(stored_flags)
    );

    always #5 clk = ~clk;

    // =========================================================
    // TEST TASK
    // =========================================================

    task automatic check(
        input logic [5:0] operation,
        input logic [63:0] a,
        input logic [63:0] b,
        input logic cin,

        input logic [63:0] expected_result,

        input logic expected_c,
        input logic expected_v,
        input logic expected_dz,
        input logic expected_valid
    );

        logic expected_z;
        logic expected_n;

        begin

            op       = operation;
            A        = a;
            B        = b;
            carry_in = cin;

            #2;

            expected_z = expected_valid &&
                         (expected_result == 64'd0);

            expected_n = expected_valid &&
                         expected_result[63];

            tests = tests + 1;

            if (
                result   !== expected_result ||
                valid    !== expected_valid  ||
                flags.Z  !== expected_z      ||
                flags.N  !== expected_n      ||
                flags.C  !== expected_c      ||
                flags.V  !== expected_v      ||
                flags.DZ !== expected_dz
            ) begin

                errors = errors + 1;

                $display("\n[FAIL] Test %0d", tests);

                $display(
                    "OP=%h A=%h B=%h CIN=%b",
                    op, A, B, carry_in
                );

                $display(
                    "RESULT: got=%h expected=%h",
                    result, expected_result
                );

                $display(
                    "VALID: got=%b expected=%b",
                    valid, expected_valid
                );

                $display(
                    "FLAGS GOT: Z=%b N=%b C=%b V=%b DZ=%b",
                    flags.Z,
                    flags.N,
                    flags.C,
                    flags.V,
                    flags.DZ
                );

                $display(
                    "FLAGS EXP: Z=%b N=%b C=%b V=%b DZ=%b",
                    expected_z,
                    expected_n,
                    expected_c,
                    expected_v,
                    expected_dz
                );

            end else begin

                $display(
                    "[PASS] %0d OP=%h RESULT=%h",
                    tests, op, result
                );

            end

        end

    endtask

    // =========================================================
    // STATUS REGISTER CHECK
    // =========================================================

    task automatic check_status(
        input logic [4:0] expected
    );

        begin

            tests = tests + 1;

            if (stored_flags !== expected) begin

                errors = errors + 1;

                $display(
                    "[FAIL] STATUS got=%b expected=%b",
                    stored_flags,
                    expected
                );

            end else begin

                $display(
                    "[PASS] STATUS=%b",
                    stored_flags
                );

            end

        end

    endtask

    // =========================================================
    // MAIN
    // =========================================================

    initial begin

        $dumpfile("alu.vcd");
        $dumpvars(0, alu_tb);

        rst          = 1;
        write_enable = 0;

        A        = 0;
        B        = 0;
        op       = ALU_ADD;
        carry_in = 0;

        #2;

        check_status(5'b00000);

        rst = 0;

        // =====================================================
        // 01. ARITHMETIC: ADD / ADC / SUB / SBC
        // =====================================================

        $display("\n=== ADD / ADC / SUB / SBC ===");

        check(ALU_ADD, 10, 5, 0,
              15, 0, 0, 0, 1);

        check(ALU_ADC, 10, 5, 0,
              15, 0, 0, 0, 1);

        check(ALU_ADC, 10, 5, 1,
              16, 0, 0, 0, 1);

        check(ALU_SUB, 10, 5, 0,
              5, 1, 0, 0, 1);

        check(ALU_SBC, 10, 5, 1,
              5, 1, 0, 0, 1);

        check(ALU_SBC, 10, 5, 0,
              4, 1, 0, 0, 1);

        // Carry-out
        check(
            ALU_ADD,
            64'hFFFFFFFFFFFFFFFF,
            1,
            0,
            0,
            1, 0, 0, 1
        );

        // Signed overflow
        check(
            ALU_ADD,
            64'h7FFFFFFFFFFFFFFF,
            1,
            0,
            64'h8000000000000000,
            0, 1, 0, 1
        );

        // Negative signed overflow
        check(
            ALU_ADD,
            64'h8000000000000000,
            64'h8000000000000000,
            0,
            0,
            1, 1, 0, 1
        );

        // ADC carry-in
        check(
            ALU_ADC,
            64'hFFFFFFFFFFFFFFFF,
            0,
            1,
            0,
            1, 0, 0, 1
        );

        check(
            ALU_ADC,
            64'hFFFFFFFFFFFFFFFF,
            64'hFFFFFFFFFFFFFFFF,
            1,
            64'hFFFFFFFFFFFFFFFF,
            1, 0, 0, 1
        );

        // Borrow
        check(
            ALU_SUB,
            0,
            1,
            0,
            64'hFFFFFFFFFFFFFFFF,
            0, 0, 0, 1
        );

        // No borrow
        check(ALU_SUB, 5, 5, 0,
              0, 1, 0, 0, 1);

        // Subtraction overflow
        check(
            ALU_SUB,
            64'h8000000000000000,
            1,
            0,
            64'h7FFFFFFFFFFFFFFF,
            1, 1, 0, 1
        );

        // SBC with borrow-in
        check(
            ALU_SBC,
            0,
            0,
            0,
            64'hFFFFFFFFFFFFFFFF,
            0, 0, 0, 1
        );

        check(
            ALU_SBC,
            5,
            5,
            0,
            64'hFFFFFFFFFFFFFFFF,
            0, 0, 0, 1
        );

        check(ALU_SBC, 5, 5, 1,
              0, 1, 0, 0, 1);

        check(
            ALU_SBC,
            64'h8000000000000000,
            1,
            1,
            64'h7FFFFFFFFFFFFFFF,
            1, 1, 0, 1
        );

        // =====================================================
        // 02. MULTIPLICATION
        // =====================================================

        $display("\n=== MULTIPLICATION ===");

        check(ALU_MUL, 10, 5, 0,
              50, 0, 0, 0, 1);

        check(ALU_MUL, 0, 123, 0,
              0, 0, 0, 0, 1);

        // Low 64 bits
        check(
            ALU_MUL,
            64'hFFFFFFFFFFFFFFFF,
            2,
            0,
            64'hFFFFFFFFFFFFFFFE,
            0, 0, 0, 1
        );

        // Upper 64 bits
        check(
            ALU_MULH,
            64'hFFFFFFFFFFFFFFFF,
            2,
            0,
            1,
            0, 0, 0, 1
        );

        check(
            ALU_MULH,
            64'hFFFFFFFFFFFFFFFF,
            64'hFFFFFFFFFFFFFFFF,
            0,
            64'hFFFFFFFFFFFFFFFE,
            0, 0, 0, 1
        );

        check(ALU_MULH, 10, 5, 0,
              0, 0, 0, 0, 1);

        // =====================================================
        // 03. UNSIGNED DIVISION / MODULO
        // =====================================================

        $display("\n=== UNSIGNED DIV / MOD ===");

        check(ALU_DIVU, 100, 5, 0,
              20, 0, 0, 0, 1);

        check(ALU_MODU, 100, 6, 0,
              4, 0, 0, 0, 1);

        check(ALU_DIVU, 5, 10, 0,
              0, 0, 0, 0, 1);

        check(ALU_MODU, 5, 10, 0,
              5, 0, 0, 0, 1);

        check(ALU_DIVU, 100, 0, 0,
              0, 0, 0, 1, 1);

        check(ALU_MODU, 100, 0, 0,
              0, 0, 0, 1, 1);

        // =====================================================
        // 04. SIGNED DIVISION / MODULO
        // =====================================================

        $display("\n=== SIGNED DIV / MOD ===");

        check(
            ALU_DIVS,
            -64'sd100,
            64'd5,
            0,
            -64'sd20,
            0, 0, 0, 1
        );

        check(
            ALU_DIVS,
            -64'sd20,
            -64'sd4,
            0,
            5,
            0, 0, 0, 1
        );

        check(
            ALU_DIVS,
            64'd20,
            -64'sd4,
            0,
            -64'sd5,
            0, 0, 0, 1
        );

        check(
            ALU_MODS,
            -64'sd100,
            64'd6,
            0,
            -64'sd4,
            0, 0, 0, 1
        );

        check(
            ALU_MODS,
            -64'sd20,
            64'd6,
            0,
            -64'sd2,
            0, 0, 0, 1
        );

        check(
            ALU_MODS,
            64'd20,
            -64'sd6,
            0,
            2,
            0, 0, 0, 1
        );

        check(ALU_DIVS, 100, 0, 0,
              0, 0, 0, 1, 1);

        check(ALU_MODS, 100, 0, 0,
              0, 0, 0, 1, 1);

        // Minimum signed integer / -1
        check(
            ALU_DIVS,
            64'h8000000000000000,
            64'hFFFFFFFFFFFFFFFF,
            0,
            64'h8000000000000000,
            0, 1, 0, 1
        );

        check(
            ALU_MODS,
            64'h8000000000000000,
            64'hFFFFFFFFFFFFFFFF,
            0,
            0,
            0, 0, 0, 1
        );

        // =====================================================
        // 05. NEG / ABS / MIN / MAX
        // =====================================================

        $display("\n=== NEG / ABS / MIN / MAX ===");

        check(ALU_NEG, 5, 0, 0,
              -64'sd5, 0, 0, 0, 1);

        check(ALU_NEG, 0, 0, 0,
              0, 1, 0, 0, 1);

        check(
            ALU_NEG,
            64'h8000000000000000,
            0,
            0,
            64'h8000000000000000,
            0, 1, 0, 1
        );

        check(ALU_ABS, -64'sd5, 0, 0,
              5, 0, 0, 0, 1);

        check(ALU_ABS, 25, 0, 0,
              25, 0, 0, 0, 1);

        check(ALU_ABS, 0, 0, 0,
              0, 0, 0, 0, 1);

        check(
            ALU_ABS,
            64'h8000000000000000,
            0,
            0,
            64'h8000000000000000,
            0, 1, 0, 1
        );

        check(ALU_MINU, 5, 10, 0,
              5, 0, 0, 0, 1);

        check(ALU_MAXU, 5, 10, 0,
              10, 0, 0, 0, 1);

        check(
            ALU_MINU,
            64'hFFFFFFFFFFFFFFFF,
            1,
            0,
            1,
            0, 0, 0, 1
        );

        check(
            ALU_MAXU,
            64'hFFFFFFFFFFFFFFFF,
            1,
            0,
            64'hFFFFFFFFFFFFFFFF,
            0, 0, 0, 1
        );

        check(
            ALU_MINS,
            -64'sd5,
            10,
            0,
            -64'sd5,
            0, 0, 0, 1
        );

        check(
            ALU_MAXS,
            -64'sd5,
            10,
            0,
            10,
            0, 0, 0, 1
        );

        check(
            ALU_MINS,
            64'hFFFFFFFFFFFFFFFF,
            1,
            0,
            64'hFFFFFFFFFFFFFFFF,
            0, 0, 0, 1
        );

        check(
            ALU_MAXS,
            64'hFFFFFFFFFFFFFFFF,
            1,
            0,
            1,
            0, 0, 0, 1
        );

        // =====================================================
        // 06. BITWISE LOGIC
        // =====================================================

        $display("\n=== BITWISE LOGIC ===");

        check(ALU_AND, 64'hAA, 64'h55, 0,
              0, 0, 0, 0, 1);

        check(ALU_OR, 64'hAA, 64'h55, 0,
              64'hFF, 0, 0, 0, 1);

        check(ALU_XOR, 64'hAA, 64'h55, 0,
              64'hFF, 0, 0, 0, 1);

        check(
            ALU_NOT,
            0,
            0,
            0,
            64'hFFFFFFFFFFFFFFFF,
            0, 0, 0, 1
        );

        check(
            ALU_NAND,
            64'hFF,
            64'h0F,
            0,
            64'hFFFFFFFFFFFFFFF0,
            0, 0, 0, 1
        );

        check(
            ALU_NOR,
            64'hF0,
            64'h0F,
            0,
            64'hFFFFFFFFFFFFFF00,
            0, 0, 0, 1
        );

        check(
            ALU_XNOR,
            64'hAA,
            64'h55,
            0,
            64'hFFFFFFFFFFFFFF00,
            0, 0, 0, 1
        );

        check(ALU_PASS_A, 123, 456, 0,
              123, 0, 0, 0, 1);

        check(ALU_PASS_B, 123, 456, 0,
              456, 0, 0, 0, 1);

        // =====================================================
        // 07. SHIFTS AND ROTATIONS
        // =====================================================

        $display("\n=== SHIFTS AND ROTATIONS ===");

        check(ALU_SHL, 1, 4, 0,
              16, 0, 0, 0, 1);

        check(ALU_SHR, 128, 4, 0,
              8, 0, 0, 0, 1);

        check(
            ALU_SAR,
            64'h8000000000000000,
            1,
            0,
            64'hC000000000000000,
            0, 0, 0, 1
        );

        check(
            ALU_ROL,
            64'h8000000000000000,
            1,
            0,
            1,
            0, 0, 0, 1
        );

        check(
            ALU_ROR,
            1,
            1,
            0,
            64'h8000000000000000,
            0, 0, 0, 1
        );

        // Shift by WIDTH
        check(ALU_SHL, 1, 64, 0,
              0, 0, 0, 0, 1);

        check(ALU_SHR, 1, 64, 0,
              0, 0, 0, 0, 1);

        check(
            ALU_SAR,
            64'h8000000000000000,
            64,
            0,
            64'hFFFFFFFFFFFFFFFF,
            0, 0, 0, 1
        );

        // Rotate by WIDTH
        check(ALU_ROL, 1, 64, 0,
              1, 0, 0, 0, 1);

        check(ALU_ROR, 1, 64, 0,
              1, 0, 0, 0, 1);

        // Rotate by zero
        check(ALU_ROL, 123, 0, 0,
              123, 0, 0, 0, 1);

        check(ALU_ROR, 123, 0, 0,
              123, 0, 0, 0, 1);

        // Rotate by WIDTH + 1
        check(ALU_ROL, 1, 65, 0,
              2, 0, 0, 0, 1);

        check(
            ALU_ROR,
            1,
            65,
            0,
            64'h8000000000000000,
            0, 0, 0, 1
        );

        // =====================================================
        // 08. COMPARISONS
        // =====================================================

        $display("\n=== COMPARISONS ===");

        // Equal
        check(ALU_EQ, 5, 5, 0,
              1, 0, 0, 0, 1);

        check(ALU_EQ, 5, 6, 0,
              0, 0, 0, 0, 1);

        // Not equal
        check(ALU_NE, 5, 6, 0,
              1, 0, 0, 0, 1);

        check(ALU_NE, 5, 5, 0,
              0, 0, 0, 0, 1);

        // Unsigned LT
        check(ALU_LTU, 5, 6, 0,
              1, 0, 0, 0, 1);

        check(ALU_LTU, 6, 5, 0,
              0, 0, 0, 0, 1);

        // Unsigned LE
        check(ALU_LEU, 5, 5, 0,
              1, 0, 0, 0, 1);

        check(ALU_LEU, 6, 5, 0,
              0, 0, 0, 0, 1);

        // Unsigned GT
        check(ALU_GTU, 6, 5, 0,
              1, 0, 0, 0, 1);

        check(ALU_GTU, 5, 6, 0,
              0, 0, 0, 0, 1);

        // Unsigned GE
        check(ALU_GEU, 5, 5, 0,
              1, 0, 0, 0, 1);

        check(ALU_GEU, 5, 6, 0,
              0, 0, 0, 0, 1);

        // Signed LT
        check(ALU_LTS, -64'sd1, 1, 0,
              1, 0, 0, 0, 1);

        check(ALU_LTS, 1, -64'sd1, 0,
              0, 0, 0, 0, 1);

        // Signed LE
        check(ALU_LES, -64'sd1, 1, 0,
              1, 0, 0, 0, 1);

        check(ALU_LES, 1, -64'sd1, 0,
              0, 0, 0, 0, 1);

        check(ALU_LES, 5, 5, 0,
              1, 0, 0, 0, 1);

        // Signed GT
        check(ALU_GTS, 1, -64'sd1, 0,
              1, 0, 0, 0, 1);

        check(ALU_GTS, -64'sd1, 1, 0,
              0, 0, 0, 0, 1);

        // Signed GE
        check(ALU_GES, 1, -64'sd1, 0,
              1, 0, 0, 0, 1);

        check(ALU_GES, -64'sd1, 1, 0,
              0, 0, 0, 0, 1);

        check(ALU_GES, 5, 5, 0,
              1, 0, 0, 0, 1);

        // Signed vs unsigned
        check(
            ALU_LTU,
            64'hFFFFFFFFFFFFFFFF,
            1,
            0,
            0,
            0, 0, 0, 1
        );

        check(
            ALU_LTS,
            64'hFFFFFFFFFFFFFFFF,
            1,
            0,
            1,
            0, 0, 0, 1
        );

        // =====================================================
        // 09. RESERVED OPCODES
        // =====================================================

        $display("\n=== RESERVED OPCODES ===");

        // 40 operations occupy 0x00 through 0x27.
        // All remaining encodings must be invalid.

        for (integer i = 6'h28; i <= 6'h3F; i = i + 1) begin

            check(
                i[5:0],
                10,
                5,
                0,
                0,
                0, 0, 0, 0
            );

        end

        // =====================================================
        // 10. STATUS REGISTER
        // =====================================================

        $display("\n=== STATUS REGISTER ===");

        // Store Z=1
        @(negedge clk);

        op = ALU_ADD;
        A = 0;
        B = 0;
        carry_in = 0;

        write_enable = 1;

        #1;

        @(posedge clk);
        #1;

        check_status(5'b10000);

        // Disable writes; previous flags must remain.
        @(negedge clk);

        write_enable = 0;

        A = 5;
        B = 6;

        @(posedge clk);
        #1;

        check_status(5'b10000);

        // Enable writes again.
        @(negedge clk);

        write_enable = 1;

        @(posedge clk);
        #1;

        check_status(5'b00000);

        // Store carry flag.
        @(negedge clk);

        op = ALU_ADD;

        A = 64'hFFFFFFFFFFFFFFFF;
        B = 1;

        @(posedge clk);
        #1;

        // Z=1, C=1
        check_status(5'b10100);

        // Store negative and overflow flags.
        @(negedge clk);

        A = 64'h7FFFFFFFFFFFFFFF;
        B = 1;

        @(posedge clk);
        #1;

        // N=1, V=1
        check_status(5'b01010);

        // Store division-by-zero flag.
        @(negedge clk);

        op = ALU_DIVU;
        A = 100;
        B = 0;

        @(posedge clk);
        #1;

        // Z=1, DZ=1
        check_status(5'b10001);

        // Asynchronous reset.
        @(negedge clk);

        write_enable = 0;
        rst = 1;

        #1;

        check_status(5'b00000);

        rst = 0;

        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("================================");
        $display("       ALU TEST SUMMARY");
        $display("================================");
        $display("Total tests : %0d", tests);
        $display("Passed      : %0d", tests - errors);
        $display("Failed      : %0d", errors);
        $display("================================");

        if (errors != 0)
            $fatal(1, "ALU TEST FAILED");

        $display("ALL TESTS PASSED");

        $finish;

    end

endmodule
