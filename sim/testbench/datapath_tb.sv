
`timescale 1ns/1ps

module datapath_tb;

    import alu_pkg::*;
    import cpu_pkg::*;

    logic clk = 0;
    always #5 clk = ~clk;

    logic rst;

    reg_addr_t rs1;
    reg_addr_t rs2;
    reg_addr_t rd;

    logic [OPCODE_WIDTH-1:0] alu_op;
    logic carry_in;

    data_t immediate;
    logic use_immediate;

    logic register_write_enable;
    logic flags_write_enable;

    // Stage 7 LOAD writeback controls/data.
    data_t memory_read_data;
    logic writeback_from_memory;

    data_t operand_a;
    data_t operand_b;
    data_t store_data;
    data_t result;

    logic valid;

    alu_pkg::flags_t alu_flags;
    alu_pkg::flags_t status_flags;

    integer tests = 0;
    integer errors = 0;

    // =========================================================
    // DATAPATH INSTANCE
    // =========================================================

    datapath dut (
        .clk(clk),
        .rst(rst),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .alu_op(alu_op),
        .carry_in(carry_in),

        .immediate(immediate),
        .use_immediate(use_immediate),

        .register_write_enable(register_write_enable),
        .flags_write_enable(flags_write_enable),

        .memory_read_data(memory_read_data),
        .writeback_from_memory(writeback_from_memory),

        .operand_a(operand_a),
        .operand_b(operand_b),
        .store_data(store_data),
        .result(result),
        .valid(valid),

        .alu_flags(alu_flags),
        .status_flags(status_flags)
    );

    // =========================================================
    // EXECUTE ONE OPERATION
    // =========================================================

    task automatic execute(
        input logic [OPCODE_WIDTH-1:0] operation,
        input reg_addr_t src_a,
        input reg_addr_t src_b,
        input reg_addr_t dest,

        input logic imm_enable,
        input data_t imm,

        input logic reg_write,
        input logic flag_write,
        input logic cin
    );

        begin

            @(negedge clk);

            alu_op = operation;

            rs1 = src_a;
            rs2 = src_b;
            rd  = dest;

            use_immediate = imm_enable;
            immediate = imm;

            register_write_enable = reg_write;
            flags_write_enable = flag_write;

            carry_in = cin;

            // Normal execute() calls exercise ALU writeback.
            memory_read_data = '0;
            writeback_from_memory = 1'b0;

            #1;

            @(posedge clk);
            #1;

        end

    endtask

    // =========================================================
    // CHECK REGISTER VALUE
    // =========================================================

    task automatic expect_reg(
        input reg_addr_t addr,
        input data_t expected
    );

        begin

            @(negedge clk);

            register_write_enable = 0;
            flags_write_enable = 0;

            rs1 = addr;

            #1;

            tests = tests + 1;

            if (operand_a !== expected) begin

                errors = errors + 1;

                $display(
                    "[FAIL] R%0d got=%h expected=%h",
                    addr,
                    operand_a,
                    expected
                );

            end else begin

                $display(
                    "[PASS] R%0d = %h",
                    addr,
                    operand_a
                );

            end

        end

    endtask

    // =========================================================
    // CHECK STATUS FLAGS
    // =========================================================

    task automatic expect_flags(
        input logic [4:0] expected
    );

        begin

            #1;

            tests = tests + 1;

            if (status_flags !== expected) begin

                errors = errors + 1;

                $display(
                    "[FAIL] FLAGS got=%b expected=%b",
                    status_flags,
                    expected
                );

            end else begin

                $display(
                    "[PASS] FLAGS = %b",
                    status_flags
                );

            end

        end

    endtask

    // =========================================================
    // MAIN TEST
    // =========================================================

    initial begin

        $dumpfile("datapath.vcd");
        $dumpvars(0, datapath_tb);

        rst = 1;

        rs1 = 0;
        rs2 = 0;
        rd  = 0;

        alu_op = ALU_ADD;
        carry_in = 0;

        immediate = 0;
        use_immediate = 0;

        register_write_enable = 0;
        flags_write_enable = 0;

        memory_read_data = '0;
        writeback_from_memory = 0;

        #2;

        rst = 0;

        // =====================================================
        // MOVI R1, #10
        // =====================================================

        execute(
            ALU_PASS_B,
            0, 0, 1,
            1, 10,
            1, 0, 0
        );

        expect_reg(1, 10);

        // =====================================================
        // MOVI R2, #20
        // =====================================================

        execute(
            ALU_PASS_B,
            0, 0, 2,
            1, 20,
            1, 0, 0
        );

        expect_reg(2, 20);

        // =====================================================
        // ADD R3, R1, R2
        // =====================================================

        execute(
            ALU_ADD,
            1, 2, 3,
            0, 0,
            1, 1, 0
        );

        expect_reg(3, 30);
        expect_flags(5'b00000);

        // =====================================================
        // MOV R4, R3
        // =====================================================

        execute(
            ALU_PASS_A,
            3, 0, 4,
            0, 0,
            1, 0, 0
        );

        expect_reg(4, 30);

        // =====================================================
        // SUB R5, R1, R1
        // =====================================================

        execute(
            ALU_SUB,
            1, 1, 5,
            0, 0,
            1, 1, 0
        );

        expect_reg(5, 0);

        // Z=1, C=1
        expect_flags(5'b10100);

        // =====================================================
        // MOVI R6, #100
        // Flags must remain unchanged.
        // =====================================================

        execute(
            ALU_PASS_B,
            0, 0, 6,
            1, 100,
            1, 0, 0
        );

        expect_reg(6, 100);
        expect_flags(5'b10100);

        // =====================================================
        // ADDI R7, R6, #23
        // =====================================================

        execute(
            ALU_ADD,
            6, 0, 7,
            1, 23,
            1, 1, 0
        );

        expect_reg(7, 123);

        // =====================================================
        // Test the highest architectural register
        // =====================================================

        execute(
            ALU_PASS_A,
            7, 0, reg_addr_t'(REG_COUNT - 1),
            0, 0,
            1, 0, 0
        );

        expect_reg(reg_addr_t'(REG_COUNT - 1), 123);

        // =====================================================
        // R0 must remain zero.
        // =====================================================

        execute(
            ALU_PASS_B,
            0, 0, 0,
            1, 999,
            1, 0, 0
        );

        expect_reg(0, 0);

        // =====================================================
        // Comparison: R8 = (R1 == R1)
        // =====================================================

        execute(
            ALU_EQ,
            1, 1, 8,
            0, 0,
            1, 1, 0
        );

        expect_reg(8, 1);

        // =====================================================
        // Disabled register write
        // =====================================================

        execute(
            ALU_PASS_B,
            0, 0, 8,
            1, 999,
            0, 0, 0
        );

        expect_reg(8, 1);

        // =====================================================
        // Invalid opcode must not modify registers or flags.
        // =====================================================

        execute(
            6'h3F,
            0, 0, 8,
            1, 999,
            1, 1, 0
        );

        expect_reg(8, 1);
        expect_flags(5'b00000);

        // =====================================================
        // Division by zero
        // =====================================================

        execute(
            ALU_DIVU,
            6, 0, 9,
            0, 0,
            1, 1, 0
        );

        expect_reg(9, 0);

        // Z=1, DZ=1
        expect_flags(5'b10001);

        // =====================================================
        // STAGE 7: STORE DATA PATH
        //
        // R6=100 is the base and R1=10 is the value to store.
        // The ALU must calculate 100+8=108 while store_data must
        // still expose the raw R1 value instead of the immediate.
        // =====================================================

        execute(
            ALU_ADD,
            6, 1, 0,
            1, 8,
            0, 0, 0
        );

        tests = tests + 1;
        if (result !== data_t'(108) || store_data !== data_t'(10)) begin
            errors = errors + 1;
            $display(
                "[FAIL] STORE path address=%h data=%h expected_address=%h expected_data=%h",
                result, store_data, data_t'(108), data_t'(10)
            );
        end else begin
            $display("[PASS] STORE path address=%h data=%h", result, store_data);
        end

        // =====================================================
        // STAGE 7: LOAD WRITEBACK PATH
        //
        // The ALU still calculates the effective address 108, but
        // the register-file writeback value must come from memory.
        // =====================================================

        @(negedge clk);
        alu_op = ALU_ADD;
        rs1 = reg_addr_t'(6);
        rs2 = ZERO_REG;
        rd  = reg_addr_t'(10);
        use_immediate = 1'b1;
        immediate = data_t'(8);
        register_write_enable = 1'b1;
        flags_write_enable = 1'b0;
        carry_in = 1'b0;
        memory_read_data = data_t'(16'hBEEF);
        writeback_from_memory = 1'b1;

        #1;
        tests = tests + 1;
        if (result !== data_t'(108)) begin
            errors = errors + 1;
            $display("[FAIL] LOAD effective address got=%h expected=%h",
                     result, data_t'(108));
        end else begin
            $display("[PASS] LOAD effective address = %h", result);
        end

        @(posedge clk);
        #1;
        writeback_from_memory = 1'b0;
        register_write_enable = 1'b0;
        memory_read_data = '0;

        expect_reg(reg_addr_t'(10), data_t'(16'hBEEF));

        // =====================================================
        // RESET
        // =====================================================

        @(negedge clk);

        register_write_enable = 0;
        flags_write_enable = 0;

        rst = 1;

        #1;

        expect_flags(5'b00000);

        rst = 0;

        expect_reg(reg_addr_t'(REG_COUNT - 1), 0);
        expect_reg(7, 0);

        // =====================================================
        // SUMMARY
        // =====================================================

        $display("");
        $display("================================");
        $display("       DATAPATH TEST SUMMARY");
        $display("================================");

        $display("Total tests : %0d", tests);
        $display("Passed      : %0d", tests - errors);
        $display("Failed      : %0d", errors);

        $display("================================");

        if (errors != 0)
            $fatal(1, "DATAPATH TEST FAILED");

        $display("ALL DATAPATH TESTS PASSED");

        $finish;

    end

endmodule
