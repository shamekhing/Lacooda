`timescale 1ns/1ps

module cpu_system_tb;

    logic clk = 0;
    logic rst = 1;
    logic run = 0;

    logic [63:0] pc;
    logic [63:0] instruction;

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
        input logic [63:0] expected_pc,
        input logic [63:0] expected_instruction,
        input logic [63:0] expected_result
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

        assert (pc === 64'd0)
            else $fatal(1, "Reset failed");

        // Start program
        @(negedge clk);
        rst = 0;
        run = 1;

        // MOVI R1, #50
        check_instruction(
            64'd0,
            64'h0160100000000032,
            64'd50
        );

        @(posedge clk); // Commit R1 = 50
        @(negedge clk);

        // MOVI R2, #75
        check_instruction(
            64'd8,
            64'h016020000000004B,
            64'd75
        );

        @(posedge clk); // Commit R2 = 75
        @(negedge clk);

        // ADD R3, R1, R2
        check_instruction(
            64'd16,
            64'h0000304200000000,
            64'd125
        );

        @(posedge clk); // Commit R3 = 125

        // Stop before fetching beyond the program.
        @(negedge clk);
        run = 0;

        $display("PASS: cpu_system_tb");
        $finish;

    end

    initial begin
        #1000;
        $fatal(1, "TIMEOUT");
    end

endmodule