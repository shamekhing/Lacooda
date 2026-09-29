module instruction_fetch (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,

    input  logic        redirect,
    input  logic [63:0] target,

    output logic [63:0] pc,
    output logic [63:0] instruction
);

    program_counter u_pc (
        .clk      (clk),
        .rst      (rst),
        .enable   (enable),
        .redirect (redirect),
        .target   (target),
        .pc       (pc)
    );

    instruction_memory u_imem (
        .address     (pc),
        .instruction (instruction)
    );

endmodule