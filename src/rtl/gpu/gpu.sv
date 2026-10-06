`timescale 1ns/1ps

// ============================================================
// LACOODA GPU
//
// Stage 1:
//   memory-mapped D-BUS endpoint only.
//
// CPU-visible global range:
//
//   decimal:
//     268435456 .. 268439551
//
//   hexadecimal:
//     0x10000000 .. 0x10000FFF
//
// The interconnect subtracts GPU_BASE before the request
// reaches this module.
//
// Therefore this module sees local addresses:
//
//   decimal:
//     0 .. 4095
//
//   hexadecimal:
//     0x00000000 .. 0x00000FFF
//
// No actual GPU registers are implemented in Stage 1.
// ============================================================

module gpu (
    input logic clk,
    input logic rst,

    input  bus_pkg::bus_req_s slave_req,
    output bus_pkg::bus_rsp_s slave_rsp
);

    // Stage 1 contains no sequential GPU state yet.
    //
    // clk and rst are intentionally present because this is
    // the permanent GPU subsystem boundary.

    always_comb begin

        slave_rsp = '0;

        if (slave_req.valid) begin

            // No Stage-1 wait states.
            slave_rsp.ready = 1'b1;

            // No readable registers yet.
            slave_rsp.rdata = '0;

            // Writes are intentionally ignored until the
            // Stage-2 register block exists.
        end

    end

endmodule