
module status_register (
    input logic clk,
    input logic rst,
    input logic write_enable,

    input  flags_pkg::flags_t flags_in,
    output flags_pkg::flags_t flags_out
);

    always_ff @(posedge clk or posedge rst) begin

        if (rst)
            flags_out <= '0;

        else if (write_enable)
            flags_out <= flags_in;

    end

endmodule
