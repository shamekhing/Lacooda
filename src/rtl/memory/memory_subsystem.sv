`timescale 1ns/1ps

// Owns the independent instruction ROM and local data BRAM. The data port
// accepts a local byte address from the SoC interconnect. GPU/TPU masters
// will require arbitration upstream when they are connected.
module memory_subsystem (
    input logic clk,
    input logic rst,
    input  bus_pkg::bus_req_s ibus_req,
    output bus_pkg::bus_rsp_s ibus_rsp,
    input  bus_pkg::bus_req_s data_ram_req,
    output bus_pkg::bus_rsp_s data_ram_rsp
);
    instruction_rom u_instruction_rom (
        .ibus_req (ibus_req),
        .ibus_rsp (ibus_rsp)
    );

    data_ram u_data_ram (
        .clk     (clk),
        .rst     (rst),
        .data_ram_req (data_ram_req),
        .data_ram_rsp (data_ram_rsp)
    );
endmodule
