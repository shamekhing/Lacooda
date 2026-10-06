`timescale 1ns/1ps
`ifndef GPU_PKG_SV
`define GPU_PKG_SV

// ============================================================
// LACOODA GPU package
//
// Single source of truth for GPU-wide architectural types.
//
// Stage 0 intentionally contains only definitions that belong to
// the GPU itself. Bus/MMIO addresses remain SoC concerns and belong
// in bus_pkg, while CPU architectural definitions remain in cpu_pkg.
//
// Later GPU stages may extend this package with:
//   - command encodings
//   - status definitions
//   - pixel formats
//   - coordinates
//   - palette definitions
//
// Do not place display timing, board pin assignments, framebuffer
// implementation details, or CPU definitions in this package.
// ============================================================

package gpu_pkg;

    // ------------------------------------------------------------
    // GPU operating state
    //
    // Stage 0 has no command processor or rendering engine yet.
    // These states establish the top-level GPU lifecycle without
    // pretending that rendering functionality already exists.
    // ------------------------------------------------------------

    typedef enum logic {
        GPU_IDLE = 1'b0,
        GPU_BUSY = 1'b1
    } gpu_state_e;

endpackage

`endif