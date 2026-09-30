`timescale 1ns/1ps

// ============================================================
// LACOODA CPU system — Stage 6
//
// Connects instruction fetch to cpu_core and closes the control-flow
// feedback path:
//
//   PC -> instruction memory -> CPU -> branch decision -> PC
//
// When no branch is taken, program_counter advances by one 64-bit
// instruction (INSTRUCTION_BYTES). When redirect is asserted, the PC
// loads redirect_target instead.
// ============================================================

module cpu_system (
    input logic clk,
    input logic rst,
    input logic run,

    output cpu_pkg::data_t pc,
    output cpu_pkg::instruction_t instruction,

    output logic execution_valid,
    output logic illegal_instruction,

    output cpu_pkg::data_t result
);

    logic instruction_valid;
    logic fetch_enable;

    cpu_pkg::data_t operand_a;
    cpu_pkg::data_t operand_b;

    alu_pkg::flags_t alu_flags;
    alu_pkg::flags_t status_flags;

    // Stage 6 feedback from cpu_core to instruction_fetch/PC.
    logic redirect;
    cpu_pkg::data_t redirect_target;

    // run=0 freezes the PC and prevents instruction execution.
    assign fetch_enable = run && !rst;

    instruction_fetch u_fetch (
        .clk         (clk),
        .rst         (rst),
        .enable      (fetch_enable),

        // Stage 5 tied these signals to zero. Stage 6 closes the loop.
        .redirect    (redirect),
        .target      (redirect_target),

        .pc          (pc),
        .instruction (instruction)
    );

    cpu_core u_core (
        .clk                 (clk),
        .rst                 (rst),

        .instruction_enable  (fetch_enable),
        .instruction         (instruction),

        // ADC/SBC receive a fixed carry input here, not the saved status C flag.
        .carry_in            (1'b0),

        .instruction_valid   (instruction_valid),
        .illegal_instruction (illegal_instruction),
        .execution_valid     (execution_valid),

        .redirect            (redirect),
        .redirect_target     (redirect_target),

        .operand_a           (operand_a),
        .operand_b           (operand_b),
        .result              (result),

        .alu_flags           (alu_flags),
        .status_flags        (status_flags)
    );

endmodule
