`timescale 1ns/1ps

// ============================================================
// LACOODA data-bus addr decoder
//
// Pure combinational addr classification. At the current system stage
// there is one mapped data-bus slave: local data memory. More regions can
// be added later without changing the CPU master interface.
// ============================================================

module address_decoder (
    input  cpu_pkg::word_t addr,
    output logic slave_sel
);

    always_comb begin
        slave_sel =
            (addr >= bus_pkg::DATA_MEMORY_BASE) &&
            (addr <  bus_pkg::DATA_MEMORY_LIMIT);
    end

endmodule
