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

    localparam int INSTRUCTION_MEMORY_BYTES = 32 * 1024;
    localparam int CPU_MEMORY_BYTES         = 32 * 1024;

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
    // Memory depths
    // ========================================================

    localparam int INSTRUCTION_MEMORY_COUNT =
        INSTRUCTION_MEMORY_BYTES / cpu_pkg::WORD_BYTES;

    localparam int CPU_MEMORY_COUNT =
        CPU_MEMORY_BYTES / cpu_pkg::WORD_BYTES;

    // ========================================================
    // Initialization files
    // ========================================================

    localparam PROGRAM_FILE = "src/programs/genesis_32.hex";
    localparam CPU_MEMORY_FILE = "src/programs/data_memory_32.hex";

    // ========================================================
    // Configuration validation
    // ========================================================

    function automatic bit validate_configuration();

        if (INSTRUCTION_MEMORY_BYTES <= 0)
            $fatal(
                1,
                "INSTRUCTION_MEMORY_BYTES must be positive"
            );

        if (CPU_MEMORY_BYTES <= 0)
            $fatal(
                1,
                "CPU_MEMORY_BYTES must be positive"
            );

        if (GPU_MMIO_BYTES <= 0)
            $fatal(
                1,
                "GPU_MMIO_BYTES must be positive"
            );

        if ((INSTRUCTION_MEMORY_BYTES % cpu_pkg::WORD_BYTES) != 0)
            $fatal(
                1,
                "INSTRUCTION_MEMORY_BYTES must be divisible by WORD_BYTES"
            );

        if ((CPU_MEMORY_BYTES % cpu_pkg::WORD_BYTES) != 0)
            $fatal(
                1,
                "CPU_MEMORY_BYTES must be divisible by WORD_BYTES"
            );

        if (INSTRUCTION_MEMORY_COUNT <= 0)
            $fatal(
                1,
                "INSTRUCTION_MEMORY_COUNT must be positive"
            );

        if (CPU_MEMORY_COUNT <= 0)
            $fatal(
                1,
                "CPU_MEMORY_COUNT must be positive"
            );

        return 1'b1;

    endfunction

endpackage

`endif
