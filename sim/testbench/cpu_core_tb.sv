
`timescale 1ns/1ps

module cpu_core_tb;

    import cpu_pkg::*;
    import alu_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst;
    logic instruction_enable;
    instruction_t instruction;
    logic carry_in;

    // Data-bus handshake interface.
    logic bus_ready;
    data_t bus_read_data;
    logic bus_valid;
    logic bus_write;
    data_t bus_address;
    data_t bus_write_data;

    logic instruction_valid;
    logic illegal_instruction;
    logic execution_valid;

    data_t operand_a;
    data_t operand_b;
    data_t result;

    flags_t alu_flags;
    flags_t status_flags;

    integer tests = 0;
    integer errors = 0;

    cpu_core dut (
        .clk(clk),
        .rst(rst),

        .instruction_enable(instruction_enable),
        .instruction(instruction),
        .carry_in(carry_in),

        .bus_ready(bus_ready),
        .bus_read_data(bus_read_data),

        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_valid(execution_valid),

        .bus_valid(bus_valid),
        .bus_write(bus_write),
        .bus_address(bus_address),
        .bus_write_data(bus_write_data),

        .operand_a(operand_a),
        .operand_b(operand_b),
        .result(result),

        .alu_flags(alu_flags),
        .status_flags(status_flags)
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
        input imm_t immediate_value
    );
        return encode_instruction(
            op,
            destination,
            source_a,
            source_b,
            immediate_mode,
            update_status,
            immediate_value
        );
    endfunction

    // Execute exactly one instruction at the next rising edge.
    task automatic execute(
        input instruction_t word,
        input logic expected_valid,
        input data_t expected_result
    );
        @(negedge clk);

        instruction = word;
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
            if (execution_valid !== 1'b1) begin
                $display("FAIL: execution_valid is not asserted");
                errors = errors + 1;
            end

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
        input data_t expected
    );
        @(negedge clk);

        instruction = make_instruction(
            ALU_PASS_A,
            ZERO_REG,
            address,
            ZERO_REG,
            1'b0,
            1'b0,
            imm_t'(0)
        );

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
        bus_ready = 1'b1;
        bus_read_data = '0;

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
                imm_t'(25)
            ),
            1'b1,
            data_t'(25)
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
                imm_t'(100)
            ),
            1'b1,
            data_t'(100)
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
                imm_t'(0)
            ),
            1'b1,
            data_t'(125)
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
                imm_t'(0)
            ),
            1'b1,
            data_t'(100)
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
                imm_t'(-1)
            ),
            1'b1,
            data_t'(24)
        );

        check_register(reg_addr_t'(1), data_t'(25));
        check_register(reg_addr_t'(2), data_t'(100));
        check_register(reg_addr_t'(3), data_t'(125));
        check_register(reg_addr_t'(4), data_t'(100));
        check_register(reg_addr_t'(5), data_t'(24));

        // --------------------------------------------------------
        // STAGE 7 LOAD / STORE
        // --------------------------------------------------------

        // MOVI R10, #(8 * DATA_BYTES) -- aligned base byte address
        execute(
            make_instruction(
                ALU_PASS_B,
                reg_addr_t'(10),
                ZERO_REG,
                ZERO_REG,
                1'b1,
                1'b0,
                imm_t'(8 * DATA_BYTES)
            ),
            1'b1,
            data_t'(8 * DATA_BYTES)
        );

        // MOVI R11, #777      -- value to store
        execute(
            make_instruction(
                ALU_PASS_B,
                reg_addr_t'(11),
                ZERO_REG,
                ZERO_REG,
                1'b1,
                1'b0,
                imm_t'(777)
            ),
            1'b1,
            data_t'(777)
        );

        // STORE R11, [R10 + DATA_BYTES]
        @(negedge clk);
        instruction = encode_store(reg_addr_t'(11), reg_addr_t'(10), imm_t'(DATA_BYTES));
        instruction_enable = 1'b1;
        bus_read_data = '0;
        #1;

        tests = tests + 1;
        if (!(instruction_valid && execution_valid && !illegal_instruction &&
              bus_valid && bus_write && bus_ready &&
              bus_address == data_t'(9 * DATA_BYTES) &&
              bus_write_data == data_t'(777))) begin
            $display(
                "FAIL: STORE bus addr=%h data=%h valid=%b write=%b ready=%b",
                bus_address, bus_write_data, bus_valid, bus_write, bus_ready
            );
            errors = errors + 1;
        end else begin
            $display("PASS: STORE addr=%0d data=%0d",
                     bus_address, bus_write_data);
        end

        @(posedge clk);
        #1;
        instruction_enable = 1'b0;

        // LOAD R12, [R10 + DATA_BYTES]. First hold bus_ready low to prove
        // that a valid memory instruction does not retire or write RD early.
        @(negedge clk);
        instruction = encode_load(reg_addr_t'(12), reg_addr_t'(10), imm_t'(DATA_BYTES));
        instruction_enable = 1'b1;
        bus_ready = 1'b0;
        bus_read_data = data_t'(777);
        #1;

        tests = tests + 1;
        if (!(instruction_valid && !execution_valid && !illegal_instruction &&
              bus_valid && !bus_write && !bus_ready &&
              bus_address == data_t'(9 * DATA_BYTES))) begin
            $display(
                "FAIL: waiting LOAD bus addr=%h valid=%b write=%b ready=%b exec=%b",
                bus_address, bus_valid, bus_write, bus_ready, execution_valid
            );
            errors = errors + 1;
        end else begin
            $display("PASS: LOAD waits while bus_ready=0");
        end

        // A rising edge while ready is low must not write the destination.
        @(posedge clk);
        #1;
        tests = tests + 1;
        if (dut.u_datapath.u_register_file.registers[12] !== data_t'(0)) begin
            $display("FAIL: stalled LOAD wrote R12 before bus handshake");
            errors = errors + 1;
        end else begin
            $display("PASS: stalled LOAD did not write R12");
        end

        // Complete the same held request.
        @(negedge clk);
        bus_ready = 1'b1;
        #1;

        tests = tests + 1;
        if (!(bus_valid && !bus_write && bus_ready && execution_valid)) begin
            $display("FAIL: LOAD did not complete when bus_ready asserted");
            errors = errors + 1;
        end else begin
            $display("PASS: LOAD completes on valid/ready handshake");
        end

        @(posedge clk);
        #1;
        instruction_enable = 1'b0;
        bus_ready = 1'b1;
        bus_read_data = '0;

        check_register(reg_addr_t'(12), data_t'(777));

        // Writing to R0 must not change its value.
        execute(
            make_instruction(
                ALU_PASS_B,
                ZERO_REG,
                ZERO_REG,
                ZERO_REG,
                1'b1,
                1'b0,
                imm_t'(99)
            ),
            1'b1,
            data_t'(99)
        );

        check_register(ZERO_REG, data_t'(0));

        // An illegal encoding must not overwrite R3.
        // Register mode with a nonzero immediate is invalid.
        execute(
            make_instruction(
                ALU_ADD,
                reg_addr_t'(3),
                reg_addr_t'(1),
                reg_addr_t'(2),
                1'b0,
                1'b1,
                imm_t'(1)
            ),
            1'b0,
            '0
        );

        check_register(reg_addr_t'(3), data_t'(125));

        // Verify that the illegal instruction did not update flags.
        tests = tests + 1;
        if (status_flags.Z !== 1'b0 ||
            status_flags.N !== 1'b0) begin
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
