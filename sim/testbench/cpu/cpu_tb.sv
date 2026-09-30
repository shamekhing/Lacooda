`timescale 1ns/1ps

// ============================================================
// LACOODA final CPU-boundary regression
//
// The testbench is the external world: it supplies an instruction-bus slave
// and a controllable data-bus slave. This proves that the CPU itself contains
// neither instruction memory nor data memory and that BOTH master interfaces
// obey the valid/ready hold-until-ready contract.
// ============================================================

module cpu_tb;
    import cpu_pkg::*;
    import alu_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst = 1'b1;
    logic run = 1'b0;

    // Instruction bus.
    logic ibus_valid;
    data_t ibus_address;
    logic ibus_ready;
    instruction_t ibus_read_data;
    logic ibus_allow;

    // Data bus.
    logic dbus_valid;
    logic dbus_write;
    data_t dbus_address;
    data_t dbus_write_data;
    logic dbus_ready;
    data_t dbus_read_data;

    data_t pc;
    instruction_t instruction;
    logic execution_valid;
    logic illegal_instruction;
    data_t result;

    instruction_t program [0:6];

    integer tests = 0;
    integer errors = 0;

    cpu dut (
        .clk(clk),
        .rst(rst),
        .run(run),

        .ibus_valid(ibus_valid),
        .ibus_address(ibus_address),
        .ibus_ready(ibus_ready),
        .ibus_read_data(ibus_read_data),

        .dbus_valid(dbus_valid),
        .dbus_write(dbus_write),
        .dbus_address(dbus_address),
        .dbus_write_data(dbus_write_data),
        .dbus_ready(dbus_ready),
        .dbus_read_data(dbus_read_data),

        .pc(pc),
        .instruction(instruction),
        .execution_valid(execution_valid),
        .illegal_instruction(illegal_instruction),
        .result(result)
    );

    // Controllable instruction-bus slave used only by this testbench.
    // It can insert arbitrary fetch wait states through ibus_allow.
    always_comb begin
        ibus_ready = ibus_valid && ibus_allow;
        ibus_read_data = '0;

        if (ibus_valid &&
            ibus_address % INSTRUCTION_BYTES == 0 &&
            (ibus_address / INSTRUCTION_BYTES) < 7)
            ibus_read_data = program[ibus_address / INSTRUCTION_BYTES];
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
    task automatic wait_for_buffered_pc(input data_t expected_pc);
        begin
            while (!(dut.u_fetch.instruction_available && pc === expected_pc)) begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0, cpu_tb);

        program[0] = encode_instruction(
            ALU_PASS_B, reg_addr_t'(1), ZERO_REG, ZERO_REG,
            1'b1, 1'b0, imm_t'(100));
        program[1] = encode_instruction(
            ALU_PASS_B, reg_addr_t'(2), ZERO_REG, ZERO_REG,
            1'b1, 1'b0, imm_t'(8 * DATA_BYTES));
        program[2] = encode_store(
            reg_addr_t'(1), reg_addr_t'(2), imm_t'(DATA_BYTES));
        program[3] = encode_load(
            reg_addr_t'(3), reg_addr_t'(2), imm_t'(DATA_BYTES));
        program[4] = encode_branch(
            CTRL_BEQ, reg_addr_t'(1), reg_addr_t'(3),
            imm_t'(6 * INSTRUCTION_BYTES));
        program[5] = encode_instruction(
            ALU_PASS_B, reg_addr_t'(4), ZERO_REG, ZERO_REG,
            1'b1, 1'b0, imm_t'(111));
        program[6] = encode_instruction(
            ALU_PASS_B, reg_addr_t'(4), ZERO_REG, ZERO_REG,
            1'b1, 1'b0, imm_t'(222));

        ibus_allow = 1'b0;
        dbus_ready = 1'b0;
        dbus_read_data = '0;

        // Reset architectural state.
        @(posedge clk);
        #1;
        check(pc === data_t'(0), "reset PC is zero");

        @(negedge clk);
        rst = 1'b0;
        run = 1'b1;

        // ----------------------------------------------------
        // I-BUS WAIT-STATE / HOLD GUARANTEE
        // ----------------------------------------------------
        @(posedge clk); // Starts first fetch request.
        #1;
        check(ibus_valid && ibus_address === data_t'(0),
              "I-BUS starts fetch at PC 0");

        // Pause after valid has been asserted. The started request must not
        // disappear before the slave accepts it.
        @(negedge clk);
        run = 1'b0;
        #1;
        check(ibus_valid && ibus_address === data_t'(0),
              "in-flight I-BUS request survives run deassertion");

        @(posedge clk);
        #1;
        check(ibus_valid && ibus_address === data_t'(0),
              "I-BUS address remains stable while ready is low");

        // Accept the fetch. The already-started instruction is then allowed
        // to execute atomically even though run remains low.
        @(negedge clk);
        ibus_allow = 1'b1;
        @(posedge clk);
        #1;
        check(dut.u_fetch.instruction_available &&
              instruction === program[0] && execution_valid,
              "accepted fetch is buffered and executes");

        @(posedge clk); // Retire MOVI R1,100.
        #1;
        check(pc === data_t'(INSTRUCTION_BYTES),
              "PC advances only after fetched instruction retires");
        check(dut.u_core.u_datapath.u_register_file.registers[1] === data_t'(100),
              "MOVI R1 retires after I-BUS fetch");
        check(!ibus_valid,
              "paused CPU does not start another fetch");

        // Resume and execute MOVI R2.
        @(negedge clk);
        run = 1'b1;
        wait_for_buffered_pc(data_t'(INSTRUCTION_BYTES));
        #1;
        check(execution_valid && !dbus_valid,
              "ordinary instruction executes without D-BUS traffic");
        @(posedge clk); // Retire MOVI R2.
        #1;

        // ----------------------------------------------------
        // D-BUS STORE WAIT-STATE / HOLD GUARANTEE
        // ----------------------------------------------------
        wait_for_buffered_pc(data_t'(2 * INSTRUCTION_BYTES));
        #1;
        check(dbus_valid && dbus_write &&
              dbus_address === data_t'(9 * DATA_BYTES) &&
              dbus_write_data === data_t'(100),
              "STORE presents complete D-BUS request");
        check(!execution_valid,
              "STORE does not retire while D-BUS ready is low");

        @(negedge clk);
        run = 1'b0;
        #1;
        check(dbus_valid && dbus_write,
              "in-flight STORE survives run deassertion");

        @(posedge clk);
        #1;
        check(pc === data_t'(2 * INSTRUCTION_BYTES) &&
              dbus_valid &&
              dbus_address === data_t'(9 * DATA_BYTES),
              "STORE PC/request remain stable while waiting");

        @(negedge clk);
        dbus_ready = 1'b1;
        #1;
        check(dbus_valid && execution_valid,
              "STORE completes when D-BUS ready is asserted");
        @(posedge clk); // Retire STORE.
        #1;
        dbus_ready = 1'b0;
        check(pc === data_t'(3 * INSTRUCTION_BYTES),
              "PC advances after STORE handshake");
        check(!ibus_valid,
              "run=0 prevents next fetch after completed STORE");

        // ----------------------------------------------------
        // D-BUS LOAD WAIT-STATE / WRITEBACK GUARANTEE
        // ----------------------------------------------------
        @(negedge clk);
        run = 1'b1;
        dbus_read_data = data_t'(100);
        wait_for_buffered_pc(data_t'(3 * INSTRUCTION_BYTES));
        #1;
        check(dbus_valid && !dbus_write &&
              dbus_address === data_t'(9 * DATA_BYTES),
              "LOAD presents D-BUS read request");
        check(!execution_valid,
              "LOAD does not retire while D-BUS ready is low");

        @(posedge clk);
        #1;
        check(dut.u_core.u_datapath.u_register_file.registers[3] === data_t'(0),
              "stalled LOAD does not write R3 early");

        @(negedge clk);
        dbus_ready = 1'b1;
        #1;
        check(dbus_valid && !dbus_write && execution_valid,
              "LOAD completes on D-BUS handshake");
        @(posedge clk); // Retire LOAD and write R3.
        #1;
        dbus_ready = 1'b0;
        dbus_read_data = '0;
        check(dut.u_core.u_datapath.u_register_file.registers[3] === data_t'(100),
              "LOAD writes D-BUS data to R3");

        // BEQ must observe R3=100 and redirect to instruction 6.
        wait_for_buffered_pc(data_t'(4 * INSTRUCTION_BYTES));
        #1;
        check(execution_valid && !illegal_instruction,
              "BEQ executes after LOAD completion");
        @(posedge clk); // Retire BEQ and redirect PC.
        #1;
        check(pc === data_t'(6 * INSTRUCTION_BYTES),
              "BEQ redirects to branch target");

        // Branch target MOVI R4,222 executes; instruction 5 is never fetched.
        wait_for_buffered_pc(data_t'(6 * INSTRUCTION_BYTES));
        #1;
        check(execution_valid, "branch-target instruction executes");
        @(posedge clk);
        #1;

        @(negedge clk);
        run = 1'b0;
        #1;
        check(dut.u_core.u_datapath.u_register_file.registers[4] === data_t'(222),
              "CPU resumes normally after independent I/D bus stalls");

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
        #4000;
        $fatal(1, "TIMEOUT");
    end

endmodule
