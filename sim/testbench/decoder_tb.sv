`timescale 1ns/1ps

// LACOODA Stage 4 decoder regression. Compatible with Icarus Verilog:
// no integer-to-enum casts, no hardcoded instruction bit positions.
module decoder_tb;
    import cpu_pkg::*;
    import alu_pkg::*;

    instruction_t instruction;
    reg_addr_t rs1, rs2, rd;
    opcode_t alu_op;
    cpu_pkg::data_t immediate;
    logic use_immediate, register_write_enable, flags_write_enable;
    logic branch_enable;
    branch_condition_t branch_condition;
    data_t branch_target;
    logic instruction_valid, illegal_instruction;
    integer tests = 0, errors = 0;
    integer op_index, bit_index;
    instruction_fields_t fields;

    decoder dut (
        .instruction(instruction), .rs1(rs1), .rs2(rs2), .rd(rd),
        .alu_op(alu_op), .immediate(immediate), .use_immediate(use_immediate),
        .register_write_enable(register_write_enable),
        .flags_write_enable(flags_write_enable),
        .branch_enable(branch_enable),
        .branch_condition(branch_condition),
        .branch_target(branch_target),
        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction)
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

    // Every call samples after combinational logic has settled.
    task automatic expect_valid(input string description,
                                input integer expected_opcode,
                                input reg_addr_t expected_rd,
                                input reg_addr_t expected_rs1,
                                input reg_addr_t expected_rs2,
                                input logic expected_i,
                                input logic expected_s,
                                input imm_t expected_imm);
        begin
            #1;
            check(instruction_valid === 1'b1 && illegal_instruction === 1'b0,
                  {description, " legal"});
            check(register_write_enable === 1'b1 &&
                  flags_write_enable === expected_s && branch_enable === 1'b0,
                  {description, " write controls"});
            check(rd === expected_rd && rs1 === expected_rs1 && rs2 === expected_rs2,
                  {description, " register addresses"});
            check(alu_op === expected_opcode[OPCODE_WIDTH-1:0],
                  {description, " opcode"});
            check(use_immediate === expected_i &&
                  immediate === sign_extend_imm32(expected_imm),
                  {description, " operand mode and sign extension"});
        end
    endtask

    task automatic expect_invalid(input string description);
        begin
            #1;
            check(instruction_valid === 1'b0 && illegal_instruction === 1'b1,
                  {description, " illegal"});
            check(register_write_enable === 1'b0 && flags_write_enable === 1'b0 &&
                  branch_enable === 1'b0,
                  {description, " no writes"});
            check(rd === ZERO_REG && rs1 === ZERO_REG && rs2 === ZERO_REG,
                  {description, " register outputs cleared"});
            check(alu_op === ALU_ADD && immediate === '0 &&
                  use_immediate === 1'b0,
                  {description, " other controls cleared"});
        end
    endtask

    // Create arbitrary raw opcode values without illegal enum casts.
    // The package's packed layout is the source of truth.
    task automatic set_raw(input integer op,
                           input reg_addr_t dest, src1, src2,
                           input logic i, s, input imm_t imm);
        begin
            fields = '0;
            fields.rd = dest;
            fields.rs1 = src1;
            fields.rs2 = src2;
            fields.immediate_mode = i;
            fields.update_status = s;
            fields.imm32 = imm;
            instruction = fields;
            instruction[OPCODE_LSB +: OPCODE_WIDTH] = op[OPCODE_WIDTH-1:0];
        end
    endtask

    initial begin
        $dumpfile("decoder_tb.vcd");
        $dumpvars(0, decoder_tb);
        instruction = '0;

        $display("=== PACKAGE / ENCODER ===");
        check($bits(instruction_t) == INSTRUCTION_WIDTH &&
              $bits(instruction_fields_t) == INSTRUCTION_WIDTH,
              "instruction widths match");
        check($bits(reg_addr_t) == REG_ADDR_WIDTH &&
              $bits(imm_t) == IMMEDIATE_WIDTH,
              "operand widths match");
        check(RESERVED_WIDTH > 0 && OPCODE_LSB == RD_MSB + 1,
              "derived instruction layout");
        instruction = encode_instruction(ALU_ADD, reg_addr_t'(63),
                      reg_addr_t'(1), reg_addr_t'(2), 1'b1, 1'b1, imm_t'(123));
        fields = instruction;
        check(fields.reserved === '0 && fields.opcode === ALU_ADD &&
              fields.rd === reg_addr_t'(63) && fields.rs1 === reg_addr_t'(1) &&
              fields.rs2 === reg_addr_t'(2) && fields.immediate_mode &&
              fields.update_status && fields.imm32 === imm_t'(123),
              "encoder packed field mapping");
        // The previous encoder example is intentionally invalid: I=1 and RS2!=0.
        expect_invalid("encoder preserves raw invalid combination");

        $display("=== ALL 40 OPCODES, REGISTER FORMAT ===");
        for (op_index = 0; op_index <= int'(ALU_GES); op_index = op_index + 1) begin
            if (op_index == int'(ALU_PASS_B)) begin
                set_raw(op_index, reg_addr_t'(10), ZERO_REG, ZERO_REG,
                        1'b1, 1'b0, imm_t'(42));
                expect_valid($sformatf("MOVI %0d", op_index), op_index,
                             reg_addr_t'(10), ZERO_REG, ZERO_REG, 1'b1, 1'b0, imm_t'(42));
            end else if (op_index == int'(ALU_PASS_A)) begin
                set_raw(op_index, reg_addr_t'(10), reg_addr_t'(11), ZERO_REG,
                        1'b0, 1'b0, '0);
                expect_valid($sformatf("MOV %0d", op_index), op_index,
                             reg_addr_t'(10), reg_addr_t'(11), ZERO_REG, 1'b0, 1'b0, '0);
            end else if (op_index == int'(ALU_NEG) ||
                         op_index == int'(ALU_ABS) ||
                         op_index == int'(ALU_NOT)) begin
                set_raw(op_index, reg_addr_t'(10), reg_addr_t'(11), ZERO_REG,
                        1'b0, 1'b1, '0);
                expect_valid($sformatf("unary %0d", op_index), op_index,
                             reg_addr_t'(10), reg_addr_t'(11), ZERO_REG, 1'b0, 1'b1, '0);
            end else begin
                set_raw(op_index, reg_addr_t'(10), reg_addr_t'(11), reg_addr_t'(12),
                        1'b0, 1'b1, '0);
                expect_valid($sformatf("binary %0d", op_index), op_index,
                             reg_addr_t'(10), reg_addr_t'(11), reg_addr_t'(12), 1'b0, 1'b1, '0);
            end
        end

        $display("=== ALL BINARY IMMEDIATE FORMATS ===");
        for (op_index = 0; op_index <= int'(ALU_GES); op_index = op_index + 1) begin
            if (op_index != int'(ALU_NEG) && op_index != int'(ALU_ABS) &&
                op_index != int'(ALU_NOT) && op_index != int'(ALU_PASS_A) &&
                op_index != int'(ALU_PASS_B)) begin
                set_raw(op_index, reg_addr_t'(13), reg_addr_t'(14), ZERO_REG,
                        1'b1, 1'b0, imm_t'(-1));
                expect_valid($sformatf("immediate %0d", op_index), op_index,
                             reg_addr_t'(13), reg_addr_t'(14), ZERO_REG,
                             1'b1, 1'b0, imm_t'(-1));
            end
        end

        $display("=== REGISTER AND IMMEDIATE BOUNDARIES ===");
        set_raw(int'(ALU_ADD), reg_addr_t'(REG_COUNT-1), ZERO_REG,
                reg_addr_t'(REG_COUNT-1), 1'b0, 1'b1, '0);
        expect_valid("R0/Rlast", int'(ALU_ADD), reg_addr_t'(REG_COUNT-1),
                     ZERO_REG, reg_addr_t'(REG_COUNT-1), 1'b0, 1'b1, '0);
        set_raw(int'(ALU_PASS_B), ZERO_REG, ZERO_REG, ZERO_REG,
                1'b1, 1'b0, imm_t'(1));
        expect_valid("R0 destination is legal", int'(ALU_PASS_B),
                     ZERO_REG, ZERO_REG, ZERO_REG, 1'b1, 1'b0, imm_t'(1));
        set_raw(int'(ALU_ADD), reg_addr_t'(1), reg_addr_t'(2), ZERO_REG,
                1'b1, 1'b1, imm_t'(32'h80000000));
        expect_valid("minimum signed immediate", int'(ALU_ADD),
                     reg_addr_t'(1), reg_addr_t'(2), ZERO_REG,
                     1'b1, 1'b1, imm_t'(32'h80000000));
        set_raw(int'(ALU_ADD), reg_addr_t'(1), reg_addr_t'(2), ZERO_REG,
                1'b1, 1'b0, imm_t'(32'h7fffffff));
        expect_valid("maximum signed immediate", int'(ALU_ADD),
                     reg_addr_t'(1), reg_addr_t'(2), ZERO_REG,
                     1'b1, 1'b0, imm_t'(32'h7fffffff));

        $display("=== STAGE 6 CONTROL FLOW ===");
        instruction = encode_jump(imm_t'(32));
        #1;
        check(instruction_valid && !illegal_instruction && branch_enable,
              "JMP legal");
        check(branch_condition == BR_ALWAYS && branch_target == data_t'(32),
              "JMP controls");
        check(!register_write_enable && !flags_write_enable,
              "JMP does not write register/status");

        instruction = encode_branch(CTRL_BEQ, reg_addr_t'(1), reg_addr_t'(2), imm_t'(64));
        #1;
        check(instruction_valid && !illegal_instruction && branch_enable,
              "BEQ legal");
        check(rs1 == reg_addr_t'(1) && rs2 == reg_addr_t'(2) && rd == ZERO_REG,
              "BEQ source registers");
        check(branch_condition == BR_EQ && branch_target == data_t'(64),
              "BEQ controls");

        // A branch may not claim an RD, immediate mode, or status update.
        set_raw(int'(CTRL_BEQ), reg_addr_t'(3), reg_addr_t'(1), reg_addr_t'(2),
                1'b0, 1'b0, imm_t'(64));
        expect_invalid("BEQ nonzero RD");
        set_raw(int'(CTRL_BEQ), ZERO_REG, reg_addr_t'(1), reg_addr_t'(2),
                1'b1, 1'b0, imm_t'(64));
        expect_invalid("BEQ I=1");
        set_raw(int'(CTRL_BEQ), ZERO_REG, reg_addr_t'(1), reg_addr_t'(2),
                1'b0, 1'b1, imm_t'(64));
        expect_invalid("BEQ S=1");
        set_raw(int'(CTRL_JMP), ZERO_REG, reg_addr_t'(1), ZERO_REG,
                1'b0, 1'b0, imm_t'(64));
        expect_invalid("JMP nonzero RS1");

        $display("=== RESERVED BITS / UNDEFINED OPCODES ===");
        for (bit_index = 0; bit_index < RESERVED_WIDTH; bit_index = bit_index + 1) begin
            set_raw(int'(ALU_ADD), reg_addr_t'(1), reg_addr_t'(2),
                    reg_addr_t'(3), 1'b0, 1'b1, '0);
            fields = instruction;
            fields.reserved = RESERVED_WIDTH'(1) << bit_index;
            instruction = fields;
            expect_invalid($sformatf("reserved bit %0d", bit_index));
        end
        for (op_index = int'(CTRL_BGEU)+1;
             op_index < (1 << OPCODE_WIDTH); op_index = op_index + 1) begin
            set_raw(op_index, ZERO_REG, ZERO_REG, ZERO_REG, 1'b0, 1'b0, '0);
            expect_invalid($sformatf("undefined opcode %0d", op_index));
        end

        $display("=== INVALID OPERAND FORMATS ===");
        set_raw(int'(ALU_ADD), reg_addr_t'(1), reg_addr_t'(2),
                reg_addr_t'(3), 1'b0, 1'b1, imm_t'(1));
        expect_invalid("register mode nonzero immediate");
        set_raw(int'(ALU_ADD), reg_addr_t'(1), reg_addr_t'(2),
                reg_addr_t'(3), 1'b1, 1'b1, imm_t'(1));
        expect_invalid("immediate mode nonzero RS2");
        for (op_index = int'(ALU_NEG); op_index <= int'(ALU_NOT);
             op_index = op_index + 1) begin
            if (op_index == int'(ALU_NEG) || op_index == int'(ALU_ABS) ||
                op_index == int'(ALU_NOT)) begin
                set_raw(op_index, reg_addr_t'(1), reg_addr_t'(2),
                        reg_addr_t'(3), 1'b0, 1'b1, '0);
                expect_invalid($sformatf("unary %0d nonzero RS2", op_index));
                set_raw(op_index, reg_addr_t'(1), reg_addr_t'(2),
                        ZERO_REG, 1'b1, 1'b1, '0);
                expect_invalid($sformatf("unary %0d immediate mode", op_index));
                set_raw(op_index, reg_addr_t'(1), reg_addr_t'(2),
                        ZERO_REG, 1'b0, 1'b1, imm_t'(1));
                expect_invalid($sformatf("unary %0d nonzero IMM32", op_index));
            end
        end
        set_raw(int'(ALU_PASS_A), reg_addr_t'(1), reg_addr_t'(2),
                ZERO_REG, 1'b0, 1'b1, '0);
        expect_invalid("MOV S=1");
        set_raw(int'(ALU_PASS_A), reg_addr_t'(1), reg_addr_t'(2),
                reg_addr_t'(3), 1'b0, 1'b0, '0);
        expect_invalid("MOV nonzero RS2");
        set_raw(int'(ALU_PASS_A), reg_addr_t'(1), reg_addr_t'(2),
                ZERO_REG, 1'b1, 1'b0, '0);
        expect_invalid("MOV I=1");
        set_raw(int'(ALU_PASS_A), reg_addr_t'(1), reg_addr_t'(2),
                ZERO_REG, 1'b0, 1'b0, imm_t'(1));
        expect_invalid("MOV nonzero IMM32");
        set_raw(int'(ALU_PASS_B), reg_addr_t'(1), ZERO_REG,
                ZERO_REG, 1'b1, 1'b1, imm_t'(42));
        expect_invalid("MOVI S=1");
        set_raw(int'(ALU_PASS_B), reg_addr_t'(1), reg_addr_t'(2),
                ZERO_REG, 1'b1, 1'b0, imm_t'(42));
        expect_invalid("MOVI nonzero RS1");
        set_raw(int'(ALU_PASS_B), reg_addr_t'(1), ZERO_REG,
                reg_addr_t'(3), 1'b1, 1'b0, imm_t'(42));
        expect_invalid("MOVI nonzero RS2");
        set_raw(int'(ALU_PASS_B), reg_addr_t'(1), ZERO_REG,
                ZERO_REG, 1'b0, 1'b0, '0);
        expect_invalid("MOVI I=0");

        $display("=== RECOVERY AFTER INVALID ===");
        set_raw(int'(ALU_ADD), reg_addr_t'(4), reg_addr_t'(5),
                reg_addr_t'(6), 1'b0, 1'b1, '0);
        expect_valid("valid after invalid", int'(ALU_ADD),
                     reg_addr_t'(4), reg_addr_t'(5), reg_addr_t'(6),
                     1'b0, 1'b1, '0);

        $display("========================================");
        $display("LACOODA STAGE 6 DECODER TEST SUMMARY");
        $display("Total tests : %0d", tests);
        $display("Passed      : %0d", tests-errors);
        $display("Failed      : %0d", errors);
        $display("========================================");
        if (errors != 0) $fatal(1, "DECODER TEST FAILED");
        $display("ALL DECODER TESTS PASSED");
        $finish;
    end
endmodule