`timescale 1ns/1ps
// ============================================================
// Register file
//
// Two asynchronous read ports and one synchronous write port.
// Register 0 is architecturally hardwired to zero: writes to it
// are ignored and reads from it always return zero. Reset is
// asynchronous and clears every register.
// Every word is the global word (cpu_pkg::WORD_WIDTH).
// ============================================================

module cpu_register (
    input  logic             clk,
    input  logic             rst,
    input  cpu_pkg::reg_addr_t rs1_addr,
    output cpu_pkg::word_t      rs1_data,
    input  cpu_pkg::reg_addr_t rs2_addr,
    output cpu_pkg::word_t      rs2_data,
    input  logic             write_enable,
    input  cpu_pkg::reg_addr_t write_addr,
    input  cpu_pkg::word_t      write_data
);
    cpu_pkg::word_t registers [0:cpu_pkg::REG_FILE_COUNT-1];

    // R0 is architecturally hardwired to zero.
    assign rs1_data = (rs1_addr == '0) ? '0 : registers[rs1_addr];
    assign rs2_data = (rs2_addr == '0) ? '0 : registers[rs2_addr];

    integer idx;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (idx = 0; idx < cpu_pkg::REG_FILE_COUNT; idx = idx + 1)
                registers[idx] <= '0;
        end else if (write_enable && (write_addr != '0)) begin
            registers[write_addr] <= write_data;
        end
    end
endmodule
