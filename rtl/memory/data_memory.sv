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
//   - Each entry stores one DATA_MEMORY_WIDTH word.
//   - Valid accesses must be aligned to the data word and inside DATA_MEMORY_COUNT.
//
// Timing:
//   - This local memory is always able to complete a request immediately.
//   - Therefore slave_ready follows slave_valid combinationally.
//   - LOAD data is combinational.
//   - STORE commits on the rising edge of an accepted transaction.
//
// Invalid addresses still complete instead of deadlocking the CPU:
//   - invalid LOAD returns zero
//   - invalid STORE is ignored
//
// A later bus fabric or DDR controller may hold slave_ready low for any
// number of cycles; the CPU wrapper is now able to wait correctly.
// ============================================================

module data_memory #(
    // Defaults come from the data-memory parameter group.
    parameter int DATA_MEMORY_WIDTH = cpu_pkg::DATA_MEMORY_WIDTH,
    parameter int DATA_MEMORY_COUNT = cpu_pkg::DATA_MEMORY_COUNT
) (
    input  logic                      clk,

    input  logic                      slave_valid,
    input  logic                      slave_write,
    input  cpu_pkg::reg_t             slave_address,
    input  cpu_pkg::data_memory_t     slave_write_data,

    output logic                      slave_ready,
    output cpu_pkg::data_memory_t     slave_read_data
);

    logic [DATA_MEMORY_WIDTH-1:0] memory [0:DATA_MEMORY_COUNT-1];
    logic address_valid;

    // Deterministic simulation/FPGA initialization.
    initial begin
        for (int i = 0; i < DATA_MEMORY_COUNT; i++)
            memory[i] = '0;
    end

    // The local memory itself never inserts wait states. Keeping ready tied
    // to valid makes the completion condition explicit: valid && ready.
    assign slave_ready = slave_valid;

    // Alignment/range check used by both reads and writes.
    always_comb begin
        address_valid =
            (slave_address % cpu_pkg::DATA_MEMORY_BYTES == 0) &&
            ((slave_address / cpu_pkg::DATA_MEMORY_BYTES) < DATA_MEMORY_COUNT);
    end

    // LOAD response. STORE and idle cycles return zero on slave_read_data.
    always_comb begin
        slave_read_data = '0;

        if (slave_valid && !slave_write && address_valid)
            slave_read_data = memory[slave_address / cpu_pkg::DATA_MEMORY_BYTES];
    end

    // STORE commits exactly once on an accepted write transaction.
    always_ff @(posedge clk) begin
        if (slave_valid && slave_ready && slave_write && address_valid)
            memory[slave_address / cpu_pkg::DATA_MEMORY_BYTES] <= slave_write_data;
    end

endmodule
