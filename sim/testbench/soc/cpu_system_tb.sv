`timescale 1ns/1ps

// ============================================================
// LACOODA minimal-SoC end-to-end regression
//
// Verifies the final CPU boundary connected to external instruction memory,
// the data-bus interconnect, and external data memory.
// ============================================================

module cpu_system_tb;
    import cpu_pkg::*;
    import opcode_pkg::*;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic run = 1'b0;

    reg_t pc;
    instruction_t instruction;
    logic execution_valid;
    logic illegal_instruction;
    reg_t result;

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

    task automatic wait_for_buffered_pc(input reg_t expected_pc);
        begin
            while (!(dut.u_cpu.u_instruction_fetch.instruction_available && pc === expected_pc)) begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    task automatic check_current(
        input reg_t expected_pc,
        input instruction_t expected_instruction,
        input reg_t expected_result
    );
        begin
            wait_for_buffered_pc(expected_pc);
            #1;

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
        // program directly in external instruction memory if widths change.
        if (REG_FILE_WIDTH != 64 || INSTRUCTION_MEMORY_WIDTH != 64 || REG_FILE_COUNT != 64 ||
            IMMEDIATE_WIDTH != 32 || OPCODE_WIDTH != 6) begin
            #1;
            dut.u_instruction_memory.memory[0] = encode_instruction(
                ALU_PASS_B, reg_addr_t'(1), ZERO_REG, ZERO_REG,
                1'b1, 1'b0, imm_t'(100));
            dut.u_instruction_memory.memory[1] = encode_instruction(
                ALU_PASS_B, reg_addr_t'(2), ZERO_REG, ZERO_REG,
                1'b1, 1'b0, imm_t'(8 * REG_FILE_BYTES));
            dut.u_instruction_memory.memory[2] = encode_store(
                reg_addr_t'(1), reg_addr_t'(2), imm_t'(REG_FILE_BYTES));
            dut.u_instruction_memory.memory[3] = encode_load(
                reg_addr_t'(3), reg_addr_t'(2), imm_t'(REG_FILE_BYTES));
            dut.u_instruction_memory.memory[4] = encode_branch(
                CTRL_BEQ, reg_addr_t'(1), reg_addr_t'(3),
                imm_t'(6 * INSTRUCTION_MEMORY_BYTES));
            dut.u_instruction_memory.memory[5] = encode_instruction(
                ALU_PASS_B, reg_addr_t'(4), ZERO_REG, ZERO_REG,
                1'b1, 1'b0, imm_t'(111));
            dut.u_instruction_memory.memory[6] = encode_instruction(
                ALU_PASS_B, reg_addr_t'(4), ZERO_REG, ZERO_REG,
                1'b1, 1'b0, imm_t'(222));
        end

        @(posedge clk);
        #1;
        assert (pc === '0)
            else $fatal(1, "Reset failed");

        @(negedge clk);
        rst = 1'b0;
        run = 1'b1;

        // MOVI R1,100
        check_current(
            reg_t'(0),
            encode_instruction(ALU_PASS_B, reg_addr_t'(1), ZERO_REG, ZERO_REG,
                               1'b1, 1'b0, imm_t'(100)),
            reg_t'(100)
        );
        @(posedge clk);
        #1;

        // MOVI R2,8*REG_FILE_BYTES
        check_current(
            reg_t'(INSTRUCTION_MEMORY_BYTES),
            encode_instruction(ALU_PASS_B, reg_addr_t'(2), ZERO_REG, ZERO_REG,
                               1'b1, 1'b0, imm_t'(8 * REG_FILE_BYTES)),
            reg_t'(8 * REG_FILE_BYTES)
        );
        @(posedge clk);
        #1;

        // STORE R1,[R2+REG_FILE_BYTES]
        check_current(
            reg_t'(2 * INSTRUCTION_MEMORY_BYTES),
            encode_store(reg_addr_t'(1), reg_addr_t'(2), imm_t'(REG_FILE_BYTES)),
            reg_t'(9 * REG_FILE_BYTES)
        );
        assert (dut.dbus_valid && dut.dbus_write && dut.dbus_ready)
            else $fatal(1, "STORE D-BUS handshake wrong");
        assert (dut.dbus_write_data === reg_t'(100))
            else $fatal(1, "STORE data wrong");
        @(posedge clk); // Commit STORE and retire instruction.
        #1;

        // LOAD R3,[R2+REG_FILE_BYTES]
        check_current(
            reg_t'(3 * INSTRUCTION_MEMORY_BYTES),
            encode_load(reg_addr_t'(3), reg_addr_t'(2), imm_t'(REG_FILE_BYTES)),
            reg_t'(9 * REG_FILE_BYTES)
        );
        assert (dut.dbus_valid && !dut.dbus_write && dut.dbus_ready)
            else $fatal(1, "LOAD D-BUS handshake wrong");
        assert (dut.dbus_read_data === reg_t'(100))
            else $fatal(1, "LOAD data expected 100, got %0d", dut.dbus_read_data);
        @(posedge clk); // Commit LOAD writeback and retire.
        #1;

        // BEQ R1,R3,target -- taken because LOAD produced 100.
        check_current(
            reg_t'(4 * INSTRUCTION_MEMORY_BYTES),
            encode_branch(CTRL_BEQ, reg_addr_t'(1), reg_addr_t'(3),
                          imm_t'(6 * INSTRUCTION_MEMORY_BYTES)),
            reg_t'(200)
        );
        @(posedge clk); // Commit redirect.
        #1;
        assert (pc === reg_t'(6 * INSTRUCTION_MEMORY_BYTES))
            else $fatal(1, "BEQ redirect failed: PC=%0d", pc);

        // Branch target MOVI R4,222; MOVI R4,111 was skipped.
        check_current(
            reg_t'(6 * INSTRUCTION_MEMORY_BYTES),
            encode_instruction(ALU_PASS_B, reg_addr_t'(4), ZERO_REG, ZERO_REG,
                               1'b1, 1'b0, imm_t'(222)),
            reg_t'(222)
        );
        @(posedge clk);
        #1;

        @(negedge clk);
        run = 1'b0;
        #1;

        assert (dut.u_cpu.u_cpu_core.u_datapath.u_register_file.registers[1] === reg_t'(100))
            else $fatal(1, "R1 wrong");
        assert (dut.u_cpu.u_cpu_core.u_datapath.u_register_file.registers[3] === reg_t'(100))
            else $fatal(1, "R3 LOAD result wrong");
        assert (dut.u_cpu.u_cpu_core.u_datapath.u_register_file.registers[4] === reg_t'(222))
            else $fatal(1, "R4 branch result wrong");
        assert (dut.u_data_memory.memory[9] === reg_t'(100))
            else $fatal(1, "Data memory word 9 wrong");

        $display("PASS: final CPU + external I-BUS memory + D-BUS interconnect/system");
        $finish;
    end

    initial begin
        #3000;
        $fatal(1, "TIMEOUT");
    end

endmodule
