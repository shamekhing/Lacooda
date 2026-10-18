`timescale 1ns/1ps

// Owns the independent instruction ROM and local data BRAM.
// Both are RPU slaves and receive slave-local byte addresses.
// The CPU no longer connects directly to either memory.
module memory_subsystem (
    input logic clk,
    input logic rst,
    input  bus_pkg::bus_req_s rom_bus_req,
    output bus_pkg::bus_rsp_s rom_bus_rsp,
    input  bus_pkg::bus_req_s ram_bus_req,
    output bus_pkg::bus_rsp_s ram_bus_rsp
);
    instruction_rom u_instruction_rom (
        .clk (clk),
        .rst (rst),
        .cpu_instr_bus_req (rom_bus_req),
        .cpu_instr_bus_rsp (rom_bus_rsp)
    );

    data_ram u_data_ram (
        .clk     (clk),
        .rst     (rst),
        .ram_bus_req (ram_bus_req),
        .ram_bus_rsp (ram_bus_rsp)
    );
endmodule
