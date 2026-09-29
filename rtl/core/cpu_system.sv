module cpu_system (
    input logic clk,
    input logic rst,
    input logic run,

    output logic [63:0] pc,
    output logic [63:0] instruction,

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

    assign fetch_enable = run && !rst;

    instruction_fetch u_fetch (
        .clk         (clk),
        .rst         (rst),
        .enable      (fetch_enable),

        .redirect    (1'b0),
        .target      (64'd0),

        .pc          (pc),
        .instruction (instruction)
    );

    cpu_core u_core (
        .clk                 (clk),
        .rst                 (rst),

        .instruction_enable  (fetch_enable),
        .instruction         (instruction),

        .carry_in            (1'b0),

        .instruction_valid   (instruction_valid),
        .illegal_instruction(illegal_instruction),
        .execution_valid    (execution_valid),

        .operand_a           (operand_a),
        .operand_b           (operand_b),
        .result              (result),

        .alu_flags           (alu_flags),
        .status_flags        (status_flags)
    );

endmodule