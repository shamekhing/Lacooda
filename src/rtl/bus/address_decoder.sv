`timescale 1ns/1ps

// ============================================================
// LACOODA data-bus address decoder
//
// Pure combinational address classification.
//
// The decoder does not move data and does not perform bus
// transactions. Its only job is to determine which data-bus
// slave owns the CPU-visible address.
//
// Stage 1 slaves:
//   - local data memory
//   - GPU MMIO
//
// Address ranges are defined centrally in bus_pkg.
// ============================================================

module address_cpu_decoder (
    input  cpu_pkg::word_t addr,

    output logic data_memory_sel,
    output logic gpu_sel
);

    always_comb begin

        // ----------------------------------------------------
        // Local data memory
        //
        // Half-open range:
        //
        //   DATA_MEMORY_BASE <= addr < DATA_MEMORY_LIMIT
        // ----------------------------------------------------

        data_memory_sel =
            (addr >= bus_pkg::DATA_MEMORY_BASE) &&
            (addr <  bus_pkg::DATA_MEMORY_LIMIT);

        // ----------------------------------------------------
        // GPU MMIO
        //
        // Half-open range:
        //
        //   GPU_BASE <= addr < GPU_LIMIT
        // ----------------------------------------------------

        gpu_sel =
            (addr >= bus_pkg::GPU_BASE) &&
            (addr <  bus_pkg::GPU_LIMIT);

    end

endmodule