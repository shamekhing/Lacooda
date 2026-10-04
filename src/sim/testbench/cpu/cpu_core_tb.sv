`timescale 1ns/1ps

module cpu_core_tb;

    import cpu_pkg::*;
    import cpu_pkg::*;
    import opcode_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst;
    logic instruction_enable;
    instruction_t instruction;
    logic carry_in;

    // Data-bus handshake interface.
    logic dbus_ready;
    word_t dbus_read_data;
    logic dbus_valid;
    logic dbus_write;
    word_t dbus_address;
    word_t dbus_write_data;
    word_t immediate_word;

    logic instruction_valid;
    logic illegal_instruction;
    logic execution_valid;

    word_t operand_a;
    word_t operand_b;
    word_t result;

    flags_t alu_flags;
    cpu_pkg::status_t status_flags;

    integer tests = 0;
    integer errors = 0;

    // The immediate is a separate word delivered on its own port, exactly
    // like the fetch unit does. make_instruction records it; execute()
    // presents it to the core together with the instruction word.
    localparam word_t STORE_TEST_IMM = word_t'(777);
    localparam word_t STORE_TEST_VALUE = word_t'(STORE_TEST_IMM);

    word_t pending_immediate;

    cpu_core dut (
        .clk(clk),
        .rst(rst),

        .core_enable(instruction_enable),
        .instruction_word(instruction),
        .immediate_word(immediate_word),
        .carry_in(carry_in),

        .dbus_ready(dbus_ready),
        .dbus_rdata(dbus_read_data),

        .decode_valid(instruction_valid),
        .illegal_instr(illegal_instruction),
        .retire_valid(execution_valid),

        .dbus_valid(dbus_valid),
        .dbus_write(dbus_write),
        .dbus_addr(dbus_address),
        .dbus_wdata(dbus_write_data),

        .operand_a(operand_a),
        .operand_b(operand_b),
        .alu_result(result),

        .flags(alu_flags),
        .status(status_flags)
    );

    // --------------------------------------------------------
    // INSTRUCTION HELPERS
    // --------------------------------------------------------

    function automatic instruction_t make_instruction(
        input opcode_t op,
        input reg_addr_t destination,
        input reg_addr_t source_a,
        input reg_addr_t source_b,
        input logic immediate_mode,
        input logic update_status,
        input word_t immediate_value
    );
        pending_immediate = immediate_value;
        return encode_instruction(
            op,
            destination,
            source_a,
            source_b,
            immediate_mode,
            update_status
        );
    endfunction

    // Execute exactly one instruction. The ALU is multi-cycle, so the
    // task waits for the core to report completion before sampling.
    task automatic execute(
        input instruction_t word,
        input logic expected_valid,
        input word_t expected_result
    );
        @(negedge clk);

        instruction = word;
        immediate_word = pending_immediate;
        instruction_enable = 1'b1;

        #1;

        tests = tests + 1;

        if (instruction_valid !== expected_valid) begin
            $display(
                "FAIL: instruction validity expected=%b actual=%b",
                expected_valid,
                instruction_valid
            );
            errors = errors + 1;
        end

        if (illegal_instruction !== !expected_valid) begin
            $display("FAIL: illegal_instruction mismatch");
            errors = errors + 1;
        end

        if (expected_valid) begin
            // Wait for the multi-cycle ALU to finish and retire.
            wait (execution_valid === 1'b1);
            #1;

            if (result !== expected_result) begin
                $display(
                    "FAIL: result expected=%h actual=%h",
                    expected_result,
                    result
                );
                errors = errors + 1;
            end
        end else begin
            if (execution_valid !== 1'b0) begin
                $display("FAIL: illegal instruction executed");
                errors = errors + 1;
            end
        end

        // Commit on the rising edge.
        @(posedge clk);
        #1;

        instruction_enable = 1'b0;
    endtask

    // Observe a register through an encoded MOV instruction.
    // instruction_enable stays low, so this does not write back.
    task automatic check_register(
        input reg_addr_t address,
        input word_t expected
    );
        @(negedge clk);

        instruction = make_instruction(
            ALU_PASS_A,
            ZERO_REG,
            address,
            ZERO_REG,
            1'b0,
            1'b0,
            word_t'(0)
        );

        immediate_word = pending_immediate;
        instruction_enable = 1'b0;

        #1;

        tests = tests + 1;

        if (operand_a !== expected) begin
            $display(
                "FAIL: R%0d expected=%h actual=%h",
                address,
                expected,
                operand_a
            );
            errors = errors + 1;
        end else begin
            $display("PASS: R%0d = %h", address, operand_a);
        end
    endtask

    // --------------------------------------------------------
    // TEST SEQUENCE
    // --------------------------------------------------------

    initial begin
        $dumpfile("cpu_core.vcd");
        $dumpvars(0, cpu_core_tb);

        rst = 1'b1;
        instruction_enable = 1'b0;
        instruction = '0;
        carry_in = 1'b0;
        dbus_ready = 1'b1;
        dbus_read_data = '0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // MOVI R1, #25
        execute(
            make_instruction(
                ALU_PASS_B,
                reg_addr_t'(1),
                ZERO_REG,
                ZERO_REG,
                1'b1,
                1'b0,
                word_t'(25)
            ),
            1'b1,
            word_t'(25)
        );

        // MOVI R2, #100
        execute(
            make_instruction(
                ALU_PASS_B,
                reg_addr_t'(2),
                ZERO_REG,
                ZERO_REG,
                1'b1,
                1'b0,
                word_t'(100)
            ),
            1'b1,
            word_t'(100)
        );

        // ADD R3, R1, R2 => 125
        execute(
            make_instruction(
                ALU_ADD,
                reg_addr_t'(3),
                reg_addr_t'(1),
                reg_addr_t'(2),
                1'b0,
                1'b1,
                word_t'(0)
            ),
            1'b1,
            word_t'(125)
        );

        // SUB R4, R3, R1 => 100
        execute(
            make_instruction(
                ALU_SUB,
                reg_addr_t'(4),
                reg_addr_t'(3),
                reg_addr_t'(1),
                1'b0,
                1'b1,
                word_t'(0)
            ),
            1'b1,
            word_t'(100)
        );

        // ADD R5, R1, #-1 => 24
        execute(
            make_instruction(
                ALU_ADD,
                reg_addr_t'(5),
                reg_addr_t'(1),
                ZERO_REG,
                1'b1,
                1'b1,
                word_t'(-1)
            ),
            1'b1,
            word_t'(24)
        );

        check_register(reg_addr_t'(1), word_t'(25));
        check_register(reg_addr_t'(2), word_t'(100));
        check_register(reg_addr_t'(3), word_t'(125));
        check_register(reg_addr_t'(4), word_t'(100));
        check_register(reg_addr_t'(5), word_t'(24));

        // --------------------------------------------------------
        // STAGE 7 LOAD / STORE
        // --------------------------------------------------------

        // MOVI R10, #(8 * WORD_BYTES) -- aligned base byte address
        execute(
            make_instruction(
                ALU_PASS_B,
                reg_addr_t'(10),
                ZERO_REG,
                ZERO_REG,
                1'b1,
                1'b0,
                word_t'(8 * WORD_BYTES)
            ),
            1'b1,
            word_t'(8 * WORD_BYTES)
        );

        // MOVI R11, #STORE_TEST_IMM -- value to store after encoding
        execute(
            make_instruction(
                ALU_PASS_B,
                reg_addr_t'(11),
                ZERO_REG,
                ZERO_REG,
                1'b1,
                1'b0,
                STORE_TEST_IMM
            ),
            1'b1,
            STORE_TEST_VALUE
        );

        // STORE R11, [R10 + WORD_BYTES]. The ALU first computes the
        // effective address, then the request is issued on the bus.
        @(negedge clk);
        instruction = encode_store(reg_addr_t'(11), reg_addr_t'(10));
        immediate_word = word_t'(WORD_BYTES);
        instruction_enable = 1'b1;
        dbus_read_data = '0;

        wait (dbus_valid === 1'b1);
        #1;

        tests = tests + 1;
        if (!(instruction_valid && execution_valid && !illegal_instruction &&
              dbus_valid && dbus_write && dbus_ready &&
              dbus_address == word_t'(9 * WORD_BYTES) &&
              dbus_write_data == STORE_TEST_VALUE)) begin
            $display(
                "FAIL: STORE bus addr=%h data=%h valid=%b write=%b ready=%b",
                dbus_address, dbus_write_data, dbus_valid, dbus_write, dbus_ready
            );
            errors = errors + 1;
        end else begin
            $display("PASS: STORE addr=%0d data=%0d",
                     dbus_address, dbus_write_data);
        end

        @(posedge clk);
        #1;
        instruction_enable = 1'b0;

        // LOAD R12, [R10 + WORD_BYTES]. First hold dbus_ready low to prove
        // that a valid memory instruction does not retire or write RD early.
        @(negedge clk);
        instruction = encode_load(reg_addr_t'(12), reg_addr_t'(10));
        immediate_word = word_t'(WORD_BYTES);
        instruction_enable = 1'b1;
        dbus_ready = 1'b0;
        dbus_read_data = STORE_TEST_VALUE;

        // Wait until the ALU has produced the address and the request is out.
        wait (dbus_valid === 1'b1);
        #1;

        tests = tests + 1;
        if (!(instruction_valid && !execution_valid && !illegal_instruction &&
              dbus_valid && !dbus_write && !dbus_ready &&
              dbus_address == word_t'(9 * WORD_BYTES))) begin
            $display(
                "FAIL: waiting LOAD bus addr=%h valid=%b write=%b ready=%b exec=%b",
                dbus_address, dbus_valid, dbus_write, dbus_ready, execution_valid
            );
            errors = errors + 1;
        end else begin
            $display("PASS: LOAD waits while dbus_ready=0");
        end

        // A rising edge while ready is low must not write the destination.
        @(posedge clk);
        #1;
        tests = tests + 1;
        if (dut.u_datapath.u_register_file.registers[12] !== word_t'(0)) begin
            $display("FAIL: stalled LOAD wrote R12 before bus handshake");
            errors = errors + 1;
        end else begin
            $display("PASS: stalled LOAD did not write R12");
        end

        // Complete the same held request.
        @(negedge clk);
        dbus_ready = 1'b1;
        #1;

        tests = tests + 1;
        if (!(dbus_valid && !dbus_write && dbus_ready && execution_valid)) begin
            $display("FAIL: LOAD did not complete when dbus_ready asserted");
            errors = errors + 1;
        end else begin
            $display("PASS: LOAD completes on valid/ready handshake");
        end

        @(posedge clk);
        #1;
        instruction_enable = 1'b0;
        dbus_ready = 1'b1;
        dbus_read_data = '0;

        check_register(reg_addr_t'(12), STORE_TEST_VALUE);

        // Writing to R0 must not change its value.
        execute(
            make_instruction(
                ALU_PASS_B,
                ZERO_REG,
                ZERO_REG,
                ZERO_REG,
                1'b1,
                1'b0,
                word_t'(99)
            ),
            1'b1,
            word_t'(99)
        );

        check_register(ZERO_REG, word_t'(0));

        // A register-mode instruction carries no immediate word, so a
        // nonzero value on the immediate port must be ignored: R3 keeps
        // its value (R1 + R2 = 125) and the flags from ADD are Z=N=0.
        execute(
            make_instruction(
                ALU_ADD,
                reg_addr_t'(3),
                reg_addr_t'(1),
                reg_addr_t'(2),
                1'b0,
                1'b1,
                word_t'(1)
            ),
            1'b1,
            word_t'(125)
        );

        check_register(reg_addr_t'(3), word_t'(125));

        // Verify that the illegal instruction did not update flags.
        tests = tests + 1;
        if (status_flags[0] !== 1'b0 ||
            status_flags[1] !== 1'b0) begin
            $display("FAIL: status flags changed unexpectedly");
            errors = errors + 1;
        end

        // The instruction remains present but is disabled.
        // No additional register write should occur.
        @(negedge clk);
        instruction_enable = 1'b0;
        #1;

        tests = tests + 1;
        if (execution_valid !== 1'b0) begin
            $display("FAIL: disabled instruction is executing");
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display(
                "CPU CORE BUS TEST PASSED: %0d checks",
                tests
            );
        end else begin
            $display(
                "CPU CORE BUS TEST FAILED: %0d errors / %0d checks",
                errors,
                tests
            );
            $fatal(1);
        end

        $finish;
    end

endmodule
