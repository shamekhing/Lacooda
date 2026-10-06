`timescale 1ns/1ps

module address_cpu_decoder (
    input  cpu_pkg::word_t addr,

    output logic data_memory_sel,
    output logic gpu_sel
);

    always_comb begin

        // ----------------------------------------------------
        // Data BRAM
        //
        // [0x00000000, 0x00008000)
        //
        // decimal:
        // [0, 32768)
        // ----------------------------------------------------

        data_memory_sel =
            (addr >= bus_pkg::DATA_MEMORY_BASE) &&
            (addr <  bus_pkg::DATA_MEMORY_LIMIT);

        // ----------------------------------------------------
        // GPU MMIO
        //
        // [0x10000000, 0x10001000)
        //
        // decimal:
        // [268435456, 268439552)
        // ----------------------------------------------------

        gpu_sel =
            (addr >= bus_pkg::GPU_BASE) &&
            (addr <  bus_pkg::GPU_LIMIT);

    end

endmodule