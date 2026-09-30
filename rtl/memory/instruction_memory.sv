`timescale 1ns/1ps

// ============================================================
// Local instruction memory — instruction-bus slave
//
// This ROM is outside the CPU boundary. It implements the same valid/ready
// protocol as other external CPU resources while retaining the original
// combinational ROM behavior.
//
// Addressing:
//   - addresses are byte addresses
//   - one entry stores one complete instruction
//   - misaligned/out-of-range reads complete and return zero
//
// Timing:
//   - this local ROM inserts no wait states
//   - bus_ready follows bus_valid
//   - read_data is combinational
// ============================================================

module instruction_memory #(
    parameter int DEPTH = cpu_pkg::INSTRUCTION_MEMORY_DEPTH,
    parameter INIT_FILE = cpu_pkg::INSTRUCTION_MEMORY_INIT_FILE
) (
    input  logic                  bus_valid,
    input  cpu_pkg::data_t        address,
    output logic                  bus_ready,
    output cpu_pkg::instruction_t read_data
);

    cpu_pkg::instruction_t memory [0:DEPTH-1];
    logic address_valid;

    initial begin
        for (int i = 0; i < DEPTH; i++)
            memory[i] = '0;

        $readmemh(INIT_FILE, memory);
    end

    assign bus_ready = bus_valid;

    always_comb begin
        address_valid =
            (address % cpu_pkg::INSTRUCTION_BYTES == 0) &&
            ((address / cpu_pkg::INSTRUCTION_BYTES) < DEPTH);
    end

    always_comb begin
        read_data = '0;

        if (bus_valid && address_valid)
            read_data = memory[address / cpu_pkg::INSTRUCTION_BYTES];
    end

endmodule
