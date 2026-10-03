`timescale 1ns/1ps
// ============================================================
// Status register
//
// A dedicated 32-bit architectural STATUS register, independent of
// the global CPU word. Only the implemented ALU condition flags
// occupy [4:0] (DZ, V, C, N, Z); the reserved high bits always read
// as zero without storage.
//
// The stored flags clear asynchronously on reset and update on the
// rising clock edge only when write_enable is asserted.
// ============================================================

module status_register (
    input logic clk,
    input logic rst,
    input logic write_enable,

    input  cpu_pkg::flags_t  flags_in,
    output cpu_pkg::status_t status
);

    cpu_pkg::flags_t flags_reg;

    always_ff @(posedge clk or posedge rst) begin

        if (rst)
            flags_reg <= '0;

        else if (write_enable)
            flags_reg <= flags_in;

    end

    assign status = cpu_pkg::status_t'({flags_reg.DZ, flags_reg.V,
                                         flags_reg.C,  flags_reg.N,
                                         flags_reg.Z});

endmodule
