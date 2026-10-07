`timescale 1ns/1ps

// ============================================================
// LACOODA GPU
//
// GPU subsystem boundary.
//
// Current implementation:
//
//                  gpu
//                   │
//                   ▼
//             gpu_register
//
// At this stage the GPU contains only its CPU-visible MMIO
// register interface.
//
// Future GPU components will be added behind this boundary
// without changing the SoC-facing bus interface.
// ============================================================

module gpu (
    input logic clk,
    input logic rst,

    input  bus_pkg::bus_req_s ibus_req,
    output bus_pkg::bus_rsp_s ibus_rsp
);


    // ========================================================
    // GPU CONFIGURATION
    // ========================================================

    gpu_pkg::gpu_config_s gpu_cfg;


    // ========================================================
    // GPU STATUS
    // ========================================================
    //
    // There is no GPU execution core yet.
    //
    // Therefore:
    //
    //     idle  = 1
    //     busy  = 0
    //     error = 0
    //
    // enabled reflects CONTROL[0].
    //
    // Once gpu_core exists, it will provide the runtime status
    // fields instead.
    // ========================================================

    gpu_pkg::gpu_status_s status;


    always_comb begin

        status = '0;

        status.enabled =
            gpu_cfg.control[0];

        status.idle =
            1'b1;

    end


    // ========================================================
    // GPU REGISTER BLOCK
    // ========================================================

    gpu_register u_gpu_register (
        .clk       (clk),
        .rst       (rst),

        .ibus_req (ibus_req),
        .ibus_rsp (ibus_rsp),

        .status    (status),
        .gpu_cfg    (gpu_cfg)
    );


endmodule