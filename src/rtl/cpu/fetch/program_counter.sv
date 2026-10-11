`timescale 1ns/1ps

// Byte-addressed program counter with synchronous, active-high reset.
// Priority at each rising edge: reset, enabled redirect, enabled increment.
// When enable is low, the PC holds its value even if redirect is asserted.
// The increment skips the immediate word when the retiring instruction was
// followed by one.
module program_counter (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,

    input  logic        redirect,
    input  cpu_pkg::word_t target,
    input  logic        has_imm,

    output cpu_pkg::word_t pc
);

    always_ff @(posedge clk) begin
        if (rst) pc <= '0;
        else if (enable) begin
            pc <= redirect ? target : pc + cpu_pkg::word_t'((has_imm ? 2 : 1) * cpu_pkg::WORD_BYTES);
        end
    end

endmodule
