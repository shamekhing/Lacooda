`timescale 1ns/1ps

// Owns the independent instruction ROM and local data BRAM. The data port
// accepts a local byte address from the SoC interconnect. GPU/TPU masters
// will require arbitration upstream when they are connected.
module memory_subsystem (
    input logic clk,
    input logic rst,
    input  bus_pkg::bus_req_s ibus_req,
    output bus_pkg::bus_rsp_s ibus_rsp,
    input  bus_pkg::bus_req_s mem_req,
    output bus_pkg::bus_rsp_s mem_rsp
);
    instruction_memory u_instruction_memory (
        .ibus_req (ibus_req),
        .ibus_rsp (ibus_rsp)
    );

    data_memory u_data_memory (
        .clk     (clk),
        .rst     (rst),
        .mem_req (mem_req),
        .mem_rsp (mem_rsp)
    );
endmodule
