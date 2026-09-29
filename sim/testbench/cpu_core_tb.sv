
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

        .instruction_valid(instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_valid(execution_valid),

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
                "CPU CORE TEST PASSED: %0d checks",
                tests
            );
        end else begin
            $display(
                "CPU CORE TEST FAILED: %0d errors / %0d checks",
                errors,
                tests
            );
            $fatal(1);
        end

        $finish;
    end

endmodule
