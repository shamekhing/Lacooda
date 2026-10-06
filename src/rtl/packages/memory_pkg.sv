`timescale 1ns/1ps
`ifndef MEMORY_PKG_SV
`define MEMORY_PKG_SV

// ============================================================
// Memory package
//
// Single source of truth for local-memory configuration.
//
// Owns:
//
//   - instruction-memory capacity
//   - data-memory capacity
//   - memory word counts
//   - memory initialization files
//
// Does NOT own:
//
//   - CPU word width       -> cpu_pkg
//   - bus protocol         -> bus_pkg
//   - address map          -> currently bus_pkg
//
// Dependency:
//
//     cpu_pkg
//       ↓
//   memory_pkg
//
// Therefore memory_pkg may reference cpu_pkg, but cpu_pkg must
// never reference memory_pkg.
// ============================================================

package memory_pkg;


    // ========================================================
    // MEMORY CAPACITY
    // ========================================================
    //
    // Define physical/logical capacity in BYTES.
    //
    // This is preferable to defining the number of words
    // directly because the capacity then remains constant when
    // switching between 32-bit and 64-bit CPU configurations.
    //
    // Current allocation:
    //
    //     instruction memory = 32 KiB
    //     data memory        = 32 KiB
    // ========================================================

    localparam int INSTRUCTION_MEMORY_BYTES =
        32 * 1024;

    localparam int DATA_MEMORY_BYTES =
        32 * 1024;


    // ========================================================
    // MEMORY DEPTH
    // ========================================================
    //
    // Number of architectural words stored in each memory.
    //
    // 32-bit:
    //
    //     WORD_BYTES = 4
    //
    //     32768 / 4
    //       = 8192 words
    //
    // 64-bit:
    //
    //     WORD_BYTES = 8
    //
    //     32768 / 8
    //       = 4096 words
    //
    // Capacity remains 32 KiB in either configuration.
    // ========================================================

    localparam int INSTRUCTION_MEMORY_COUNT =
        INSTRUCTION_MEMORY_BYTES /
        cpu_pkg::WORD_BYTES;


    localparam int DATA_MEMORY_COUNT =
        DATA_MEMORY_BYTES /
        cpu_pkg::WORD_BYTES;


    // ========================================================
    // INSTRUCTION MEMORY IMAGE
    // ========================================================
    //
    // Program images are word-width dependent.
    //
    // Paths are relative to the repository root because the
    // existing simulation and Gowin flows run from there.
    // ========================================================

    localparam string PROGRAM_FILE =
        (cpu_pkg::WORD_WIDTH == 32)
            ? "src/programs/genesis_32.hex"
            : "src/programs/genesis_64.hex";


    // ========================================================
    // DATA MEMORY IMAGE
    // ========================================================
    //
    // Data memory uses a memory image rather than a huge:
    //
    //     for (...)
    //         mem[i] = '0;
    //
    // initialization loop.
    //
    // For zero-filled images:
    //
    // 32-bit:
    //
    //     yes 00000000 | head -n 8192 \
    //       > src/programs/data_memory_32.hex
    //
    // 64-bit:
    //
    //     yes 0000000000000000 | head -n 4096 \
    //       > src/programs/data_memory_64.hex
    //
    // The file provides initial contents only.
    // Data RAM remains writable at runtime.
    // ========================================================

    localparam string DATA_MEMORY_FILE =
        (cpu_pkg::WORD_WIDTH == 32)
            ? "src/programs/data_memory_32.hex"
            : "src/programs/data_memory_64.hex";


    // ========================================================
    // MEMORY CONFIGURATION VALIDATION
    // ========================================================
    //
    // Memory checks moved here from cpu_pkg because memory_pkg
    // now owns memory geometry.
    // ========================================================

    function automatic bit validate_configuration();


        // ----------------------------------------------------
        // Capacities must be positive.
        // ----------------------------------------------------

        if (INSTRUCTION_MEMORY_BYTES <= 0)
            $fatal(
                1,
                "INSTRUCTION_MEMORY_BYTES must be positive"
            );


        if (DATA_MEMORY_BYTES <= 0)
            $fatal(
                1,
                "DATA_MEMORY_BYTES must be positive"
            );


        // ----------------------------------------------------
        // Capacity must contain an exact number of CPU words.
        // ----------------------------------------------------

        if (
            (INSTRUCTION_MEMORY_BYTES %
             cpu_pkg::WORD_BYTES) != 0
        )
            $fatal(
                1,
                "INSTRUCTION_MEMORY_BYTES must be divisible by WORD_BYTES"
            );


        if (
            (DATA_MEMORY_BYTES %
             cpu_pkg::WORD_BYTES) != 0
        )
            $fatal(
                1,
                "DATA_MEMORY_BYTES must be divisible by WORD_BYTES"
            );


        // ----------------------------------------------------
        // Derived memory depths must be valid.
        // ----------------------------------------------------

        if (INSTRUCTION_MEMORY_COUNT <= 0)
            $fatal(
                1,
                "INSTRUCTION_MEMORY_COUNT must be positive"
            );


        if (DATA_MEMORY_COUNT <= 0)
            $fatal(
                1,
                "DATA_MEMORY_COUNT must be positive"
            );


        return 1'b1;

    endfunction

endpackage

`endif