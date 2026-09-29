`timescale 1ns/1ps
module datapath #(
    parameter int DATA_WIDTH = cpu_pkg::DATA_WIDTH,
    parameter int REG_ADDR_WIDTH = cpu_pkg::REG_ADDR_WIDTH
) (
    input logic clk,
    input logic rst,

    // Register addresses
    input logic [REG_ADDR_WIDTH-1:0] rs1,
    input logic [REG_ADDR_WIDTH-1:0] rs2,
    input logic [REG_ADDR_WIDTH-1:0] rd,

    // ALU control
    input alu_pkg::opcode_t alu_op,
    input logic carry_in,

    // Immediate operand
    input logic [DATA_WIDTH-1:0] immediate,
    input logic use_immediate,

    // Write controls
    input logic register_write_enable,
    input logic flags_write_enable,

    // Datapath outputs
    output logic [DATA_WIDTH-1:0] operand_a,
    output logic [DATA_WIDTH-1:0] operand_b,
    output logic [DATA_WIDTH-1:0] result,
    output logic valid,

    // Flags
    output alu_pkg::flags_t alu_flags,
    output alu_pkg::flags_t status_flags
);

    logic [DATA_WIDTH-1:0] register_b;

    logic register_write;
    logic flags_write;

    // =========================================================
    // WRITE ENABLE CONTROL
    // =========================================================

    assign register_write =
        register_write_enable && valid && !rst;

    assign flags_write =
        flags_write_enable && valid && !rst;

    // =========================================================
    // REGISTER FILE
    // =========================================================

    register_file #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(REG_ADDR_WIDTH)
    ) u_register_file (
        .clk(clk),
        .rst(rst),

        .read_addr_a(rs1),
        .read_data_a(operand_a),

        .read_addr_b(rs2),
        .read_data_b(register_b),

        .write_enable(register_write),
        .write_addr(rd),
        .write_data(result)
    );

    // =========================================================
    // OPERAND B MULTIPLEXER
    // =========================================================

    assign operand_b =
        use_immediate ? immediate : register_b;

    // =========================================================
    // ALU
    // =========================================================

    alu #(
        .WIDTH(DATA_WIDTH)
    ) u_alu (
        .A(operand_a),
        .B(operand_b),

        .op(alu_op),
        .carry_in(carry_in),

        .result(result),
        .flags(alu_flags),
        .valid(valid)
    );

    // =========================================================
    // STATUS REGISTER
    // =========================================================

    status_register u_status (
        .clk(clk),
        .rst(rst),

        .write_enable(flags_write),
        .flags_in(alu_flags),
        .flags_out(status_flags)
    );

endmodule
