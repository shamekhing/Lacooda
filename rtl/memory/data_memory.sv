`timescale 1ns/1ps

// ============================================================
// Stage 7 data memory
//
// Simple fixed-latency local memory used to establish LOAD/STORE
// semantics before the later valid/ready bus stage.
//
// Addressing:
//   - CPU addresses are byte addresses.
//   - Each memory entry stores one DATA_WIDTH word.
//   - Accesses must be aligned to DATA_BYTES.
//
// Timing:
//   - reads are combinational
//   - writes commit on the rising clock edge
//
// Misaligned or out-of-range reads return zero. Misaligned or
// out-of-range writes are ignored. Stage 7 does not yet implement
// architectural memory-fault exceptions.
// ============================================================

module data_memory #(
    parameter int DATA_WIDTH = cpu_pkg::DATA_WIDTH,
    parameter int DEPTH = cpu_pkg::DATA_MEMORY_DEPTH
) (
    input  logic                  clk,
    input  logic                  read_enable,
    input  logic                  write_enable,
    input  cpu_pkg::data_t        address,
    input  logic [DATA_WIDTH-1:0] write_data,
    output logic [DATA_WIDTH-1:0] read_data
);

    localparam int DATA_BYTES = DATA_WIDTH / 8;

    logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];

    // Deterministic simulation/FPGA initialization for the Stage-7 RAM.
    initial begin
        for (int i = 0; i < DEPTH; i++)
            memory[i] = '0;
    end

    // Combinational read. The division is by a compile-time constant and
    // converts the CPU's byte address into a DATA_WIDTH-word index.
    always_comb begin
        read_data = '0;

        if (read_enable &&
            (address % DATA_BYTES == 0) &&
            ((address / DATA_BYTES) < DEPTH)) begin
            read_data = memory[address / DATA_BYTES];
        end
    end

    // Synchronous write.
    always_ff @(posedge clk) begin
        if (write_enable &&
            (address % DATA_BYTES == 0) &&
            ((address / DATA_BYTES) < DEPTH)) begin
            memory[address / DATA_BYTES] <= write_data;
        end
    end

endmodule
