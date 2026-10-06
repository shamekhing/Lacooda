`timescale 1ns/1ps

// ============================================================
// LACOODA GPU MMIO decoder
//
// Converts a GPU-local bus request into register selects and
// write enables.
//
// bus_interconnect has already determined that the request
// belongs to the GPU.
//
// The incoming bus address is converted to gpu_addr_t before
// register decoding.
// ============================================================

module gpu_decoder (
    input bus_pkg::bus_req_s slave_req,

    output logic id_sel,
    output logic control_sel,
    output logic status_sel,

    output logic framebuffer_base_sel,
    output logic framebuffer_width_sel,
    output logic framebuffer_height_sel,

    output logic clear_color_sel,

    output logic control_wen,

    output logic framebuffer_base_wen,
    output logic framebuffer_width_wen,
    output logic framebuffer_height_wen,

    output logic clear_color_wen
);

    // ========================================================
    // GPU-local address
    // ========================================================

    gpu_pkg::gpu_addr_t gpu_addr;

    assign gpu_addr =
        gpu_pkg::gpu_addr_t'(slave_req.addr);

    // ========================================================
    // Register selection
    // ========================================================

    always_comb begin

        id_sel                 = 1'b0;
        control_sel            = 1'b0;
        status_sel             = 1'b0;

        framebuffer_base_sel   = 1'b0;
        framebuffer_width_sel  = 1'b0;
        framebuffer_height_sel = 1'b0;

        clear_color_sel        = 1'b0;

        if (slave_req.valid) begin

            case (gpu_addr)

                gpu_pkg::GPU_REG_ID:
                    id_sel = 1'b1;

                gpu_pkg::GPU_REG_CONTROL:
                    control_sel = 1'b1;

                gpu_pkg::GPU_REG_STATUS:
                    status_sel = 1'b1;

                gpu_pkg::GPU_REG_FRAMEBUFFER_BASE:
                    framebuffer_base_sel = 1'b1;

                gpu_pkg::GPU_REG_FRAMEBUFFER_WIDTH:
                    framebuffer_width_sel = 1'b1;

                gpu_pkg::GPU_REG_FRAMEBUFFER_HEIGHT:
                    framebuffer_height_sel = 1'b1;

                gpu_pkg::GPU_REG_CLEAR_COLOR:
                    clear_color_sel = 1'b1;

                default: begin
                    // Reserved/unimplemented register.
                end

            endcase

        end

    end

    // ========================================================
    // Write enables
    // ========================================================
    //
    // ID and STATUS are read-only.
    // ========================================================

    always_comb begin

        control_wen =
            control_sel &&
            (slave_req.op == bus_pkg::BUS_WRITE);

        framebuffer_base_wen =
            framebuffer_base_sel &&
            (slave_req.op == bus_pkg::BUS_WRITE);

        framebuffer_width_wen =
            framebuffer_width_sel &&
            (slave_req.op == bus_pkg::BUS_WRITE);

        framebuffer_height_wen =
            framebuffer_height_sel &&
            (slave_req.op == bus_pkg::BUS_WRITE);

        clear_color_wen =
            clear_color_sel &&
            (slave_req.op == bus_pkg::BUS_WRITE);

    end

endmodule