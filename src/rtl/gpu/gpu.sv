`timescale 1ns/1ps

// ============================================================
// LACOODA GPU
//
// Stage 2 MMIO register block.
//
// Current structure:
//
//                       gpu
//                        |
//             +----------+----------+
//             |                     |
//        gpu_decoder            gpu_register
//             |                     |
//             +----------+----------+
//                        |
//                  MMIO response
//
// No rendering datapath exists yet.
// ============================================================

module gpu (
    input logic clk,
    input logic rst,

    input  bus_pkg::bus_req_s slave_req,
    output bus_pkg::bus_rsp_s slave_rsp
);

    // ========================================================
    // Decoder signals
    // ========================================================

    logic id_sel;
    logic control_sel;
    logic status_sel;

    logic framebuffer_base_sel;
    logic framebuffer_width_sel;
    logic framebuffer_height_sel;

    logic clear_color_sel;

    logic control_wen;

    logic framebuffer_base_wen;
    logic framebuffer_width_wen;
    logic framebuffer_height_wen;

    logic clear_color_wen;

    // ========================================================
    // GPU architectural state
    // ========================================================

    cpu_pkg::word_t control;

    gpu_pkg::gpu_status_s status;

    cpu_pkg::word_t framebuffer_base;
    cpu_pkg::word_t framebuffer_width;
    cpu_pkg::word_t framebuffer_height;

    cpu_pkg::word_t clear_color;

    // ========================================================
    // Decoder
    // ========================================================

    gpu_decoder u_gpu_decoder (
        .slave_req              (slave_req),

        .id_sel                 (id_sel),
        .control_sel            (control_sel),
        .status_sel             (status_sel),

        .framebuffer_base_sel   (framebuffer_base_sel),
        .framebuffer_width_sel  (framebuffer_width_sel),
        .framebuffer_height_sel (framebuffer_height_sel),

        .clear_color_sel        (clear_color_sel),

        .control_wen            (control_wen),

        .framebuffer_base_wen   (framebuffer_base_wen),
        .framebuffer_width_wen  (framebuffer_width_wen),
        .framebuffer_height_wen (framebuffer_height_wen),

        .clear_color_wen        (clear_color_wen)
    );

    // ========================================================
    // Register block
    // ========================================================

    gpu_register u_gpu_register (
        .clk                    (clk),
        .rst                    (rst),

        .control_wen            (control_wen),

        .framebuffer_base_wen   (framebuffer_base_wen),
        .framebuffer_width_wen  (framebuffer_width_wen),
        .framebuffer_height_wen (framebuffer_height_wen),

        .clear_color_wen        (clear_color_wen),

        .wdata                  (slave_req.wdata),

        .control                (control),
        .status                 (status),

        .framebuffer_base       (framebuffer_base),
        .framebuffer_width      (framebuffer_width),
        .framebuffer_height     (framebuffer_height),

        .clear_color            (clear_color)
    );

    // ========================================================
    // MMIO response
    // ========================================================
    //
    // Stage 2 has no GPU wait states.
    //
    // Every valid request completes immediately.
    //
    // Reserved addresses read as zero.
    // ========================================================

    always_comb begin

        slave_rsp = '0;

        if (slave_req.valid) begin

            slave_rsp.ready = 1'b1;

            if (slave_req.op == bus_pkg::BUS_READ) begin

                if (id_sel)
                    slave_rsp.rdata =
                        gpu_pkg::GPU_ID_VALUE;

                else if (control_sel)
                    slave_rsp.rdata =
                        control;

                else if (status_sel)
                    slave_rsp.rdata =
                        cpu_pkg::word_t'(status);

                else if (framebuffer_base_sel)
                    slave_rsp.rdata =
                        framebuffer_base;

                else if (framebuffer_width_sel)
                    slave_rsp.rdata =
                        framebuffer_width;

                else if (framebuffer_height_sel)
                    slave_rsp.rdata =
                        framebuffer_height;

                else if (clear_color_sel)
                    slave_rsp.rdata =
                        clear_color;

                else
                    slave_rsp.rdata =
                        '0;

            end

        end

    end

endmodule