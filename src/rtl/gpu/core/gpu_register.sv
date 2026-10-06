`timescale 1ns/1ps

// ============================================================
// LACOODA GPU register block
//
// Stage 2 architectural GPU state.
//
// Writable:
//   CONTROL
//   FRAMEBUFFER_BASE
//   FRAMEBUFFER_WIDTH
//   FRAMEBUFFER_HEIGHT
//   CLEAR_COLOR
//
// Read-only:
//   STATUS
//
// The actual rendering engine is not implemented yet.
// ============================================================

module gpu_register (
    input logic clk,
    input logic rst,

    input logic control_wen,

    input logic framebuffer_base_wen,
    input logic framebuffer_width_wen,
    input logic framebuffer_height_wen,

    input logic clear_color_wen,

    input cpu_pkg::word_t wdata,

    output cpu_pkg::word_t control,

    output gpu_pkg::gpu_status_s status,

    output cpu_pkg::word_t framebuffer_base,
    output cpu_pkg::word_t framebuffer_width,
    output cpu_pkg::word_t framebuffer_height,

    output cpu_pkg::word_t clear_color
);

    // ========================================================
    // Persistent configuration registers
    // ========================================================

    cpu_pkg::word_t control_reg;

    cpu_pkg::word_t framebuffer_base_reg;
    cpu_pkg::word_t framebuffer_width_reg;
    cpu_pkg::word_t framebuffer_height_reg;

    cpu_pkg::word_t clear_color_reg;

    // ========================================================
    // Internal GPU state
    // ========================================================
    //
    // Stage 2 contains no execution engine.
    //
    // Therefore the GPU remains idle.
    //
    // gpu_control will eventually own this state.
    // ========================================================

    gpu_pkg::gpu_state_e gpu_state;

    assign gpu_state =
        gpu_pkg::GPU_IDLE;

    // ========================================================
    // Persistent register writes
    // ========================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            control_reg <= '0;

            framebuffer_base_reg   <= '0;
            framebuffer_width_reg  <= '0;
            framebuffer_height_reg <= '0;

            clear_color_reg <= '0;

        end else begin

            if (control_wen)
                control_reg <= wdata;

            if (framebuffer_base_wen)
                framebuffer_base_reg <= wdata;

            if (framebuffer_width_wen)
                framebuffer_width_reg <= wdata;

            if (framebuffer_height_wen)
                framebuffer_height_reg <= wdata;

            if (clear_color_wen)
                clear_color_reg <= wdata;

        end

    end

    // ========================================================
    // Register outputs
    // ========================================================

    assign control =
        control_reg;

    assign framebuffer_base =
        framebuffer_base_reg;

    assign framebuffer_width =
        framebuffer_width_reg;

    assign framebuffer_height =
        framebuffer_height_reg;

    assign clear_color =
        clear_color_reg;

    // ========================================================
    // STATUS construction
    // ========================================================
    //
    // STATUS is not stored independently.
    //
    // It is constructed from the current GPU state.
    // ========================================================

    always_comb begin

        status = '0;

        // CONTROL bit 0 enables the GPU.
        status.enabled =
            control_reg[0];

        status.idle =
            (gpu_state == gpu_pkg::GPU_IDLE);

        status.busy =
            (gpu_state == gpu_pkg::GPU_BUSY);

        status.error =
            (gpu_state == gpu_pkg::GPU_ERROR);

        // Later stages will drive these.
        status.command_done =
            1'b0;

        status.framebuffer_valid =
            1'b0;

        status.display_active =
            1'b0;

    end

endmodule