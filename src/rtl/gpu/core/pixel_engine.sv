`timescale 1ns/1ps

// ============================================================
// LACOODA GPU pixel engine
//
// Converts a logical framebuffer pixel:
//
//     (x, y, color)
//
// into:
//
//     (memory address, pixel data)
//
// Address:
//
//     framebuffer_base
//       + ((y * framebuffer_width) + x)
//       * GPU_PIXEL_BYTES
//
// This module does NOT access memory directly.
//
// It only performs graphics-side address generation.
// The GPU memory interface will later translate the generated
// write into a LACOODA bus transaction.
// ============================================================

module pixel_engine (
    input gpu_pkg::gpu_config_s gpu_cfg,

    input  gpu_pkg::gpu_pixel_req_s   pixel_req,
    output gpu_pkg::gpu_pixel_write_s pixel_write
);


    // ========================================================
    // INTERNAL CALCULATION WIDTH
    // ========================================================
    //
    // Use the CPU architectural word width for framebuffer
    // address calculations.
    // ========================================================

    cpu_pkg::word_t x_ext;
    cpu_pkg::word_t y_ext;

    cpu_pkg::word_t pixel_index;
    cpu_pkg::word_t byte_offset;
    cpu_pkg::word_t pixel_addr;

    logic in_bounds;


    // ========================================================
    // COORDINATE EXTENSION
    // ========================================================

    always_comb begin

        x_ext = cpu_pkg::word_t'(pixel_req.x);
        y_ext = cpu_pkg::word_t'(pixel_req.y);

    end


    // ========================================================
    // BOUNDS CHECK
    // ========================================================

    always_comb begin

        in_bounds =

            (x_ext < gpu_cfg.framebuffer_width) &&

            (y_ext < gpu_cfg.framebuffer_height);

    end


    // ========================================================
    // PIXEL INDEX
    // ========================================================
    //
    // Linear row-major framebuffer:
    //
    //     index = y * width + x
    //
    // ========================================================

    always_comb begin

        pixel_index =

            (y_ext * gpu_cfg.framebuffer_width)
            +
            x_ext;

    end


    // ========================================================
    // BYTE OFFSET
    // ========================================================
    //
    // RGBA8888:
    //
    //     4 bytes per pixel
    //
    // Because GPU_PIXEL_BYTES is a power of two, synthesis can
    // reduce this multiplication to a shift.
    // ========================================================

    always_comb begin

        byte_offset =

            pixel_index
            *
            gpu_pkg::GPU_PIXEL_BYTES;

    end


    // ========================================================
    // FRAMEBUFFER ADDRESS
    // ========================================================

    always_comb begin

        pixel_addr =

            gpu_cfg.framebuffer_base
            +
            byte_offset;

    end


    // ========================================================
    // PIXEL WRITE OUTPUT
    // ========================================================

    always_comb begin

        pixel_write = '0;

        if (
            pixel_req.valid &&
            in_bounds
        ) begin

            pixel_write.valid =
                1'b1;

            pixel_write.addr =
                pixel_addr;

            pixel_write.data =
                pixel_req.color;

        end

    end

endmodule