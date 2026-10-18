`timescale 1ns/1ps
`ifndef MEMORY_PKG_SV
`define MEMORY_PKG_SV

// ============================================================
// LACOODA memory package
//
// Central source of truth for memory and MMIO allocation sizes.
//
// This package owns capacities/sizes.
//
// It does NOT own:
//   - CPU/GPU internal register definitions
//   - bus protocol
//   - absolute SoC base addresses
// ============================================================

package memory_pkg;

    // ========================================================
    // Local memories
    // ========================================================

    localparam int INSTRUCTION_ROM_BYTES = 32 * 1024;
    localparam int DATA_RAM_BYTES         = 32 * 1024;

    // ========================================================
    // MMIO region sizes
    // ========================================================
    //
    // GPU receives 4 KiB of CPU-visible MMIO address space.
    //
    // This is NOT framebuffer memory.
    // It is the address space occupied by GPU registers.
    // ========================================================

    localparam int GPU_MMIO_BYTES = 4 * 1024;

    // ========================================================
    // External DDR3 window
    // ========================================================
    //
    // The SoC owns a 128 MiB CPU-visible DDR3 region. The
    // physical DDR3 device and controller may be larger; this
    // is the address window exposed through the DDR3 bridge.
    // ========================================================

    localparam int DDR3_BYTES = 128 * 1024 * 1024;

    // ========================================================
    // Memory depths
    // ========================================================

    localparam int INSTRUCTION_ROM_WORDS =
        INSTRUCTION_ROM_BYTES / cpu_pkg::WORD_BYTES;

    localparam int DATA_RAM_WORDS =
        DATA_RAM_BYTES / cpu_pkg::WORD_BYTES;

    // ========================================================
    // Initialization files
    // ========================================================

    localparam INSTRUCTION_ROM_INIT_FILE = "src/programs/boot_program.hex";
    localparam DATA_RAM_INIT_FILE = "src/programs/data_ram_init.hex";

    // ========================================================
    // Configuration validation
    // ========================================================

    function automatic bit validate_configuration();

        if (INSTRUCTION_ROM_BYTES <= 0)
            $fatal(
                1,
                "INSTRUCTION_ROM_BYTES must be positive"
            );

        if (DATA_RAM_BYTES <= 0)
            $fatal(
                1,
                "DATA_RAM_BYTES must be positive"
            );

        if (GPU_MMIO_BYTES <= 0)
            $fatal(
                1,
                "GPU_MMIO_BYTES must be positive"
            );

        if ((INSTRUCTION_ROM_BYTES % cpu_pkg::WORD_BYTES) != 0)
            $fatal(
                1,
                "INSTRUCTION_ROM_BYTES must be divisible by WORD_BYTES"
            );

        if ((DATA_RAM_BYTES % cpu_pkg::WORD_BYTES) != 0)
            $fatal(
                1,
                "DATA_RAM_BYTES must be divisible by WORD_BYTES"
            );

        if (INSTRUCTION_ROM_WORDS <= 0)
            $fatal(
                1,
                "INSTRUCTION_ROM_WORDS must be positive"
            );

        if (DATA_RAM_WORDS <= 0)
            $fatal(
                1,
                "DATA_RAM_WORDS must be positive"
            );

        return 1'b1;

    endfunction

endpackage

`endif
