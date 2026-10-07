`timescale 1ns/1ps

// ============================================================
// LACOODA minimal-SoC end-to-end regression
//
// Verifies the final CPU boundary connected to external instruction memory,
// the data-bus interconnect, and external data memory, running the
// programs/genesis_64.hex or genesis_32.hex image (selected by WORD_WIDTH).
//
// The image stores each immediate in the word that follows its instruction;
// its data addresses are word-size independent (base 64, offset 8).
// ============================================================

module system_tb;
    import cpu_pkg::*;
    import opcode_pkg::*;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic run = 1'b0;

    word_t pc;
    instruction_t instruction;
    logic execution_valid;
    logic illegal_instruction;
    word_t result;

    always #5 clk = ~clk;

    system dut (
        .clk(clk),
        .rst(rst),
        .run(run),
        .pc(pc),
        .instruction(instruction),
        .retire_valid(execution_valid),
        .illegal_instr(illegal_instruction),
        .alu_result(result)
    );

    task automatic wait_for_buffered_pc(input word_t expected_pc);
        begin
            while (!(dut.u_cpu.u_instruction_fetch.instruction_available && pc === expected_pc)) begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    task automatic check_current(
        input word_t expected_pc,
        input instruction_t expected_instruction,
        input word_t expected_result
    );
        begin
            wait_for_buffered_pc(expected_pc);
            // The ALU (and any memory handshake) is multi-cycle: wait for
            // the core to report the instruction complete.
            wait (execution_valid === 1'b1);
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
        $dumpfile("system.vcd");
        $dumpvars(0, system_tb);

        @(posedge clk);
        #1;
        assert (pc === '0)
            else $fatal(1, "Reset failed");

        @(negedge clk);
        rst = 1'b0;
        run = 1'b1;

        // MOVI R1,100 (word 0 + immediate word 1)
        check_current(
            word_t'(0),
            encode_instruction(ALU_PASS_B, reg_addr_t'(1), ZERO_REG, ZERO_REG,
                               1'b1, 1'b0),
            word_t'(100)
        );
        @(posedge clk);
        #1;

        // MOVI R2,64 (word 2 + immediate word 3)
        check_current(
            word_t'(2 * WORD_BYTES),
            encode_instruction(ALU_PASS_B, reg_addr_t'(2), ZERO_REG, ZERO_REG,
                               1'b1, 1'b0),
            word_t'(64)
        );
        @(posedge clk);
        #1;

        // STORE R1,[R2+8] -> byte address 72 (word 4 + immediate word 5)
        check_current(
            word_t'(4 * WORD_BYTES),
            encode_store(reg_addr_t'(1), reg_addr_t'(2)),
            word_t'(72)
        );
        assert (dut.data_req.valid && dut.data_req.op == bus_pkg::BUS_WRITE && dut.data_rsp.ready)
            else $fatal(1, "STORE D-BUS handshake wrong");
        assert (dut.data_req.addr === word_t'(72))
            else $fatal(1, "STORE address wrong: %0d", dut.data_req.addr);
        assert (dut.data_req.wdata === word_t'(100))
            else $fatal(1, "STORE data wrong");
        @(posedge clk); // Commit STORE and retire instruction.
        #1;

        // LOAD R3,[R2+8] -> byte address 72 (word 6 + immediate word 7)
        check_current(
            word_t'(6 * WORD_BYTES),
            encode_load(reg_addr_t'(3), reg_addr_t'(2)),
            word_t'(72)
        );
        assert (dut.data_req.valid && dut.data_req.op == bus_pkg::BUS_READ && dut.data_rsp.ready)
            else $fatal(1, "LOAD D-BUS handshake wrong");
        assert (dut.data_rsp.rdata === word_t'(100))
            else $fatal(1, "LOAD data expected 100, got %0d", dut.data_rsp.rdata);
        @(posedge clk); // Commit LOAD writeback and retire.
        #1;

        // BEQ R1,R3,target -- taken because LOAD produced 100 (word 8 + imm 9).
        check_current(
            word_t'(8 * WORD_BYTES),
            encode_branch(CTRL_BEQ, reg_addr_t'(1), reg_addr_t'(3)),
            word_t'(200)
        );
        @(posedge clk); // Commit redirect.
        #1;
        assert (pc === word_t'(12 * WORD_BYTES))
            else $fatal(1, "BEQ redirect failed: PC=%0d", pc);

        // Branch target MOVI R4,222 (word 12 + immediate 13);
        // MOVI R4,111 at word 10 was skipped.
        check_current(
            word_t'(12 * WORD_BYTES),
            encode_instruction(ALU_PASS_B, reg_addr_t'(4), ZERO_REG, ZERO_REG,
                               1'b1, 1'b0),
            word_t'(222)
        );
        @(posedge clk);
        #1;

        @(negedge clk);
        run = 1'b0;
        #1;

        assert (dut.u_cpu.u_cpu_core.u_cpu_datapath.u_cpu_register.registers[1] === word_t'(100))
            else $fatal(1, "R1 wrong");
        assert (dut.u_cpu.u_cpu_core.u_cpu_datapath.u_cpu_register.registers[3] === word_t'(100))
            else $fatal(1, "R3 LOAD result wrong");
        assert (dut.u_cpu.u_cpu_core.u_cpu_datapath.u_cpu_register.registers[4] === word_t'(222))
            else $fatal(1, "R4 branch result wrong");
        assert (dut.u_data_memory.mem[72 / WORD_BYTES] === word_t'(100))
            else $fatal(1, "Data memory word wrong");

        $display("PASS: final CPU + external I-BUS memory + D-BUS interconnect/system");
        $finish;
    end

    initial begin
        #400000;
        $fatal(1, "TIMEOUT");
    end

endmodule
