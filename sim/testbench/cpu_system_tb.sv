`timescale 1ns/1ps

// ============================================================
// LACOODA CPU-bus full-system regression
//
// Program under test (default 64-bit configuration):
//   0x00  MOVI  R1, 100
//   0x08  MOVI  R2, 64
//   0x10  STORE R1, [R2 + 8]   -> memory byte address 72
//   0x18  LOAD  R3, [R2 + 8]   -> R3 = 100
//   0x20  BEQ   R1, R3, 0x30
//   0x28  MOVI  R4, 111         -> must be skipped
//   0x30  MOVI  R4, 222         -> branch target
//
// This preserves the Stage-7 end-to-end proof through the wrapped CPU
// and the new valid/ready data-bus boundary.
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
                else $fatal(1, "Wrong instruction at PC=%0d: expected=%h actual=%h",
                            pc, expected_instruction, instruction);

            assert (execution_valid === 1'b1)
                else $fatal(1, "Execution invalid at PC=%0d", pc);

            assert (illegal_instruction === 1'b0)
                else $fatal(1, "Illegal instruction at PC=%0d", pc);

            assert (result === expected_result)
                else $fatal(1, "PC=%0d: expected result %0d, got %0d",
                            pc, expected_result, result);

            $display("PC=%0d INSTRUCTION=%h RESULT=%0d",
                     pc, instruction, result);
        end
    endtask

    initial begin
        $dumpfile("cpu_system.vcd");
        $dumpvars(0, cpu_system_tb);

        // program_0.hex encodes the default architecture. Rebuild the same
        // program directly in ROM when a legal architectural width changes.
        if (DATA_WIDTH != 64 || INSTRUCTION_WIDTH != 64 || REG_COUNT != 64 ||
            IMMEDIATE_WIDTH != 32 || OPCODE_WIDTH != 6) begin
            #1; // Let the ROM's time-zero initialization finish first.
            dut.u_cpu.u_fetch.u_imem.memory[0] = encode_instruction(
                ALU_PASS_B, reg_addr_t'(1), ZERO_REG, ZERO_REG,
                1'b1, 1'b0, imm_t'(100));
            dut.u_cpu.u_fetch.u_imem.memory[1] = encode_instruction(
                ALU_PASS_B, reg_addr_t'(2), ZERO_REG, ZERO_REG,
                1'b1, 1'b0, imm_t'(8 * DATA_BYTES));
            dut.u_cpu.u_fetch.u_imem.memory[2] = encode_store(
                reg_addr_t'(1), reg_addr_t'(2), imm_t'(DATA_BYTES));
            dut.u_cpu.u_fetch.u_imem.memory[3] = encode_load(
                reg_addr_t'(3), reg_addr_t'(2), imm_t'(DATA_BYTES));
            dut.u_cpu.u_fetch.u_imem.memory[4] = encode_branch(
                CTRL_BEQ, reg_addr_t'(1), reg_addr_t'(3),
                imm_t'(6 * INSTRUCTION_BYTES));
            dut.u_cpu.u_fetch.u_imem.memory[5] = encode_instruction(
                ALU_PASS_B, reg_addr_t'(4), ZERO_REG, ZERO_REG,
                1'b1, 1'b0, imm_t'(111));
            dut.u_cpu.u_fetch.u_imem.memory[6] = encode_instruction(
                ALU_PASS_B, reg_addr_t'(4), ZERO_REG, ZERO_REG,
                1'b1, 1'b0, imm_t'(222));
        end

        // Hold reset through a rising edge and verify PC reset behavior.
        @(posedge clk);
        #1;
        assert (pc === '0)
            else $fatal(1, "Reset failed");

        @(negedge clk);
        rst = 0;
        run = 1;

        // --------------------------------------------------------
        // MOVI R1, #100
        // --------------------------------------------------------
        check_instruction(
            data_t'(0),
            encode_instruction(ALU_PASS_B, reg_addr_t'(1), ZERO_REG, ZERO_REG,
                               1'b1, 1'b0, imm_t'(100)),
            data_t'(100)
        );
        @(posedge clk);
        @(negedge clk);

        // --------------------------------------------------------
        // MOVI R2, #(8 * DATA_BYTES)
        // --------------------------------------------------------
        check_instruction(
            data_t'(INSTRUCTION_BYTES),
            encode_instruction(ALU_PASS_B, reg_addr_t'(2), ZERO_REG, ZERO_REG,
                               1'b1, 1'b0, imm_t'(8 * DATA_BYTES)),
            data_t'(8 * DATA_BYTES)
        );
        @(posedge clk);
        @(negedge clk);

        // --------------------------------------------------------
        // STORE R1, [R2 + DATA_BYTES]
        // Effective byte address = 9 * DATA_BYTES.
        // --------------------------------------------------------
        check_instruction(
            data_t'(2 * INSTRUCTION_BYTES),
            encode_store(reg_addr_t'(1), reg_addr_t'(2), imm_t'(DATA_BYTES)),
            data_t'(9 * DATA_BYTES)
        );
        assert (dut.bus_valid === 1'b1 &&
                dut.bus_write === 1'b1 &&
                dut.bus_ready === 1'b1)
            else $fatal(1, "STORE bus handshake wrong");
        assert (dut.bus_write_data === data_t'(100))
            else $fatal(1, "STORE data expected 100, got %0d",
                        dut.bus_write_data);

        @(posedge clk); // Commit data-memory write.
        @(negedge clk);

        // --------------------------------------------------------
        // LOAD R3, [R2 + DATA_BYTES]
        // --------------------------------------------------------
        check_instruction(
            data_t'(3 * INSTRUCTION_BYTES),
            encode_load(reg_addr_t'(3), reg_addr_t'(2), imm_t'(DATA_BYTES)),
            data_t'(9 * DATA_BYTES)
        );
        assert (dut.bus_valid === 1'b1 &&
                dut.bus_write === 1'b0 &&
                dut.bus_ready === 1'b1)
            else $fatal(1, "LOAD bus handshake wrong");
        assert (dut.bus_read_data === data_t'(100))
            else $fatal(1, "LOAD data expected 100, got %0d",
                        dut.bus_read_data);

        @(posedge clk); // Commit LOAD writeback R3=100.
        @(negedge clk);

        // --------------------------------------------------------
        // BEQ R1,R3,target -- must be taken because LOAD produced 100.
        // --------------------------------------------------------
        #1;
        assert (pc === data_t'(4 * INSTRUCTION_BYTES))
            else $fatal(1, "BEQ PC wrong: %0d", pc);
        assert (instruction === encode_branch(
                    CTRL_BEQ,
                    reg_addr_t'(1),
                    reg_addr_t'(3),
                    imm_t'(6 * INSTRUCTION_BYTES)))
            else $fatal(1, "Wrong BEQ encoding at PC=%0d", pc);
        assert (execution_valid === 1'b1 && illegal_instruction === 1'b0)
            else $fatal(1, "BEQ failed to execute");

        $display("PC=%0d BEQ R1,R3 -> target=%0d TAKEN",
                 pc, 6 * INSTRUCTION_BYTES);

        @(posedge clk); // Commit branch redirect.
        @(negedge clk);

        // --------------------------------------------------------
        // Branch target: MOVI R4, #222. R4=111 must be skipped.
        // --------------------------------------------------------
        check_instruction(
            data_t'(6 * INSTRUCTION_BYTES),
            encode_instruction(ALU_PASS_B, reg_addr_t'(4), ZERO_REG, ZERO_REG,
                               1'b1, 1'b0, imm_t'(222)),
            data_t'(222)
        );

        @(posedge clk); // Commit R4=222.
        @(negedge clk);
        run = 0;
        #1;

        // Final architectural checks.
        assert (dut.u_cpu.u_core.u_datapath.u_register_file.registers[1] === data_t'(100))
            else $fatal(1, "R1 wrong");
        assert (dut.u_cpu.u_core.u_datapath.u_register_file.registers[3] === data_t'(100))
            else $fatal(1, "R3 LOAD result wrong");
        assert (dut.u_cpu.u_core.u_datapath.u_register_file.registers[4] === data_t'(222))
            else $fatal(1, "R4 branch result wrong");
        assert (dut.u_dmem.memory[9] === data_t'(100))
            else $fatal(1, "Data memory word 9 expected 100, got %0d",
                        dut.u_dmem.memory[9]);

        $display("PASS: STORE wrote memory word 9 = %0d", dut.u_dmem.memory[9]);
        $display("PASS: LOAD wrote R3 = %0d",
                 dut.u_cpu.u_core.u_datapath.u_register_file.registers[3]);
        $display("PASS: BEQ skipped MOVI R4,111 and R4 = %0d",
                 dut.u_cpu.u_core.u_datapath.u_register_file.registers[4]);
        $display("PASS: LACOODA wrapped CPU + local bus memory cpu_system_tb");
        $finish;
    end

    initial begin
        #1500;
        $fatal(1, "TIMEOUT");
    end

endmodule
