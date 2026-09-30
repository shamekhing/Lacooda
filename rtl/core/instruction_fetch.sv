module instruction_fetch (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,

    input  logic        redirect,
    input  cpu_pkg::data_t target,

    output cpu_pkg::data_t pc,
    output cpu_pkg::instruction_t instruction
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
