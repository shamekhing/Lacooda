`timescale 1ns/1ps

// ============================================================
// LACOODA GPU MMIO REGISTER BLOCK
// ============================================================
//
// Native LACOODA bus slave.
//
// Existing register map:
//
//   0x00 : ID
//   0x04 : CONTROL
//   0x08 : STATUS
//   0x0C : FRAMEBUFFER_BASE
//   0x10 : FRAMEBUFFER_WIDTH
//   0x14 : FRAMEBUFFER_HEIGHT
//   0x18 : CLEAR_COLOR
//
// Access rules:
//
//   - Word-aligned accesses only.
//   - Reads ignore write strobes.
//   - Writes require all four byte strobes.
//   - ID and STATUS are read-only.
//   - Unknown addresses return an error.
//   - Invalid writes have no side effects.
//
// MMIO responses are combinational.
//
// A successful write executes at the rising edge on which
// valid && ready is asserted.
//
// This module does not execute GPU rendering commands.
// ============================================================

module gpu_register (

    input logic clk,
    input logic rst,

    input  bus_pkg::bus_req_s gpu_mmio_bus_req,
    output bus_pkg::bus_rsp_s gpu_mmio_bus_rsp,

    input  gpu_pkg::gpu_status_s status,
    output gpu_pkg::gpu_config_s gpu_cfg

);

    // ========================================================
    // LOCAL ADDRESS
    // ========================================================

    gpu_pkg::gpu_addr_t local_addr;

    assign local_addr =
        gpu_pkg::gpu_addr_t'(gpu_mmio_bus_req.addr);

    // ========================================================
    // REGISTER DECODING
    // ========================================================

    logic addr_aligned;
    logic addr_known;
    logic addr_writable;

    logic write_strobes_valid;
    logic access_valid;

    assign addr_aligned =
        bus_pkg::bus_is_aligned(gpu_mmio_bus_req.addr);

    // --------------------------------------------------------
    // Known and writable register classification.
    // --------------------------------------------------------

    always_comb begin

        addr_known    = 1'b0;
        addr_writable = 1'b0;

        case (local_addr)

            gpu_pkg::GPU_REG_ID,
            gpu_pkg::GPU_REG_STATUS: begin

                addr_known = 1'b1;

            end

            gpu_pkg::GPU_REG_CONTROL,
            gpu_pkg::GPU_REG_FRAMEBUFFER_BASE,
            gpu_pkg::GPU_REG_FRAMEBUFFER_WIDTH,
            gpu_pkg::GPU_REG_FRAMEBUFFER_HEIGHT,
            gpu_pkg::GPU_REG_CLEAR_COLOR: begin

                addr_known    = 1'b1;
                addr_writable = 1'b1;

            end

            default: begin

                addr_known    = 1'b0;
                addr_writable = 1'b0;

            end

        endcase

    end

    // ========================================================
    // WRITE STROBE CHECK
    // ========================================================
    //
    // RAM supports partial writes.
    //
    // GPU MMIO does not.
    //
    // Every GPU register write must update the complete word.
    // ========================================================

    assign write_strobes_valid =
        (gpu_mmio_bus_req.op == bus_pkg::BUS_READ) ||
        (gpu_mmio_bus_req.wstrb == bus_pkg::BUS_STRB_ALL);

    // ========================================================
    // ACCESS VALIDITY
    // ========================================================

    assign access_valid =
        addr_aligned &&
        addr_known &&
        write_strobes_valid &&
        (
            (gpu_mmio_bus_req.op == bus_pkg::BUS_READ) ||
            addr_writable
        );

    // ========================================================
    // CONFIGURATION REGISTERS
    // ========================================================
    //
    // All configuration fields are reset together.
    //
    // Invalid writes do not modify configuration.
    // ========================================================

    always_ff @(posedge clk or posedge rst) begin

        if (rst) begin

            gpu_cfg <= '0;

        end else if (
            gpu_mmio_bus_req.valid &&
            gpu_mmio_bus_rsp.ready &&
            access_valid &&
            (gpu_mmio_bus_req.op == bus_pkg::BUS_WRITE)
        ) begin

            case (local_addr)

                gpu_pkg::GPU_REG_CONTROL: begin

                    gpu_cfg.control <= gpu_mmio_bus_req.wdata;

                end

                gpu_pkg::GPU_REG_FRAMEBUFFER_BASE: begin

                    gpu_cfg.framebuffer_base <=
                        gpu_mmio_bus_req.wdata;

                end

                gpu_pkg::GPU_REG_FRAMEBUFFER_WIDTH: begin

                    gpu_cfg.framebuffer_width <=
                        gpu_mmio_bus_req.wdata;

                end

                gpu_pkg::GPU_REG_FRAMEBUFFER_HEIGHT: begin

                    gpu_cfg.framebuffer_height <=
                        gpu_mmio_bus_req.wdata;

                end

                gpu_pkg::GPU_REG_CLEAR_COLOR: begin

                    gpu_cfg.clear_color <=
                        gpu_mmio_bus_req.wdata;

                end

                default: begin

                    // Read-only or reserved register.
                    // No write occurs.

                end

            endcase

        end

    end

    // ========================================================
    // READ RESPONSE
    // ========================================================

    always_comb begin

        gpu_mmio_bus_rsp = '0;

        if (gpu_mmio_bus_req.valid && !rst) begin

            gpu_mmio_bus_rsp.ready = 1'b1;
            gpu_mmio_bus_rsp.error = !access_valid;

            if (
                access_valid &&
                (gpu_mmio_bus_req.op == bus_pkg::BUS_READ)
            ) begin

                case (local_addr)

                    gpu_pkg::GPU_REG_ID: begin

                        gpu_mmio_bus_rsp.rdata =
                            gpu_pkg::GPU_ID_VALUE;

                    end

                    gpu_pkg::GPU_REG_CONTROL: begin

                        gpu_mmio_bus_rsp.rdata =
                            gpu_cfg.control;

                    end

                    gpu_pkg::GPU_REG_STATUS: begin

                        gpu_mmio_bus_rsp.rdata =
                            cpu_pkg::word_t'(status);

                    end

                    gpu_pkg::GPU_REG_FRAMEBUFFER_BASE: begin

                        gpu_mmio_bus_rsp.rdata =
                            gpu_cfg.framebuffer_base;

                    end

                    gpu_pkg::GPU_REG_FRAMEBUFFER_WIDTH: begin

                        gpu_mmio_bus_rsp.rdata =
                            gpu_cfg.framebuffer_width;

                    end

                    gpu_pkg::GPU_REG_FRAMEBUFFER_HEIGHT: begin

                        gpu_mmio_bus_rsp.rdata =
                            gpu_cfg.framebuffer_height;

                    end

                    gpu_pkg::GPU_REG_CLEAR_COLOR: begin

                        gpu_mmio_bus_rsp.rdata =
                            gpu_cfg.clear_color;

                    end

                    default: begin

                        gpu_mmio_bus_rsp.rdata = '0;

                    end

                endcase

            end

        end

    end

endmodule