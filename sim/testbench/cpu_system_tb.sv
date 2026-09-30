`timescale 1ns/1ps

// ============================================================
// LACOODA Stage 6 full-system regression
//
// Program under test:
//   0x00  MOVI R1, 5
//   0x08  MOVI R2, 5
//   0x10  BEQ  R1, R2, 0x20
//   0x18  MOVI R3, 111      <-- must be skipped
//   0x20  MOVI R3, 222      <-- branch target
//
// Expected PC sequence while running:
//   0 -> 8 -> 16 -> 32
//
// This proves Stage 6 changes actual instruction flow rather than
// merely calculating a comparison result.
// ============================================================

module cpu_system_tb;
    import cpu_pkg::*;
    import alu_pkg::*;

    logic clk = 0;
    logic rst = 1;
    logic run = 0;

    data_t pc;
    instruction_t instruction;

    logic execution_valid;
    logic illegal_instruction;
    data_t result;

    always #5 clk = ~clk;

    cpu_system dut (
        .clk(clk),
        .rst(rst),
        .run(run),
        .pc(pc),
        .instruction(instruction),
        .execution_valid(execution_valid),
        .illegal_instruction(illegal_instruction),
        .result(result)
    );

    task automatic check_instruction(
        input data_t expected_pc,
        input instruction_t expected_instruction,
        input data_t expected_result
    );
        begin
            #1;

            assert (pc === expected_pc)
                else $fatal(1, "Wrong PC: expected=%0d actual=%0d",
                            expected_pc, pc);

            assert (instruction === expected_instruction)
                else $fatal(1, "Wrong instruction at PC=%0d: expected=%016h actual=%016h",
                            pc, expected_instruction, instruction);

            assert (execution_valid === 1'b1)
                else $fatal(1, "Execution invalid at PC=%0d", pc);

            assert (illegal_instruction === 1'b0)
                else $fatal(1, "Illegal instruction at PC=%0d", pc);

            assert (result === expected_result)
                else $fatal(1, "PC=%0d: expected result %0d, got %0d",
                            pc, expected_result, result);

            $display("PC=%0d INSTRUCTION=%016h RESULT=%0d",
                     pc, instruction, result);
        end
    endtask

    initial begin
        $dumpfile("cpu_system.vcd");
        $dumpvars(0, cpu_system_tb);

        // The checked-in image encodes the default layout. Re-encode the same
        // five instructions only when architectural dimensions change.
        if (INSTRUCTION_WIDTH != 64 || REG_COUNT != 64 ||
            IMMEDIATE_WIDTH != 32 || OPCODE_WIDTH != 6) begin
            #1; // Let the ROM's time-zero initialization finish first.
            dut.u_fetch.u_imem.memory[0] = encode_instruction(
                ALU_PASS_B, reg_addr_t'(1), ZERO_REG, ZERO_REG, 1'b1, 1'b0, imm_t'(5));
            dut.u_fetch.u_imem.memory[1] = encode_instruction(
                ALU_PASS_B, reg_addr_t'(2), ZERO_REG, ZERO_REG, 1'b1, 1'b0, imm_t'(5));
            dut.u_fetch.u_imem.memory[2] = encode_branch(
                CTRL_BEQ, reg_addr_t'(1), reg_addr_t'(2), imm_t'(4 * INSTRUCTION_BYTES));
            dut.u_fetch.u_imem.memory[3] = encode_instruction(
                ALU_PASS_B, reg_addr_t'(3), ZERO_REG, ZERO_REG, 1'b1, 1'b0, imm_t'(111));
            dut.u_fetch.u_imem.memory[4] = encode_instruction(
                ALU_PASS_B, reg_addr_t'(3), ZERO_REG, ZERO_REG, 1'b1, 1'b0, imm_t'(222));
        end

        // Hold reset through a rising edge and verify the Stage-5 PC
        // reset behavior remains intact.
        @(posedge clk);
        #1;
        assert (pc === '0)
            else $fatal(1, "Reset failed");

        // Start sequential execution.
        @(negedge clk);
        rst = 0;
        run = 1;

        // --------------------------------------------------------
        // 0x00: MOVI R1, #5
        // --------------------------------------------------------
        check_instruction(
            data_t'(0),
            encode_instruction(ALU_PASS_B, reg_addr_t'(1), ZERO_REG, ZERO_REG,
                               1'b1, 1'b0, imm_t'(5)),
            data_t'(5)
        );

        @(posedge clk); // Commit R1=5 and advance PC to 0x08.
        @(negedge clk);

        // --------------------------------------------------------
        // 0x08: MOVI R2, #5
        // --------------------------------------------------------
        check_instruction(
            data_t'(INSTRUCTION_BYTES),
            encode_instruction(ALU_PASS_B, reg_addr_t'(2), ZERO_REG, ZERO_REG,
                               1'b1, 1'b0, imm_t'(5)),
            data_t'(5)
        );

        @(posedge clk); // Commit R2=5 and advance PC to 0x10.
        @(negedge clk);

        // --------------------------------------------------------
        // 0x10: BEQ R1,R2,0x20
        // --------------------------------------------------------
        // The datapath's ALU result is not architecturally meaningful
        // for a branch, so this test checks instruction/control flow
        // directly instead of using check_instruction's result check.
        #1;
        assert (pc === data_t'(2 * INSTRUCTION_BYTES))
            else $fatal(1, "BEQ PC wrong: %0d", pc);

        assert (instruction === encode_branch(
                    CTRL_BEQ,
                    reg_addr_t'(1),
                    reg_addr_t'(2),
                    imm_t'(4 * INSTRUCTION_BYTES)))
            else $fatal(1, "Wrong BEQ encoding at PC=%0d", pc);

        assert (execution_valid === 1'b1)
            else $fatal(1, "BEQ did not execute");

        assert (illegal_instruction === 1'b0)
            else $fatal(1, "BEQ decoded as illegal");

        $display("PC=%0d BEQ R1,R2 -> target=%0d TAKEN",
                 pc, 4 * INSTRUCTION_BYTES);

        // At this rising edge the branch redirect is committed by the PC.
        @(posedge clk);
        @(negedge clk);

        // --------------------------------------------------------
        // MUST be 0x20, not 0x18. MOVI R3,111 was skipped.
        // --------------------------------------------------------
        check_instruction(
            data_t'(4 * INSTRUCTION_BYTES),
            encode_instruction(ALU_PASS_B, reg_addr_t'(3), ZERO_REG, ZERO_REG,
                               1'b1, 1'b0, imm_t'(222)),
            sign_extend_imm32(imm_t'(222))
        );

        @(posedge clk); // Commit R3=222.

        // Stop before fetching unused memory.
        @(negedge clk);
        run = 0;

        // Hierarchical observation is used only in the testbench to prove
        // the skipped MOVI never wrote R3=111. The architectural result is
        // R3=222 after the target instruction commits.
        #1;
        assert (dut.u_core.u_datapath.u_register_file.registers[3] === sign_extend_imm32(imm_t'(222)))
            else $fatal(1, "R3 expected %0d, got %0d", sign_extend_imm32(imm_t'(222)),
                        dut.u_core.u_datapath.u_register_file.registers[3]);

        $display("PASS: branch skipped PC=%0d and R3=%0d",
                 3 * INSTRUCTION_BYTES, sign_extend_imm32(imm_t'(222)));
        $display("PASS: cpu_system_tb");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "TIMEOUT");
    end

endmodule
