`timescale 1ns/1ps
module status_register (
    input logic clk,
    input logic rst,
    input logic write_enable,

    input  alu_pkg::flags_t flags_in,
    output alu_pkg::flags_t flags_out
);

    always_ff @(posedge clk or posedge rst) begin

        if (rst)
            flags_out <= '0;

        else if (write_enable)
            flags_out <= flags_in;

    end

endmodule
