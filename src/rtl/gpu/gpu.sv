`timescale 1ns/1ps

// ============================================================
// LACOODA GPU
//
// Top-level boundary of the LACOODA graphics processor.
//
// Stage 0 establishes the GPU as an independent hardware block.
// It does not yet implement:
//   - CPU/MMIO access
//   - commands
//   - rendering
//   - framebuffer access
//   - palette lookup
//   - video timing
//   - physical video output
//
// Those capabilities are added behind this boundary in later stages.
//
// Keeping the GPU behind a stable top-level module prevents the SoC
// from depending directly on future internal GPU implementation
// details.
// ============================================================

module gpu (
    input logic clk,
    input logic reset_n
);

    import gpu_pkg::*;

    // ------------------------------------------------------------
    // GPU state
    //
    // There is currently no engine capable of starting work, so the
    // GPU remains idle after reset.
    //
    // The state register is introduced here because the GPU top level
    // will eventually coordinate the register interface and execution
    // engines. Stage 0 intentionally provides no transition to BUSY.
    // ------------------------------------------------------------

    gpu_state_e state_q;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            state_q <= GPU_IDLE;
        end else begin
            state_q <= GPU_IDLE;
        end
    end

endmodule