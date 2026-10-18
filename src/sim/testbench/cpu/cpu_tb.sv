`timescale 1ns/1ps

// ============================================================
// LACOODA final CPU-boundary regression
//
// The testbench is the external world: it supplies an instruction-bus slave
// and a controllable data-bus slave. This proves that the CPU itself contains
// neither instruction memory nor data memory and that BOTH master interfaces
// obey the valid/ready hold-until-ready contract.
//
// Program image: every instruction that uses an immediate is stored as a
// pair — the instruction word followed by its immediate word.
// ============================================================

module cpu_tb;
    import cpu_pkg::*;
    import opcode_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst = 1'b1;
    logic run = 1'b0;

    // Typed CPU bus interfaces.
    bus_pkg::bus_req_s cpu_instr_bus_req;
    bus_pkg::bus_rsp_s cpu_instr_bus_rsp;
    logic ibus_allow;
    logic ibus_error = 1'b0;
    bus_pkg::bus_req_s cpu_bus_req;
    bus_pkg::bus_rsp_s cpu_bus_rsp;

    word_t pc;
    instruction_t instruction;
    logic execution_valid;
    logic illegal_instruction;
    logic fault;

    instruction_t program_words [0:13];

    integer tests = 0;
    integer errors = 0;

    cpu dut (
        .clk(clk),
        .rst(rst),
        .run(run),

        .cpu_instr_bus_req(cpu_instr_bus_req),
        .cpu_instr_bus_rsp(cpu_instr_bus_rsp),
        .cpu_bus_req(cpu_bus_req),
        .cpu_bus_rsp(cpu_bus_rsp),

        .retire_valid(execution_valid),
        .illegal_instr(illegal_instruction),
        .fault(fault)
    );

    assign pc = dut.u_instruction_fetch.pc;
    assign instruction = dut.instruction;

    // Controllable instruction-bus slave used only by this testbench.
    // It can insert arbitrary fetch wait states through ibus_allow.
    always_comb begin
        cpu_instr_bus_rsp.ready = cpu_instr_bus_req.valid && ibus_allow;
        cpu_instr_bus_rsp.error = ibus_error;
        cpu_instr_bus_rsp.rdata = '0;

        if (cpu_instr_bus_req.valid &&
            cpu_instr_bus_req.addr % WORD_BYTES == 0 &&
            (cpu_instr_bus_req.addr / WORD_BYTES) < 14)
            cpu_instr_bus_rsp.rdata = program_words[cpu_instr_bus_req.addr / WORD_BYTES];
    end

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

    // Wait until the CPU has buffered the instruction at expected_pc.
    task automatic wait_for_buffered_pc(input word_t expected_pc);
        begin
            while (!(dut.u_instruction_fetch.instruction_available && pc === expected_pc)) begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    initial begin
        cpu_bus_rsp.error = 1'b0;
        $dumpfile("cpu.vcd");
        $dumpvars(0, cpu_tb);

        // 0: MOVI R1, 100                (instruction + immediate)
        program_words[0] = encode_instruction(
            ALU_PASS_B, reg_addr_t'(1), ZERO_REG, ZERO_REG, 1'b1, 1'b0);
        program_words[1] = word_t'(100);
        // 2: MOVI R2, base byte address
        program_words[2] = encode_instruction(
            ALU_PASS_B, reg_addr_t'(2), ZERO_REG, ZERO_REG, 1'b1, 1'b0);
        program_words[3] = word_t'(8 * WORD_BYTES);
        // 4: STORE R1, [R2 + WORD_BYTES]
        program_words[4] = encode_store(reg_addr_t'(1), reg_addr_t'(2));
        program_words[5] = word_t'(WORD_BYTES);
        // 6: LOAD R3, [R2 + WORD_BYTES]
        program_words[6] = encode_load(reg_addr_t'(3), reg_addr_t'(2));
        program_words[7] = word_t'(WORD_BYTES);
        // 8: BEQ R1, R3 -> instruction at word index 12
        program_words[8] = encode_branch(
            CTRL_BEQ, reg_addr_t'(1), reg_addr_t'(3));
        program_words[9] = word_t'(12 * WORD_BYTES);
        // 10: MOVI R4, 111 (never executed)
        program_words[10] = encode_instruction(
            ALU_PASS_B, reg_addr_t'(4), ZERO_REG, ZERO_REG, 1'b1, 1'b0);
        program_words[11] = word_t'(111);
        // 12: MOVI R4, 222 (branch target)
        program_words[12] = encode_instruction(
            ALU_PASS_B, reg_addr_t'(4), ZERO_REG, ZERO_REG, 1'b1, 1'b0);
        program_words[13] = word_t'(222);

        ibus_allow = 1'b0;
        cpu_bus_rsp.ready = 1'b0;
        cpu_bus_rsp.rdata = '0;

        // Reset architectural state.
        @(posedge clk);
        #1;
        check(pc === word_t'(0), "reset PC is zero");

        @(negedge clk);
        rst = 1'b0;
        run = 1'b1;

        // ----------------------------------------------------
        // I-BUS WAIT-STATE / HOLD GUARANTEE
        // ----------------------------------------------------
        @(posedge clk); // Starts first fetch request.
        #1;
        check(cpu_instr_bus_req.valid && cpu_instr_bus_req.op == bus_pkg::BUS_READ &&
              cpu_instr_bus_req.addr === word_t'(0) && cpu_instr_bus_req.wdata === '0,
              "I-BUS starts fetch at PC 0");

        // Pause after valid has been asserted. The started request must not
        // disappear before the slave accepts it.
        @(negedge clk);
        run = 1'b0;
        #1;
        check(cpu_instr_bus_req.valid && cpu_instr_bus_req.op == bus_pkg::BUS_READ &&
              cpu_instr_bus_req.addr === word_t'(0) && cpu_instr_bus_req.wdata === '0,
              "in-flight I-BUS request survives run deassertion");

        @(posedge clk);
        #1;
        check(cpu_instr_bus_req.valid && cpu_instr_bus_req.op == bus_pkg::BUS_READ &&
              cpu_instr_bus_req.addr === word_t'(0) && cpu_instr_bus_req.wdata === '0,
              "I-BUS address remains stable while ready is low");

        // Accept the instruction word; the immediate beat completes on the
        // next edge because ibus_allow stays high. The already-started
        // instruction is then allowed to execute atomically even though
        // run remains low.
        @(negedge clk);
        ibus_allow = 1'b1;
        @(posedge clk);
        @(posedge clk);
        #1;
        // MOVI is an ALU instruction: wait for the multi-cycle result.
        wait (execution_valid === 1'b1);
        #1;
        check(dut.u_instruction_fetch.instruction_available &&
              instruction === program_words[0] && execution_valid,
              "accepted fetch (instruction + immediate) is buffered and executes");

        @(posedge clk); // Retire MOVI R1,100.
        #1;
        check(pc === word_t'(2 * WORD_BYTES),
              "PC advances past instruction and immediate");
        check(dut.u_cpu_core.u_cpu_datapath.u_cpu_register.registers[1] === word_t'(100),
              "MOVI R1 retires after I-BUS fetch");
        check(!cpu_instr_bus_req.valid,
              "paused CPU does not start another fetch");

        // Resume and execute MOVI R2.
        @(negedge clk);
        run = 1'b1;
        wait_for_buffered_pc(word_t'(2 * WORD_BYTES));
        wait (execution_valid === 1'b1);
        #1;
        check(execution_valid && !cpu_bus_req.valid,
              "ordinary instruction executes without D-BUS traffic");
        @(posedge clk); // Retire MOVI R2.
        #1;

        // ----------------------------------------------------
        // D-BUS STORE WAIT-STATE / HOLD GUARANTEE
        // ----------------------------------------------------
        wait_for_buffered_pc(word_t'(4 * WORD_BYTES));
        // The effective address is computed by the multi-cycle ALU first.
        wait (cpu_bus_req.valid === 1'b1);
        #1;
        check(cpu_bus_req.valid && (cpu_bus_req.op == bus_pkg::BUS_WRITE) &&
              cpu_bus_req.addr === word_t'(9 * WORD_BYTES) &&
              cpu_bus_req.wdata === word_t'(100),
              "STORE presents complete D-BUS request");
        check(!execution_valid,
              "STORE does not retire while D-BUS ready is low");

        @(negedge clk);
        run = 1'b0;
        #1;
        check(cpu_bus_req.valid && cpu_bus_req.op == bus_pkg::BUS_WRITE,
              "in-flight STORE survives run deassertion");

        @(posedge clk);
        #1;
        check(pc === word_t'(4 * WORD_BYTES) &&
              cpu_bus_req.valid &&
              cpu_bus_req.addr === word_t'(9 * WORD_BYTES) &&
              cpu_bus_req.wdata === word_t'(100),
              "STORE PC/request remain stable while waiting");

        @(negedge clk);
        cpu_bus_rsp.ready = 1'b1;
        #1;
        check(cpu_bus_req.valid && !execution_valid,
              "STORE accepts D-BUS response before retirement");
        @(posedge clk); // Capture STORE response.
        #1;
        check(execution_valid && !cpu_bus_req.valid,
              "STORE retires one cycle after bus acceptance");
        @(posedge clk); // Retire STORE.
        #1;
        cpu_bus_rsp.ready = 1'b0;
        check(pc === word_t'(6 * WORD_BYTES),
              "PC advances after STORE handshake");
        check(!cpu_instr_bus_req.valid,
              "run=0 prevents next fetch after completed STORE");

        // ----------------------------------------------------
        // D-BUS LOAD WAIT-STATE / WRITEBACK GUARANTEE
        // ----------------------------------------------------
        @(negedge clk);
        run = 1'b1;
        cpu_bus_rsp.rdata = word_t'(100);
        wait_for_buffered_pc(word_t'(6 * WORD_BYTES));
        wait (cpu_bus_req.valid === 1'b1);
        #1;
        check(cpu_bus_req.valid && cpu_bus_req.op == bus_pkg::BUS_READ &&
              cpu_bus_req.addr === word_t'(9 * WORD_BYTES),
              "LOAD presents D-BUS read request");
        check(!execution_valid,
              "LOAD does not retire while D-BUS ready is low");

        @(posedge clk);
        #1;
        check(dut.u_cpu_core.u_cpu_datapath.u_cpu_register.registers[3] === word_t'(0),
              "stalled LOAD does not write R3 early");

        @(negedge clk);
        cpu_bus_rsp.ready = 1'b1;
        #1;
        check(cpu_bus_req.valid && cpu_bus_req.op == bus_pkg::BUS_READ && !execution_valid,
              "LOAD accepts D-BUS response before retirement");
        @(posedge clk); // Capture LOAD response.
        #1;
        check(execution_valid && !cpu_bus_req.valid,
              "LOAD retires one cycle after bus acceptance");
        @(posedge clk); // Retire LOAD and write R3.
        #1;
        cpu_bus_rsp.ready = 1'b0;
        cpu_bus_rsp.rdata = '0;
        check(dut.u_cpu_core.u_cpu_datapath.u_cpu_register.registers[3] === word_t'(100),
              "LOAD writes D-BUS data to R3");

        // BEQ must observe R3=100 and redirect to instruction 6 (word 12).
        wait_for_buffered_pc(word_t'(8 * WORD_BYTES));
        wait (execution_valid === 1'b1);
        #1;
        check(execution_valid && !illegal_instruction,
              "BEQ executes after LOAD completion");
        @(posedge clk); // Retire BEQ and redirect PC.
        #1;
        check(pc === word_t'(12 * WORD_BYTES),
              "BEQ redirects to branch target");

        // Branch target MOVI R4,222 executes; instruction 5 is never fetched.
        wait_for_buffered_pc(word_t'(12 * WORD_BYTES));
        wait (execution_valid === 1'b1);
        #1;
        check(execution_valid, "branch-target instruction executes");
        @(posedge clk);
        #1;

        @(negedge clk);
        run = 1'b0;
        #1;
        check(dut.u_cpu_core.u_cpu_datapath.u_cpu_register.registers[4] === word_t'(222),
              "CPU resumes normally after independent I/D bus stalls");

        // Carry chaining and a failed LOAD must not silently commit data.
        @(negedge clk);
        rst = 1'b1;
        program_words[0] = encode_instruction(ALU_PASS_B, reg_addr_t'(1), ZERO_REG, ZERO_REG, 1'b1, 1'b0);
        program_words[1] = '1;
        program_words[2] = encode_instruction(ALU_PASS_B, reg_addr_t'(2), ZERO_REG, ZERO_REG, 1'b1, 1'b0);
        program_words[3] = word_t'(1);
        program_words[4] = encode_instruction(ALU_ADD, reg_addr_t'(3), reg_addr_t'(1), reg_addr_t'(2), 1'b0, 1'b1);
        program_words[5] = encode_instruction(ALU_ADC, reg_addr_t'(4), ZERO_REG, ZERO_REG, 1'b0, 1'b0);
        program_words[6] = encode_load(reg_addr_t'(5), ZERO_REG);
        program_words[7] = '0;
        ibus_allow = 1'b1;
        cpu_bus_rsp.ready = 1'b0;
        @(negedge clk);
        rst = 1'b0;
        run = 1'b1;
        wait_for_buffered_pc(word_t'(5 * WORD_BYTES));
        wait (execution_valid === 1'b1);
        @(posedge clk);
        #1;
        check(dut.u_cpu_core.u_cpu_datapath.u_cpu_register.registers[4] === word_t'(1),
              "ADC consumes carry from prior ADD");
        wait (cpu_bus_req.valid === 1'b1);
        @(negedge clk);
        cpu_bus_rsp.error = 1'b1;
        cpu_bus_rsp.ready = 1'b1;
        @(posedge clk);
        #1;
        check(fault && !execution_valid &&
              dut.u_cpu_core.u_cpu_datapath.u_cpu_register.registers[5] === '0,
              "failed LOAD latches fault without writeback");

        // A fetch error also stops the CPU before an instruction is buffered.
        @(negedge clk);
        rst = 1'b1;
        cpu_bus_rsp.error = 1'b0;
        cpu_bus_rsp.ready = 1'b0;
        @(negedge clk);
        rst = 1'b0;
        ibus_error = 1'b1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        #1;
        check(fault && !dut.u_instruction_fetch.instruction_available,
              "instruction bus error latches fault");

        @(negedge clk);
        rst = 1'b1;
        ibus_error = 1'b0;
        program_words[0] = '1;
        @(negedge clk);
        rst = 1'b0;
        repeat (4) @(posedge clk);
        #1;
        check(fault && pc === '0 && !execution_valid,
              "illegal instruction latches fault without retiring");

        $display("========================================");
        $display("LACOODA FINAL CPU I-BUS/D-BUS TEST SUMMARY");
        $display("Total tests : %0d", tests);
        $display("Passed      : %0d", tests-errors);
        $display("Failed      : %0d", errors);
        $display("========================================");

        if (errors != 0)
            $fatal(1, "FINAL CPU I-BUS/D-BUS TEST FAILED");

        $display("ALL FINAL CPU I-BUS/D-BUS TESTS PASSED");
        $finish;
    end

    initial begin
        #400000;
        $fatal(1, "TIMEOUT");
    end

endmodule
