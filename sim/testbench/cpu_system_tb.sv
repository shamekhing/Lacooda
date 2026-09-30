`timescale 1ns/1ps

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

    cpu_pkg::data_t result;

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

        #1;

        assert (pc === expected_pc)
            else $fatal(1, "Wrong PC: %0d", pc);

        assert (instruction === expected_instruction)
            else $fatal(1, "Wrong instruction at PC=%0d", pc);

        assert (execution_valid === 1'b1)
            else $fatal(1, "Execution invalid at PC=%0d", pc);

        assert (illegal_instruction === 1'b0)
            else $fatal(1, "Illegal instruction at PC=%0d", pc);

        assert (result === expected_result)
            else $fatal(1,
                "PC=%0d: expected result %0d, got %0d",
                pc, expected_result, result);

        $display(
            "PC=%0d INSTRUCTION=%016h RESULT=%0d",
            pc, instruction, result
        );

    endtask

    initial begin

        $dumpfile("cpu_system.vcd");
        $dumpvars(0, cpu_system_tb);

        // Initialize processor
        @(posedge clk);
        #1;

        assert (pc === '0)
            else $fatal(1, "Reset failed");

        // Start program
        @(negedge clk);
        rst = 0;
        run = 1;

        // MOVI R1, #50
        check_instruction(
            '0,
            encode_instruction(ALU_PASS_B, reg_addr_t'(1), ZERO_REG, ZERO_REG,
                               1'b1, 1'b0, imm_t'(50)),
            data_t'(50)
        );

        @(posedge clk); // Commit R1 = 50
        @(negedge clk);

        // MOVI R2, #75
        check_instruction(
            INSTRUCTION_BYTES,
            encode_instruction(ALU_PASS_B, reg_addr_t'(2), ZERO_REG, ZERO_REG,
                               1'b1, 1'b0, imm_t'(75)),
            data_t'(75)
        );

        @(posedge clk); // Commit R2 = 75
        @(negedge clk);

        // ADD R3, R1, R2
        check_instruction(
            2 * INSTRUCTION_BYTES,
            encode_instruction(ALU_ADD, reg_addr_t'(3), reg_addr_t'(1), reg_addr_t'(2),
                               1'b0, 1'b0, '0),
            data_t'(125)
        );

        @(posedge clk); // Commit R3 = 125

        // Stop before fetching beyond the program.
        @(negedge clk);
        run = 0;
        #1;
        assert (instruction === '0)
            else $fatal(1, "Unloaded instruction memory must read zero");

        $display("PASS: cpu_system_tb");
        $finish;

    end

    initial begin
        #1000;
        $fatal(1, "TIMEOUT");
    end

endmodule
