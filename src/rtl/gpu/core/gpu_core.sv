`timescale 1ns/1ps

// ============================================================
// LACOODA GPU core
//
// Central GPU control/state unit.
//
// Current responsibilities:
//
//   - consume CPU-written GPU configuration
//   - decode CONTROL
//   - validate framebuffer configuration
//   - generate architectural GPU status
//
// Rendering hardware is intentionally NOT implemented here yet.
//
// Future engines will connect behind this module.
// ============================================================

module gpu_core (
    input logic clk,
    input logic rst,

    input  gpu_pkg::gpu_config_s gpu_cfg,
    output gpu_pkg::gpu_status_s status
);


    // ========================================================
    // CONTROL REGISTER
    // ========================================================
    //
    // CONTROL[0] : GPU enable
    //
    // Remaining bits are reserved for now.
    // ========================================================

    logic enabled;

    assign enabled =
        gpu_cfg.control[0];


    // ========================================================
    // FRAMEBUFFER VALIDATION
    // ========================================================

    logic framebuffer_valid;

    always_comb begin

        framebuffer_valid =
            (gpu_cfg.framebuffer_width  != '0) &&
            (gpu_cfg.framebuffer_height != '0);

    end


    // ========================================================
    // GPU EXECUTION STATE
    // ========================================================
    //
    // There is no rendering engine yet.
    //
    // Therefore an enabled GPU with valid configuration remains
    // idle.
    //
    // These signals become real sequential execution state when
    // the command processor/raster engine is introduced.
    // ========================================================

    logic busy;
    logic error;
    logic command_done;
    logic display_active;

    assign busy =
        1'b0;

    assign error =
        1'b0;

    assign command_done =
        1'b0;

    assign display_active =
        1'b0;


    // ========================================================
    // STATUS
    // ========================================================

    always_comb begin

        status = '0;

        status.enabled =
            enabled;

        status.idle =
            ~busy;

        status.busy =
            busy;

        status.error =
            error;

        status.command_done =
            command_done;

        status.framebuffer_valid =
            framebuffer_valid;

        status.display_active =
            display_active;

    end


    // ========================================================
    // RESERVED SEQUENTIAL CORE
    // ========================================================
    //
    // clk/rst are intentionally present now because gpu_core
    // will own GPU execution state.
    //
    // Keeping the interface stable prevents us from changing
    // the subsystem hierarchy when execution hardware is added.
    // ========================================================

    always_ff @(posedge clk or posedge rst) begin

        if (rst) begin

            // No persistent execution state yet.

        end else begin

            // Future GPU state transitions.

        end

    end

endmodule