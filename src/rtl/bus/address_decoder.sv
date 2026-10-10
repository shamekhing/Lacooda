`timescale 1ns/1ps

module address_decoder (
    input  cpu_pkg::word_t addr,

    output logic cpu_memory_sel,
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

        cpu_memory_sel = (addr >= bus_pkg::CPU_MEMORY_BASE) && (addr <  bus_pkg::CPU_MEMORY_LIMIT);

        // ----------------------------------------------------
        // GPU MMIO
        //
        // [0x10000000, 0x10001000)
        //
        // decimal:
        // [268435456, 268439552)
        // ----------------------------------------------------

        gpu_sel = (addr >= bus_pkg::GPU_BASE) && (addr <  bus_pkg::GPU_LIMIT);

    end

endmodule