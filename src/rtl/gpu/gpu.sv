`timescale 1ns/1ps

// ============================================================
// LACOODA GPU — Stage 1
//
// Stage 1 establishes the GPU as a real SoC data-bus slave.
//
// Implemented:
//   - D-BUS request input
//   - D-BUS response output
//   - immediate transaction completion
//   - GPU-local addressing supplied by the interconnect
//
// Not implemented yet:
//   - GPU control/status registers
//   - commands
//   - rendering
//   - framebuffer
//   - palette
//   - display timing
//   - video output
//
// Stage 2 will add the first CPU-visible GPU registers behind
// this module.
//
// Stage-1 behavior:
//   READ  -> completes immediately and returns zero
//   WRITE -> completes immediately and is ignored
//
// This intentionally gives the GPU no fake functionality.
// ============================================================

module gpu (
    input logic clk,
    input logic rst,

    input  bus_pkg::bus_req_s slave_req,
    output bus_pkg::bus_rsp_s slave_rsp
);

    // --------------------------------------------------------
    // Stage 1 has no sequential GPU state.
    //
    // clk and rst are still part of the GPU boundary because
    // Stage 2 and later stages will contain sequential control
    // and rendering hardware.
    // --------------------------------------------------------

    // Suppress unused-input ambiguity in the source explanation:
    // clk and rst intentionally have no behavioral effect yet.

    // ========================================================
    // BUS RESPONSE
    // ========================================================
    //
    // The Stage-1 GPU never inserts a wait state.
    //
    // When:
    //
    //      slave_req.valid = 1
    //
    // we respond:
    //
    //      slave_rsp.ready = 1
    //
    // Therefore:
    //
    //      valid && ready
    //
    // completes the transaction immediately.
    //
    // There are no readable registers yet, so rdata is zero.
    // ========================================================

    always_comb begin
        slave_rsp = '0;
        if (slave_req.valid) begin
            slave_rsp.ready = 1'b1;
            slave_rsp.rdata = '0;
        end
    end

endmodule