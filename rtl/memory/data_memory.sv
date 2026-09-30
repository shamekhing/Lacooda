`timescale 1ns/1ps

// ============================================================
// Local data memory — bus slave
//
// This is the first slave attached to the LACOODA CPU data bus.
// It preserves the Stage-7 memory semantics while speaking the new
// valid/ready request protocol.
//
// Addressing:
//   - CPU addresses are byte addresses.
//   - Each entry stores one DATA_WIDTH word.
//   - Valid accesses must be aligned to DATA_BYTES and inside DEPTH.
//
// Timing:
//   - This local memory is always able to complete a request immediately.
//   - Therefore bus_ready follows bus_valid combinationally.
//   - LOAD data is combinational.
//   - STORE commits on the rising edge of an accepted transaction.
//
// Invalid addresses still complete instead of deadlocking the CPU:
//   - invalid LOAD returns zero
//   - invalid STORE is ignored
//
// A later bus fabric or DDR controller may hold bus_ready low for any
// number of cycles; the CPU wrapper is now able to wait correctly.
// ============================================================

module data_memory #(
    parameter int DATA_WIDTH = cpu_pkg::DATA_WIDTH,
    parameter int DEPTH = cpu_pkg::DATA_MEMORY_DEPTH
) (
    input  logic                  clk,

    input  logic                  bus_valid,
    input  logic                  bus_write,
    input  cpu_pkg::data_t        address,
    input  logic [DATA_WIDTH-1:0] write_data,

    output logic                  bus_ready,
    output logic [DATA_WIDTH-1:0] read_data
);

    localparam int DATA_BYTES = DATA_WIDTH / 8;

    logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    logic address_valid;

    // Deterministic simulation/FPGA initialization.
    initial begin
        for (int i = 0; i < DEPTH; i++)
            memory[i] = '0;
    end

    // The local memory itself never inserts wait states. Keeping ready tied
    // to valid makes the completion condition explicit: valid && ready.
    assign bus_ready = bus_valid;

    // Alignment/range check used by both reads and writes.
    always_comb begin
        address_valid =
            (address % DATA_BYTES == 0) &&
            ((address / DATA_BYTES) < DEPTH);
    end

    // LOAD response. STORE and idle cycles return zero on read_data.
    always_comb begin
        read_data = '0;

        if (bus_valid && !bus_write && address_valid)
            read_data = memory[address / DATA_BYTES];
    end

    // STORE commits exactly once on an accepted write transaction.
    always_ff @(posedge clk) begin
        if (bus_valid && bus_ready && bus_write && address_valid)
            memory[address / DATA_BYTES] <= write_data;
    end

endmodule
