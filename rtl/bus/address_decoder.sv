`timescale 1ns/1ps

// ============================================================
// LACOODA data-bus address decoder
//
// Pure combinational address classification. At the current system stage
// there is one mapped data-bus slave: local data memory. More regions can
// be added later without changing the CPU master interface.
// ============================================================

module address_decoder (
    input  cpu_pkg::data_t address,
    output logic data_memory_select
);

    always_comb begin
        data_memory_select =
            (address >= bus_pkg::DATA_MEMORY_BASE) &&
            (address <  bus_pkg::DATA_MEMORY_LIMIT);
    end

endmodule
