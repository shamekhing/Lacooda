`timescale 1ns/1ps

// ============================================================
// LACOODA CPU-wrapper regression
//
// This test drives the CPU bus directly so the slave can deliberately
// delay bus_ready. It proves the contract that closes the CPU boundary:
//
//   - ordinary instructions continue to retire normally
//   - STORE holds PC/request while ready=0
//   - LOAD holds PC/request while ready=0
//   - stalled LOAD does not write RD early
//   - LOAD writes RD on the accepting handshake
//   - execution resumes normally after the stall
// ============================================================

module cpu_tb;
    import cpu_pkg::*;
    import alu_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst = 1'b1;
    logic run = 1'b0;

    logic bus_valid;
    logic bus_write;
    data_t bus_address;
    data_t bus_write_data;
    logic bus_ready;
    data_t bus_read_data;

    data_t pc;
    instruction_t instruction;
    logic execution_valid;
    logic illegal_instruction;
    data_t result;

    integer tests = 0;
    integer errors = 0;

    cpu dut (
        .clk(clk),
        .rst(rst),
        .run(run),

        .bus_valid(bus_valid),
        .bus_write(bus_write),
        .bus_address(bus_address),
        .bus_write_data(bus_write_data),
        .bus_ready(bus_ready),
        .bus_read_data(bus_read_data),

        .pc(pc),
        .instruction(instruction),
        .execution_valid(execution_valid),
        .illegal_instruction(illegal_instruction),
        .result(result)
    );

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

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0, cpu_tb);

        bus_ready = 1'b0;
        bus_read_data = '0;

        // Build the test program directly so this wrapper regression does not
        // depend on the default hex file contents.
        #1;
        dut.u_fetch.u_imem.memory[0] = encode_instruction(
            ALU_PASS_B, reg_addr_t'(1), ZERO_REG, ZERO_REG,
            1'b1, 1'b0, imm_t'(100));
        dut.u_fetch.u_imem.memory[1] = encode_instruction(
            ALU_PASS_B, reg_addr_t'(2), ZERO_REG, ZERO_REG,
            1'b1, 1'b0, imm_t'(8 * DATA_BYTES));
        dut.u_fetch.u_imem.memory[2] = encode_store(
            reg_addr_t'(1), reg_addr_t'(2), imm_t'(DATA_BYTES));
        dut.u_fetch.u_imem.memory[3] = encode_load(
            reg_addr_t'(3), reg_addr_t'(2), imm_t'(DATA_BYTES));
        dut.u_fetch.u_imem.memory[4] = encode_branch(
            CTRL_BEQ, reg_addr_t'(1), reg_addr_t'(3),
            imm_t'(6 * INSTRUCTION_BYTES));
        dut.u_fetch.u_imem.memory[5] = encode_instruction(
            ALU_PASS_B, reg_addr_t'(4), ZERO_REG, ZERO_REG,
            1'b1, 1'b0, imm_t'(111));
        dut.u_fetch.u_imem.memory[6] = encode_instruction(
            ALU_PASS_B, reg_addr_t'(4), ZERO_REG, ZERO_REG,
            1'b1, 1'b0, imm_t'(222));

        // Reset PC/register state.
        @(posedge clk);
        #1;
        check(pc === data_t'(0), "reset PC is zero");

        @(negedge clk);
        rst = 1'b0;
        run = 1'b1;

        // MOVI R1,100 retires normally.
        #1;
        check(pc === data_t'(0) && execution_valid,
              "MOVI R1 executes at PC 0");
        @(posedge clk);
        @(negedge clk);

        // MOVI R2,8*DATA_BYTES retires normally.
        #1;
        check(pc === data_t'(INSTRUCTION_BYTES) && execution_valid,
              "MOVI R2 executes without bus traffic");
        check(bus_valid === 1'b0,
              "ordinary ALU instruction does not use data bus");
        @(posedge clk);
        @(negedge clk);

        // ----------------------------------------------------
        // STORE: deliberately withhold ready for two cycles.
        // ----------------------------------------------------
        #1;
        check(pc === data_t'(2 * INSTRUCTION_BYTES),
              "STORE reached expected PC");
        check(bus_valid && bus_write &&
              bus_address == data_t'(9 * DATA_BYTES) &&
              bus_write_data == data_t'(100),
              "STORE presents complete bus request");
        check(!execution_valid,
              "STORE is not complete while bus_ready is low");

        @(posedge clk);
        #1;
        check(pc === data_t'(2 * INSTRUCTION_BYTES),
              "STORE stall holds PC for first wait cycle");
        check(bus_valid && bus_write &&
              bus_address == data_t'(9 * DATA_BYTES) &&
              bus_write_data == data_t'(100),
              "STORE request remains stable while waiting");

        // Pause the CPU after the request is already outstanding. The wrapper
        // must finish that transaction instead of dropping bus_valid.
        @(negedge clk);
        run = 1'b0;
        #1;
        check(bus_valid && bus_write,
              "in-flight STORE survives run deassertion");

        @(posedge clk);
        #1;
        check(pc === data_t'(2 * INSTRUCTION_BYTES),
              "paused STORE still holds PC while ready=0");

        // Accept STORE while run remains low. The wrapper must retire this
        // already-issued transaction exactly once, then remain paused.
        @(negedge clk);
        bus_ready = 1'b1;
        #1;
        check(bus_valid && bus_write && execution_valid,
              "STORE completes when ready is asserted");
        @(posedge clk);
        @(negedge clk);
        bus_ready = 1'b0;

        check(pc === data_t'(3 * INSTRUCTION_BYTES),
              "PC advances after STORE handshake even while paused");
        check(bus_valid === 1'b0,
              "CPU stops at next instruction after completing paused STORE");

        // Resume at the LOAD.
        run = 1'b1;
        bus_read_data = data_t'(100);
        #1;
        check(bus_valid && !bus_write &&
              bus_address == data_t'(9 * DATA_BYTES),
              "LOAD presents read request");
        check(!execution_valid,
              "LOAD is not complete while bus_ready is low");

        @(posedge clk);
        #1;
        check(pc === data_t'(3 * INSTRUCTION_BYTES),
              "LOAD stall holds PC");
        check(dut.u_core.u_datapath.u_register_file.registers[3] === data_t'(0),
              "stalled LOAD does not write R3 early");

        // Accept LOAD and sample bus_read_data into R3.
        @(negedge clk);
        bus_ready = 1'b1;
        #1;
        check(bus_valid && !bus_write && execution_valid,
              "LOAD completes when ready is asserted");
        @(posedge clk);
        #1;
        check(dut.u_core.u_datapath.u_register_file.registers[3] === data_t'(100),
              "LOAD writes bus_read_data to R3 on handshake");

        @(negedge clk);
        bus_ready = 1'b0;
        bus_read_data = '0;
        check(pc === data_t'(4 * INSTRUCTION_BYTES),
              "PC advances after LOAD handshake");

        // BEQ R1,R3 must still work after the stalled memory operation.
        #1;
        check(execution_valid && !illegal_instruction,
              "BEQ executes after LOAD completion");
        @(posedge clk);
        @(negedge clk);
        check(pc === data_t'(6 * INSTRUCTION_BYTES),
              "BEQ redirects to branch target");

        // Commit MOVI R4,222 at the branch target.
        #1;
        check(execution_valid, "branch-target instruction executes");
        @(posedge clk);
        @(negedge clk);
        run = 1'b0;
        #1;

        check(dut.u_core.u_datapath.u_register_file.registers[4] === data_t'(222),
              "CPU resumes normally after bus stalls");

        $display("========================================");
        $display("LACOODA CPU WRAPPER/BUS TEST SUMMARY");
        $display("Total tests : %0d", tests);
        $display("Passed      : %0d", tests-errors);
        $display("Failed      : %0d", errors);
        $display("========================================");

        if (errors != 0)
            $fatal(1, "CPU WRAPPER/BUS TEST FAILED");

        $display("ALL CPU WRAPPER/BUS TESTS PASSED");
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "TIMEOUT");
    end

endmodule
