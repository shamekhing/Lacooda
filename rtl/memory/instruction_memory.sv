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
//   - slave_ready follows slave_valid
//   - slave_read_data is combinational
// ============================================================

module instruction_memory #(
    // Defaults come from the instruction-memory parameter group.
    parameter int INSTRUCTION_MEMORY_WIDTH = cpu_pkg::INSTRUCTION_MEMORY_WIDTH,
    parameter int INSTRUCTION_MEMORY_COUNT = cpu_pkg::INSTRUCTION_MEMORY_COUNT,
    parameter INSTRUCTION_MEMORY_INIT_FILE = cpu_pkg::INSTRUCTION_MEMORY_INIT_FILE
) (
    input  logic                  slave_valid,
    input  cpu_pkg::reg_t        slave_address,
    output logic                  slave_ready,
    output cpu_pkg::instruction_t slave_read_data
);

    logic [INSTRUCTION_MEMORY_WIDTH-1:0] memory [0:INSTRUCTION_MEMORY_COUNT-1];
    logic address_valid;

    initial begin
        for (int i = 0; i < INSTRUCTION_MEMORY_COUNT; i++)
            memory[i] = '0;

        $readmemh(INSTRUCTION_MEMORY_INIT_FILE, memory);
    end

    assign slave_ready = slave_valid;

    always_comb begin
        address_valid =
            (slave_address % cpu_pkg::INSTRUCTION_MEMORY_BYTES == 0) &&
            ((slave_address / cpu_pkg::INSTRUCTION_MEMORY_BYTES) < INSTRUCTION_MEMORY_COUNT);
    end

    always_comb begin
        slave_read_data = '0;

        if (slave_valid && address_valid)
            slave_read_data = memory[slave_address / cpu_pkg::INSTRUCTION_MEMORY_BYTES];
    end

endmodule
