`timescale 1ns/1ps
// ============================================================
// Register file
//
// Two asynchronous read ports and one synchronous write port.
// Register 0 is architecturally hardwired to zero: writes to it
// are ignored and reads from it always return zero. Reset is
// asynchronous and clears every register.
// ============================================================

module register_file #(
    parameter int DATA_WIDTH = cpu_pkg::DATA_WIDTH,
    parameter int ADDR_WIDTH = cpu_pkg::REG_ADDR_WIDTH,
    parameter int REG_COUNT  = (1 << ADDR_WIDTH)
) (
    input  logic                  clk,
    input  logic                  rst,
    input  logic [ADDR_WIDTH-1:0] read_addr_a,
    output logic [DATA_WIDTH-1:0] read_data_a,
    input  logic [ADDR_WIDTH-1:0] read_addr_b,
    output logic [DATA_WIDTH-1:0] read_data_b,
    input  logic                  write_enable,
    input  logic [ADDR_WIDTH-1:0] write_addr,
    input  logic [DATA_WIDTH-1:0] write_data
);
    logic [DATA_WIDTH-1:0] registers [0:REG_COUNT-1];

    // R0 is architecturally hardwired to zero.
    assign read_data_a = (read_addr_a == '0) ? '0 : registers[read_addr_a];
    assign read_data_b = (read_addr_b == '0) ? '0 : registers[read_addr_b];

    integer i;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < REG_COUNT; i = i + 1)
                registers[i] <= '0;
        end else if (write_enable && (write_addr != '0)) begin
            registers[write_addr] <= write_data;
        end
    end
endmodule