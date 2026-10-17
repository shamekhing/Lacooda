`timescale 1ns/1ps

// Owns the independent instruction ROM and local data BRAM. The data port
// accepts a local byte address from the SoC interconnect. GPU/TPU masters
// will require arbitration upstream when they are connected.
module memory_subsystem (
    input logic clk,
    input logic rst,
    input  bus_pkg::bus_req_s cpu_instr_bus_req,
    output bus_pkg::bus_rsp_s cpu_instr_bus_rsp,
    input  bus_pkg::bus_req_s ram_bus_req,
    output bus_pkg::bus_rsp_s ram_bus_rsp
);
    instruction_rom u_instruction_rom (
        .cpu_instr_bus_req (cpu_instr_bus_req),
        .cpu_instr_bus_rsp (cpu_instr_bus_rsp)
    );

    data_ram u_data_ram (
        .clk     (clk),
        .rst     (rst),
        .ram_bus_req (ram_bus_req),
        .ram_bus_rsp (ram_bus_rsp)
    );
endmodule
